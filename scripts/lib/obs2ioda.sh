#!/usr/bin/env bash
# Build NCAR/obs2ioda with the MONAN-JEDI stack environment.

monan_jedi_obs2ioda_enabled() {
  case "${MONAN_JEDI_OBS2IODA_ENABLED:-0}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

monan_jedi_find_obs2ioda_bufr_lib() {
  if [[ -n "${MONAN_JEDI_OBS2IODA_BUFR_LIB:-}" ]]; then
    [[ -f "${MONAN_JEDI_OBS2IODA_BUFR_LIB}" ]] || {
      log_error "Configured BUFR library not found: ${MONAN_JEDI_OBS2IODA_BUFR_LIB}"
      exit 1
    }
    printf '%s\n' "${MONAN_JEDI_OBS2IODA_BUFR_LIB}"
    return 0
  fi

  local root candidate
  for root in \
    "${MONAN_JEDI_OBS2IODA_BUFR_ROOT:-}" \
    "$(spack location -i bufr 2>/dev/null || true)" \
    "${STACK_ROOT}/../install" \
    "/p/projetos/monan_das/${STACK_OWNER}/env/spack-stack/${STACK_INSTANCE}/install"
  do
    [[ -n "${root}" && -d "${root}" ]] || continue
    candidate="$(find "${root}" -type f \( -name 'libbufr_4.so' -o -name 'libbufr_4.a' -o -name 'libbufr.so' -o -name 'libbufr.a' \) 2>/dev/null | grep '/bufr-' | grep -v '/bufr-query-' | head -n 1 || true)"
    if [[ -n "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  log_error "Could not find BUFR library for obs2ioda. Set obs2ioda.bufr_lib in the YAML configuration."
  exit 1
}

monan_jedi_prepare_obs2ioda_source() {
  require_cmd git
  mkdir -p "$(dirname "${MONAN_JEDI_OBS2IODA_SOURCE_DIR}")"

  if [[ ! -d "${MONAN_JEDI_OBS2IODA_SOURCE_DIR}/.git" ]]; then
    git clone "${MONAN_JEDI_OBS2IODA_REPO}" "${MONAN_JEDI_OBS2IODA_SOURCE_DIR}" 2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/08_obs2ioda_clone.log"
  fi

  cd "${MONAN_JEDI_OBS2IODA_SOURCE_DIR}"
  git fetch --tags origin 2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/08_obs2ioda_fetch.log"
  git checkout "${MONAN_JEDI_OBS2IODA_REF}" 2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/08_obs2ioda_checkout.log"
}

monan_jedi_build_obs2ioda() {
  monan_jedi_obs2ioda_enabled || {
    log_error "obs2ioda is disabled in ${MONAN_JEDI_CONFIG}. Set obs2ioda.enabled: true."
    exit 1
  }

  monan_jedi_load_stack
  require_cmd cmake
  require_cmd nc-config
  require_cmd nf-config
  require_cmd ncxx4-config

  mkdir -p "${MONAN_JEDI_LOG_ROOT}" "${MONAN_JEDI_INSTALL_BIN_DIR}"
  monan_jedi_prepare_obs2ioda_source

  local bufr_lib cmake_prefix_path built_exe published_exe
  bufr_lib="$(monan_jedi_find_obs2ioda_bufr_lib)"
  cmake_prefix_path="$(nc-config --prefix);$(nf-config --prefix);$(ncxx4-config --prefix)"

  log_info "obs2ioda source=${MONAN_JEDI_OBS2IODA_SOURCE_DIR}"
  log_info "obs2ioda build=${MONAN_JEDI_OBS2IODA_BUILD_DIR}"
  log_info "obs2ioda publish_bin=${MONAN_JEDI_INSTALL_BIN_DIR}"
  log_info "obs2ioda executable=${MONAN_JEDI_OBS2IODA_EXECUTABLE_NAME}"
  log_info "obs2ioda BUFR=${bufr_lib}"

  rm -rf "${MONAN_JEDI_OBS2IODA_BUILD_DIR}"
  mkdir -p "${MONAN_JEDI_OBS2IODA_BUILD_DIR}"
  cd "${MONAN_JEDI_OBS2IODA_BUILD_DIR}"

  cmake "${MONAN_JEDI_OBS2IODA_SOURCE_DIR}" \
    "-DCMAKE_BUILD_TYPE=${MONAN_JEDI_OBS2IODA_BUILD_TYPE}" \
    "-DCMAKE_INSTALL_PREFIX=${MONAN_JEDI_OBS2IODA_INSTALL_DIR}" \
    "-DCMAKE_C_COMPILER=${CC}" \
    "-DCMAKE_CXX_COMPILER=${CXX}" \
    "-DCMAKE_Fortran_COMPILER=${FC}" \
    "-DCMAKE_PREFIX_PATH=${cmake_prefix_path}" \
    "-DNCEP_BUFR_LIB=${bufr_lib}" \
    "-DBUILD_GOES_ABI_CONVERTER=${MONAN_JEDI_OBS2IODA_BUILD_GOES_ABI_CONVERTER}" \
    2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/08_obs2ioda_cmake.log"

  cmake --build . -j "${MONAN_JEDI_OBS2IODA_JOBS}" 2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/08_obs2ioda_build.log"

  built_exe="${MONAN_JEDI_OBS2IODA_BUILD_DIR}/bin/obs2ioda_v3"
  published_exe="${MONAN_JEDI_INSTALL_BIN_DIR}/${MONAN_JEDI_OBS2IODA_EXECUTABLE_NAME}"

  [[ -x "${built_exe}" ]] || {
    log_error "obs2ioda_v3 was not created: ${built_exe}"
    exit 1
  }

  cp -p "${built_exe}" "${published_exe}"
  chmod 755 "${published_exe}"

  if ldd "${published_exe}" 2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/08_obs2ioda_ldd.log" | grep -q 'not found'; then
    log_error "Missing runtime library for ${published_exe}"
    exit 1
  fi

  log_info "obs2ioda published=${published_exe}"
}
