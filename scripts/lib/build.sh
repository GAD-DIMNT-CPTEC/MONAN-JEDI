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
  local source_ufo="${MONAN_JEDI_SOURCE_DIR}/ufo-data/testinput_tier_1"
  local target_ufo="${MONAN_JEDI_INSTALL_ROOT}/share/monan-jedi/ufo/testinput_tier_1"
  local manifest="${MONAN_JEDI_INSTALL_ROOT}/share/monan-jedi/install-manifest.json"
  local name
  local -a baseline_obs_files=(
    "sondes_obs_2018041500_m.nc4"
    "gnssro_obs_2018041500_s.nc4"
    "sfc_obs_2018041500_m.nc4"
  )
  local -a namelist_files=(
    "geovars.yaml"
    "keptvars.yaml"
    "stream_list.atmosphere.background"
    "stream_list.atmosphere.analysis"
    "stream_list.atmosphere.control"
    "stream_list.atmosphere.ensemble"
  )

  mkdir -p "${target_namelists}" "${target_testinput}" "${target_ufo}" "$(dirname "${manifest}")"

  # Publish only support files that are version-coupled to the installed
  # software. Scientific case data (including dated observations) remain owned
  # by experiment/reference-data roots.
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

  # Compatibility fixtures for the producer's own historical test suite.
  # Downstream ecosystem consumers must not use these as scientific case data.
  for name in "${baseline_obs_files[@]}"; do
    if [[ ! -f "${source_ufo}/${name}" ]]; then
      log_error "Required UFO compatibility fixture is missing: ${source_ufo}/${name}"
      exit 1
    fi
    install -m 644 "${source_ufo}/${name}" "${target_ufo}/${name}"
  done

  require_cmd python3
  python3 "${MONAN_JEDI_SOURCE_DIR}/scripts/write_runtime_manifest.py" \
    --output "${manifest}" \
    --install-root "${MONAN_JEDI_INSTALL_ROOT}" \
    --stack-env-name "${STACK_ENV_NAME}" \
    --stack-env-module "${STACK_ENV_MODULE}" \
    --stack-site-setup "${STACK_SITE_SETUP}" \
    --build-id "${MONAN_JEDI_BUILD_ID}" \
    --config "${MONAN_JEDI_CONFIG:-}" \
    --wps-enabled "${MONAN_JEDI_WPS_ENABLED:-0}" \
    --obs2ioda-enabled "${MONAN_JEDI_OBS2IODA_ENABLED:-0}" \
    --wps-ref "${MONAN_JEDI_WPS_REF:-}" \
    --obs2ioda-ref "${MONAN_JEDI_OBS2IODA_REF:-}"

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
