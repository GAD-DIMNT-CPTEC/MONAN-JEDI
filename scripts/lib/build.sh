#!/usr/bin/env bash
# Build and install commands for the MONAN-JEDI reduced MPAS-JEDI workflow.
#
# Purpose:
#   Compile and install the already configured MONAN-JEDI build tree.
#
# Requires:
#   load_monan_jedi_config must have defined MONAN_JEDI_BUILD_DIR,
#   MONAN_JEDI_BUILD_JOBS, MONAN_JEDI_INSTALL_ROOT and MONAN_JEDI_LOG_ROOT. The
#   configure step must have completed successfully and produced a Makefile in
#   MONAN_JEDI_BUILD_DIR.

monan_jedi_validate_required_mpas_executables() {
  local bin_dir="$1"
  local phase="$2"
  local executable
  local -a required_executables=(
    "mpasjedi_process_perts.x"
    "mpasjedi_unbalance_ensemble.x"
  )

  for executable in "${required_executables[@]}"; do
    if [[ ! -x "${bin_dir}/${executable}" ]]; then
      log_error "Required MPAS-JEDI executable is missing after ${phase}: ${bin_dir}/${executable}"
      exit 1
    fi
  done

  log_info "Validated required MPAS-JEDI executables after ${phase}"
  log_info "  process_perts=${bin_dir}/mpasjedi_process_perts.x"
  log_info "  unbalance=${bin_dir}/mpasjedi_unbalance_ensemble.x"
}

monan_jedi_publish_secondary_bin_aliases() {
  local canonical_bin="${MONAN_JEDI_INSTALL_ROOT}/bin"
  local secondary_bin="${MONAN_JEDI_INSTALL_BIN_DIR}"
  local name

  [[ "${secondary_bin}" != "${canonical_bin}" ]] || return 0

  mkdir -p "${secondary_bin}"
  for name in \
    mpas_init_atmosphere \
    mpas_atmosphere \
    mpasjedi_variational.x \
    mpasjedi_error_covariance_toolbox.x \
    mpasjedi_process_perts.x \
    mpasjedi_unbalance_ensemble.x
  do
    [[ -e "${canonical_bin}/${name}" ]] || continue
    ln -sfn "${canonical_bin}/${name}" "${secondary_bin}/${name}"
  done

  log_info "Published optional secondary executable aliases"
  log_info "  canonical=${canonical_bin}"
  log_info "  secondary=${secondary_bin}"
}

monan_jedi_publish_runtime_support() {
  local source_namelists="${MONAN_JEDI_SOURCE_DIR}/mpas-jedi/test/testinput/namelists"
  local target_namelists="${MONAN_JEDI_INSTALL_ROOT}/share/monan-jedi/mpas-jedi/namelists"
  local source_testinput="${MONAN_JEDI_SOURCE_DIR}/mpas-jedi/test/testinput"
  local target_testinput="${MONAN_JEDI_INSTALL_ROOT}/share/monan-jedi/mpas-jedi/testinput"
  local manifest="${MONAN_JEDI_INSTALL_ROOT}/share/monan-jedi/install-manifest.json"
  local name
  local -a namelist_files=(
    "geovars.yaml"
    "keptvars.yaml"
    "stream_list.atmosphere.background"
    "stream_list.atmosphere.analysis"
    "stream_list.atmosphere.control"
    "stream_list.atmosphere.ensemble"
  )

  mkdir -p "${target_namelists}" "${target_testinput}" "$(dirname "${manifest}")"

  # These files are runtime inputs used by downstream workflows. They are part
  # of the public installation contract and must not be read from source-tree
  # test directories by consumers.
  for name in "${namelist_files[@]}"; do
    if [[ ! -f "${source_namelists}/${name}" ]]; then
      log_error "Required MPAS-JEDI runtime support file is missing: ${source_namelists}/${name}"
      exit 1
    fi
    install -m 644 "${source_namelists}/${name}" "${target_namelists}/${name}"
  done

  if [[ ! -f "${source_testinput}/obsop_name_map.yaml" ]]; then
    log_error "Required MPAS-JEDI observation alias map is missing: ${source_testinput}/obsop_name_map.yaml"
    exit 1
  fi
  install -m 644 "${source_testinput}/obsop_name_map.yaml" "${target_testinput}/obsop_name_map.yaml"

  require_cmd python3
  python3 - "${manifest}" <<'PY'
import json
import os
import sys
from pathlib import Path

root = Path(os.environ["MONAN_JEDI_INSTALL_ROOT"])
manifest = Path(sys.argv[1])
record = {
    "schema_version": 1,
    "install_root": str(root),
    "public_contract": {
        "bin": "bin",
        "lib": "lib",
        "include": "include",
        "share": "share",
        "mpas_atmosphere_share": "share/MPAS/core_atmosphere",
        "wps_variable_tables": "share/wps/Variable_Tables",
        "mpas_jedi_namelists": "share/monan-jedi/mpas-jedi/namelists",
        "mpas_jedi_testinput": "share/monan-jedi/mpas-jedi/testinput",
        "ufo_testinput_tier_1": "share/monan-jedi/ufo/testinput_tier_1",
    },
    "required_runtime_support": [
        "share/monan-jedi/mpas-jedi/namelists/geovars.yaml",
        "share/monan-jedi/mpas-jedi/namelists/keptvars.yaml",
        "share/monan-jedi/mpas-jedi/namelists/stream_list.atmosphere.background",
        "share/monan-jedi/mpas-jedi/namelists/stream_list.atmosphere.analysis",
        "share/monan-jedi/mpas-jedi/namelists/stream_list.atmosphere.control",
        "share/monan-jedi/mpas-jedi/namelists/stream_list.atmosphere.ensemble",
        "share/monan-jedi/mpas-jedi/testinput/obsop_name_map.yaml",
        "share/monan-jedi/ufo/testinput_tier_1/sondes_obs_2018041500_m.nc4",
        "share/monan-jedi/ufo/testinput_tier_1/gnssro_obs_2018041500_s.nc4",
        "share/monan-jedi/ufo/testinput_tier_1/sfc_obs_2018041500_m.nc4",
    ],
}
manifest.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

  log_info "Published MONAN-JEDI runtime support"
  log_info "  namelists=${target_namelists}"
  log_info "  testinput=${target_testinput}"
  log_info "  manifest=${manifest}"
}

