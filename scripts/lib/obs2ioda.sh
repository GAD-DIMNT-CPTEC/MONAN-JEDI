#!/usr/bin/env bash
# obs2ioda build workflow for MONAN-JEDI.
#
# Purpose:
#   Build NCAR/obs2ioda using the already loaded MONAN-JEDI spack-stack-inpe
#   environment. This keeps obs2ioda outside the main MONAN-JEDI bundle while
#   still making it reproducible from the same YAML configuration and module set.

monan_jedi_obs2ioda_enabled() {
  case "${MONAN_JEDI_OBS2IODA_ENABLED:-0}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

monan_jedi_find_obs2ioda_bufr_lib() {
  if [[ -n "${MONAN_JEDI_OBS2IODA_BUFR_LIB:-}" ]]; then
    if [[ -f "${MONAN_JEDI_OBS2IODA_BUFR_LIB}" ]]; then
      printf '%s\n' "${MONAN_JEDI_OBS2IODA_BUFR_LIB}"
      return 0
    fi
    log_error "Configured obs2ioda BUFR library was not found: ${MONAN_JEDI_OBS2IODA_BUFR_LIB}"
    exit 1
  fi

  local search_roots=()
  local spack_bufr_root=""
  local candidate=""
  local root=""

  if command -v spack >/dev/null 2>&1; then
    spack_bufr_root="$(spack location -i bufr 2>/dev/null || true)"
    [[ -n "${spack_bufr_root}" && -d "${spack_bufr_root}" ]] && search_roots+=("${spack_bufr_root}")
  fi

  [[ -n "${MONAN_JEDI_OBS2IODA_BUFR_ROOT:-}" && -d "${MONAN_JEDI_OBS2IODA_BUFR_ROOT}" ]] && search_roots+=("${MONAN_JEDI_OBS2IODA_BUFR_ROOT}")
  [[ -n "${BUFR_ROOT:-}" && -d "${BUFR_ROOT}" ]] && search_roots+=("${BUFR_ROOT}")
  [[ -d "${STACK_ROOT}/../install" ]] && search_roots+=("${STACK_ROOT}/../install")
  [[ -d "/p/projetos/monan_das/${STACK_OWNER}/env/spack-stack/${STACK_INSTANCE}/install" ]] && search_roots+=("/p/projetos/monan_das/${STACK_OWNER}/env/spack-stack/${STACK_INSTANCE}/install")

  for root in "${search_roots[@]}"; do
    candidate="$(find "${root}" -type f \( \
        -name 'libbufr_4.so' -o -name 'libbufr_4.a' -o \
        -name 'libbufr.so' -o -name 'libbufr.a' \
      \) 2>/dev/null | grep '/bufr-' | grep -v '/bufr-query-' | head -n 1 || true)"

    if [[ -n "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  for root in "${search_roots[@]}"; do
    candidate="$(find "${root}" -type f \( \
        -name 'libbufr_4.so' -o -name 'libbufr_4.a' -o \
        -name 'libbufr.so' -o -name 'libbufr.a' \
      \) 2>/dev/null | head -n 1 || true)"

    if [[ -n "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  log_error "Could not find a BUFR library for obs2ioda. Set obs2ioda.bufr_lib or obs2ioda.bufr_root in the YAML configuration."
  exit 1
}

monan_jedi_prepare_obs2ioda_source() {
  require_cmd git

  mkdir -p "$(dirname "${MONAN_JEDI_OBS2IODA_SOURCE_DIR}")"

  if [[ ! -d "${MONAN_JEDI_OBS2IODA_SOURCE_DIR}/.git" ]]; then
    log_info "Cloning obs2ioda source"
    log_info "  repo=${MONAN_JEDI_OBS2IODA_REPO}"
    log_info "  source=${MONAN_JEDI_OBS2IODA_SOURCE_DIR}"
    git clone "${MONAN_JEDI_OBS2IODA_REPO}" "${MONAN_JEDI_OBS2IODA_SOURCE_DIR}" \
      2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/08_obs2ioda_clone.log"
  fi

  cd "${MONAN_JEDI_OBS2IODA_SOURCE_DIR}" || {
    log_error "Failed to enter obs2ioda source directory: ${MONAN_JEDI_OBS2IODA_SOURCE_DIR}"
    exit 1
  }

  git fetch --tags origin 2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/08_obs2ioda_fetch.log"
  git checkout "${MONAN_JEDI_OBS2IODA_REF}" 2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/08_obs2ioda_checkout.log"
}

monan_jedi_build_obs2ioda() {
  if ! monan_jedi_obs2ioda_enabled; then
    log_error "obs2ioda is disabled in ${MONAN_JEDI_CONFIG}. Set obs2ioda.enabled: true to build it."
    exit 1
  fi

  monan_jedi_load_stack

  require_cmd cmake
  require_cmd make
  require_cmd nc-config
  require_cmd nf-config
  require_cmd ncxx4-config

  mkdir -p "${MONAN_JEDI_LOG_ROOT}"

  monan_jedi_prepare_obs2ioda_source

  local bufr_lib
  local netcdf_c_root
  local netcdf_fortran_root
  local netcdf_cxx_root
  local cmake_prefix_path

  bufr_lib="$(monan_jedi_find_obs2ioda_bufr_lib)"
  netcdf_c_root="$(nc-config --prefix)"
  netcdf_fortran_root="$(nf-config --prefix)"
  netcdf_cxx_root="$(ncxx4-config --prefix)"

  cmake_prefix_path="${netcdf_c_root};${netcdf_fortran_root};${netcdf_cxx_root}"
  if [[ -n "${MONAN_JEDI_OBS2IODA_CMAKE_PREFIX_PATH:-}" ]]; then
    cmake_prefix_path="${cmake_prefix_path};${MONAN_JEDI_OBS2IODA_CMAKE_PREFIX_PATH}"
  fi

  log_info "Configuring obs2ioda"
  log_info "  source=${MONAN_JEDI_OBS2IODA_SOURCE_DIR}"
  log_info "  build=${MONAN_JEDI_OBS2IODA_BUILD_DIR}"
  log_info "  install=${MONAN_JEDI_OBS2IODA_INSTALL_DIR}"
  log_info "  BUFR=${bufr_lib}"
  log_info "  NetCDF C=${netcdf_c_root}"
  log_info "  NetCDF Fortran=${netcdf_fortran_root}"
  log_info "  NetCDF CXX=${netcdf_cxx_root}"

  rm -rf "${MONAN_JEDI_OBS2IODA_BUILD_DIR}"
  mkdir -p "${MONAN_JEDI_OBS2IODA_BUILD_DIR}" "${MONAN_JEDI_OBS2IODA_INSTALL_DIR}"
  cd "${MONAN_JEDI_OBS2IODA_BUILD_DIR}" || {
    log_error "Failed to enter obs2ioda build directory: ${MONAN_JEDI_OBS2IODA_BUILD_DIR}"
    exit 1
  }

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

  log_info "Building obs2ioda"
  cmake --build . -j "${MONAN_JEDI_OBS2IODA_JOBS}" \
    2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/08_obs2ioda_build.log"

  if [[ ! -x "${MONAN_JEDI_OBS2IODA_BUILD_DIR}/bin/obs2ioda_v3" ]]; then
    log_error "obs2ioda_v3 was not created under ${MONAN_JEDI_OBS2IODA_BUILD_DIR}/bin"
    exit 1
  fi

  mkdir -p "${MONAN_JEDI_OBS2IODA_INSTALL_DIR}/bin"
  cp -p "${MONAN_JEDI_OBS2IODA_BUILD_DIR}/bin/obs2ioda_v3" "${MONAN_JEDI_OBS2IODA_INSTALL_DIR}/bin/"

  if [[ -x "${MONAN_JEDI_OBS2IODA_BUILD_DIR}/bin/goes_abi_converter" ]]; then
    cp -p "${MONAN_JEDI_OBS2IODA_BUILD_DIR}/bin/goes_abi_converter" "${MONAN_JEDI_OBS2IODA_INSTALL_DIR}/bin/"
  fi

  log_info "Checking obs2ioda runtime libraries"
  if ldd "${MONAN_JEDI_OBS2IODA_BUILD_DIR}/bin/obs2ioda_v3" 2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/08_obs2ioda_ldd.log" | grep -q 'not found'; then
    log_error "obs2ioda_v3 has missing runtime libraries. See ${MONAN_JEDI_LOG_ROOT}/08_obs2ioda_ldd.log"
    exit 1
  fi

  log_info "obs2ioda build completed"
  log_info "  executable=${MONAN_JEDI_OBS2IODA_INSTALL_DIR}/bin/obs2ioda_v3"
}
