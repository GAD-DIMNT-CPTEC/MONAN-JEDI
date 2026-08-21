#!/usr/bin/env bash
# ecbuild/CMake configuration for the MONAN-JEDI repository bundle.

monan_jedi_download_enabled() {
  case "${MONAN_JEDI_DATA_DOWNLOAD_MISSING:-1}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

monan_jedi_valid_tgz_archive() {
  local archive="$1"

  [[ -s "${archive}" ]] || return 1

  if command -v tar >/dev/null 2>&1; then
    tar -tzf "${archive}" >/dev/null 2>&1
    return $?
  fi

  return 0
}

monan_jedi_find_local_data_file() {
  local relative_path="$1"
  local filename
  filename="$(basename "${relative_path}")"

  [[ -n "${MONAN_JEDI_DATA_LOCAL_ROOT:-}" && -d "${MONAN_JEDI_DATA_LOCAL_ROOT}" ]] || return 1

  for candidate in \
    "${MONAN_JEDI_DATA_LOCAL_ROOT}/${relative_path}" \
    "${MONAN_JEDI_DATA_LOCAL_ROOT}/${filename}"
  do
    if [[ -s "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  find "${MONAN_JEDI_DATA_LOCAL_ROOT}" -type f -name "${filename}" -print -quit 2>/dev/null
}

monan_jedi_stage_tgz_data_file() {
  local name="$1"
  local url="$2"
  local cache_file="$3"
  local build_file="$4"
  local relative_path="$5"
  local local_file=""

  mkdir -p "$(dirname "${cache_file}")" "$(dirname "${build_file}")"

  local_file="$(monan_jedi_find_local_data_file "${relative_path}" || true)"
  if [[ -n "${local_file}" ]]; then
    if monan_jedi_valid_tgz_archive "${local_file}"; then
      cp -p "${local_file}" "${cache_file}"
      log_info "Using local ${name} archive"
      log_info "  local=${local_file}"
      log_info "  cache=${cache_file}"
    else
      log_warn "Local ${name} archive exists but is invalid: ${local_file}"
    fi
  fi

  if [[ -s "${cache_file}" ]] && ! monan_jedi_valid_tgz_archive "${cache_file}"; then
    log_warn "Cached ${name} archive is incomplete or invalid: ${cache_file}"
    log_warn "Removing invalid cache file."
    rm -f "${cache_file}"
  fi

  if [[ ! -s "${cache_file}" ]]; then
    if monan_jedi_download_enabled; then
      log_info "Downloading ${name} archive"
      log_info "  url=${url}"
      log_info "  cache=${cache_file}"

      if command -v wget >/dev/null 2>&1; then
        wget --continue --tries=5 --timeout=60 --waitretry=10 \
          -O "${cache_file}" \
          "${url}" \
          2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/03_${name}_download.log"
      elif command -v curl >/dev/null 2>&1; then
        curl --fail --location --retry 5 --retry-delay 10 \
          --output "${cache_file}" \
          "${url}" \
          2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/03_${name}_download.log"
      else
        log_warn "Neither wget nor curl is available. CMake may try to download ${name} during configure."
      fi
    else
      log_warn "Download disabled and ${name} archive was not found locally or in cache."
    fi
  fi

  if monan_jedi_valid_tgz_archive "${cache_file}"; then
    cp -p "${cache_file}" "${build_file}"
    log_info "Prepared ${name} archive for CMake"
    log_info "  source=${cache_file}"
    log_info "  target=${build_file}"
  else
    log_warn "${name} archive is not available or is invalid before configure."
    log_warn "CMake may fail if it cannot obtain ${url}."
  fi
}

monan_jedi_prepare_external_data() {
  monan_jedi_stage_tgz_data_file \
    "crtm_coeffs" \
    "${MONAN_JEDI_CRTM_COEFFS_URL}" \
    "${MONAN_JEDI_CRTM_COEFFS_TGZ}" \
    "${MONAN_JEDI_BUILD_DIR}/test_data/3.1.3/fix_REL-3.1.2.0.tgz" \
    "crtm/fix_REL-3.1.2.0.tgz"
}

monan_jedi_unbalance_sources_materialized() {
  local saber_dir="${MONAN_JEDI_SOURCE_DIR}/saber"
  local mpas_jedi_dir="${MONAN_JEDI_SOURCE_DIR}/mpas-jedi"

  [[ -d "${saber_dir}" && -d "${mpas_jedi_dir}" ]] || return 1
  git -C "${saber_dir}" rev-parse --git-dir >/dev/null 2>&1 || return 1
  git -C "${mpas_jedi_dir}" rev-parse --git-dir >/dev/null 2>&1 || return 1
}

monan_jedi_apply_unbalance_patches() {
  local patch_script="${MONAN_JEDI_SOURCE_DIR}/scripts/apply_unbalance_ensemble_patches.sh"

  if [[ ! -f "${patch_script}" ]]; then
    log_error "Unbalance ensemble patch helper not found: ${patch_script}"
    exit 1
  fi

  log_info "Applying required unbalance ensemble patches"
  (
    cd "${MONAN_JEDI_SOURCE_DIR}" || exit 1
    bash "${patch_script}"
  ) 2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/04_unbalance_patches.log"
}

monan_jedi_validate_unbalance_target() {
  local target="mpasjedi_unbalance_ensemble.x"

  if ! cmake --build "${MONAN_JEDI_BUILD_DIR}" --target help 2>/dev/null | grep -Fq "${target}"; then
    log_error "Required MPAS-JEDI target was not registered by CMake: ${target}"
    log_error "The unbalance patches must be applied before the final configure pass."
    exit 1
  fi

  log_info "Validated required MPAS-JEDI target: ${target}"
  log_info "  runtime_output=${MONAN_JEDI_INSTALL_BIN_DIR}/${target}"
}

monan_jedi_configure_bundle() {
  monan_jedi_load_stack

  require_cmd ecbuild
  require_cmd cmake
  require_cmd git
  require_cmd python

  if [[ ! -f "${MONAN_JEDI_SOURCE_DIR}/CMakeLists.txt" ]]; then
    log_error "MONAN-JEDI source CMakeLists.txt not found: ${MONAN_JEDI_SOURCE_DIR}/CMakeLists.txt"
    exit 1
  fi

  rm -rf "${MONAN_JEDI_BUILD_DIR}"
  mkdir -p "${MONAN_JEDI_BUILD_DIR}" "${MONAN_JEDI_LOG_ROOT}" "${MONAN_JEDI_INSTALL_BIN_DIR}"
  cd "${MONAN_JEDI_BUILD_DIR}" || {
    log_error "Failed to enter build directory: ${MONAN_JEDI_BUILD_DIR}"
    exit 1
  }

  monan_jedi_prepare_external_data

  case "${MONAN_JEDI_MODEL_DOUBLE_PRECISION}" in
    ON|OFF) ;;
    *)
      log_error "Invalid MPAS double precision value: ${MONAN_JEDI_MODEL_DOUBLE_PRECISION}. Use ON or OFF."
      exit 1
      ;;
  esac

  local cache_file="${MONAN_JEDI_BUILD_DIR}/monan-jedi-initial-cache.cmake"
  local after_project_file="${MONAN_JEDI_BUILD_DIR}/monan-jedi-after-project.cmake"
  local python_exe python_prefix python_include python_library
  local -a ecbuild_args

  python_exe="$(command -v python)"
  python_prefix="$(${python_exe} -c 'import sys; print(sys.prefix)')"
  python_include="$(${python_exe} -c 'import sysconfig; print(sysconfig.get_path("include") or "")')"
  python_library="$(${python_exe} -c 'import pathlib, sysconfig; libdir=pathlib.Path(sysconfig.get_config_var("LIBDIR") or ""); ldlib=sysconfig.get_config_var("LDLIBRARY") or ""; path=libdir / ldlib if libdir and ldlib else pathlib.Path(""); print(path if str(path) != "." else "")')"

  cat > "${cache_file}" <<EOF_CACHE
# Generated by scripts/lib/configure.sh.
set(Python3_EXECUTABLE "${python_exe}" CACHE FILEPATH "" FORCE)
set(Python_EXECUTABLE "${python_exe}" CACHE FILEPATH "" FORCE)
set(PYTHON_EXECUTABLE "${python_exe}" CACHE FILEPATH "" FORCE)
set(Python3_ROOT_DIR "${python_prefix}" CACHE PATH "" FORCE)
set(Python3_INCLUDE_DIR "${python_include}" CACHE PATH "" FORCE)
set(_Python3_INCLUDE_DIR "${python_include}" CACHE PATH "" FORCE)
set(Python3_FIND_STRATEGY LOCATION CACHE STRING "" FORCE)
set(Python3_FIND_REGISTRY NEVER CACHE STRING "" FORCE)
set(Python3_FIND_FRAMEWORK NEVER CACHE STRING "" FORCE)
set(MONAN_JEDI_INITIAL_CACHE_LOADED ON CACHE BOOL "" FORCE)
EOF_CACHE

  if [[ -n "${python_library}" && -f "${python_library}" ]]; then
    cat >> "${cache_file}" <<EOF_CACHE
set(Python3_LIBRARY "${python_library}" CACHE FILEPATH "" FORCE)
set(Python3_LIBRARIES "${python_library}" CACHE STRING "" FORCE)
EOF_CACHE
  fi

  cat > "${after_project_file}" <<'EOF_PROJECT'
# Generated by scripts/lib/configure.sh.
if(NOT MONAN_JEDI_AFTER_PROJECT_INCLUDE_DONE)
  set(MONAN_JEDI_AFTER_PROJECT_INCLUDE_DONE TRUE CACHE INTERNAL "")
  find_package(ip CONFIG QUIET)
  if(TARGET ip::ip_d)
    message(STATUS "MONAN-JEDI after-project include: ip::ip_d is available")
  else()
    message(STATUS "MONAN-JEDI after-project include: ip::ip_d not available; continuing")
  endif()
endif()
EOF_PROJECT

  monan_jedi_record_environment_snapshot "${MONAN_JEDI_LOG_ROOT}/04_configure_environment.log"

  log_info "Configuring MONAN-JEDI bundle"
  log_info "  source=${MONAN_JEDI_SOURCE_DIR}"
  log_info "  build=${MONAN_JEDI_BUILD_DIR}"
  log_info "  install=${MONAN_JEDI_INSTALL_ROOT}"
  log_info "  install_bin=${MONAN_JEDI_INSTALL_BIN_DIR}"

  ecbuild_args=(
    "${MONAN_JEDI_SOURCE_DIR}"
    "-C${cache_file}"
    "-DCMAKE_PROJECT_INCLUDE=${after_project_file}"
    "-DCMAKE_C_COMPILER=${CC}"
    "-DCMAKE_CXX_COMPILER=${CXX}"
    "-DCMAKE_Fortran_COMPILER=${FC}"
    "-DMPI_C_COMPILER=${MPICC}"
    "-DMPI_CXX_COMPILER=${MPICXX}"
    "-DMPI_Fortran_COMPILER=${MPIFC}"
    "-DPython3_EXECUTABLE=${python_exe}"
    "-DPython_EXECUTABLE=${python_exe}"
    "-DPYTHON_EXECUTABLE=${python_exe}"
    "-DCMAKE_INSTALL_PREFIX=${MONAN_JEDI_INSTALL_ROOT}"
    "-DCMAKE_INSTALL_BINDIR=bin"
    "-DCMAKE_INSTALL_LIBDIR=lib"
    "-DCMAKE_RUNTIME_OUTPUT_DIRECTORY=${MONAN_JEDI_INSTALL_BIN_DIR}"
    "-DCMAKE_INSTALL_RPATH=\$ORIGIN/../lib"
    "-DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON"
    "-DBUILD_MPAS=ON"
    "-DBUILD_GSIBEC=OFF"
    "-DMPAS_DOUBLE_PRECISION=${MONAN_JEDI_MODEL_DOUBLE_PRECISION}"
  )

  # ecbuild_bundle materializes saber/ and mpas-jedi/ in the MONAN-JEDI source
  # tree. On a clean checkout they do not exist until the first configure pass.
  # Run that pass only when needed, then patch the pinned sources and perform the
  # final configure pass so the new CMake target is guaranteed to be registered.
  if ! monan_jedi_unbalance_sources_materialized; then
    log_info "Materializing pinned bundle sources before applying unbalance patches"
    ecbuild "${ecbuild_args[@]}" \
      2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/04_ecbuild_materialize.log"
  fi

  monan_jedi_apply_unbalance_patches

  log_info "Running final MONAN-JEDI configure with unbalance patches applied"
  ecbuild "${ecbuild_args[@]}" \
    2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/04_ecbuild.log"

  monan_jedi_validate_unbalance_target
}