monan_jedi_build_bundle() {
  # Load the configured MONAN-JEDI stack before resolving build tools.
  monan_jedi_load_stack

  # Fail early if make is not available after the stack has been loaded.
  require_cmd make

  # The configure step must have generated a Makefile in the build tree.
  if [[ ! -f "${MONAN_JEDI_BUILD_DIR}/Makefile" ]]; then
    log_error "Build tree does not contain Makefile: ${MONAN_JEDI_BUILD_DIR}"
    exit 1
  fi

  # Run make from the configured build directory. Guard the directory change to
  # avoid accidentally building from the wrong working directory.
  cd "${MONAN_JEDI_BUILD_DIR}" || {
    log_error "Failed to enter build directory: ${MONAN_JEDI_BUILD_DIR}"
    exit 1
  }

  # Keep the build output visible while also preserving a persistent log.
  make -j "${MONAN_JEDI_BUILD_JOBS}" 2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/05_make.log"

  # MPAS-JEDI overrides the bundle-level runtime output directory and writes
  # executable build artifacts to the bundle's build/bin directory. Publishing
  # to the user-facing install/bin directory happens only during make install.
  monan_jedi_validate_required_mpas_executables "${MONAN_JEDI_BUILD_DIR}/bin" "build"
}

monan_jedi_install_bundle() {
  monan_jedi_load_stack
  require_cmd make
  require_cmd install

  if [[ ! -f "${MONAN_JEDI_BUILD_DIR}/Makefile" ]]; then
    log_error "Build tree does not contain Makefile: ${MONAN_JEDI_BUILD_DIR}"
    exit 1
  fi

  mkdir -p "${MONAN_JEDI_INSTALL_ROOT}" "${MONAN_JEDI_INSTALL_BIN_DIR}"

  cd "${MONAN_JEDI_BUILD_DIR}" || {
    log_error "Failed to enter build directory: ${MONAN_JEDI_BUILD_DIR}"
    exit 1
  }

  log_info "Installing MONAN-JEDI bundle"
  log_info "  build=${MONAN_JEDI_BUILD_DIR}"
  log_info "  install=${MONAN_JEDI_INSTALL_ROOT}"
  log_info "  install_bin=${MONAN_JEDI_INSTALL_BIN_DIR}"

  make install 2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/06_make_install.log"
  monan_jedi_validate_required_mpas_executables "${MONAN_JEDI_INSTALL_ROOT}/bin" "install"
  monan_jedi_publish_secondary_bin_aliases
  monan_jedi_publish_runtime_support
}
