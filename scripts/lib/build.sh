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

monan_jedi_publish_runtime_support() {
  local source_dir="${MONAN_JEDI_SOURCE_DIR}/mpas-jedi/test/testinput/namelists"
  local target_dir="${MONAN_JEDI_INSTALL_ROOT}/share/monan-jedi/mpas-jedi/namelists"
  local manifest="${MONAN_JEDI_INSTALL_ROOT}/share/monan-jedi/install-manifest.json"
  local name

  mkdir -p "${target_dir}" "$(dirname "${manifest}")"

  # These YAMLs are runtime inputs used by downstream workflows. They are part
  # of the public installation contract and must not be read from the ecbuild
  # source/materialization tree by consumers.
  for name in geovars.yaml keptvars.yaml; do
    if [[ ! -f "${source_dir}/${name}" ]]; then
      log_error "Required MPAS-JEDI runtime support file is missing: ${source_dir}/${name}"
      exit 1
    fi
    install -m 644 "${source_dir}/${name}" "${target_dir}/${name}"
  done

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
    },
    "required_runtime_support": [
        "share/monan-jedi/mpas-jedi/namelists/geovars.yaml",
        "share/monan-jedi/mpas-jedi/namelists/keptvars.yaml",
    ],
}
manifest.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

  log_info "Published MONAN-JEDI runtime support"
  log_info "  namelists=${target_dir}"
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
  monan_jedi_validate_required_mpas_executables "${MONAN_JEDI_INSTALL_BIN_DIR}" "install"
  monan_jedi_publish_runtime_support
}
