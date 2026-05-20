#!/usr/bin/env bash
# ecbuild/CMake configuration.

monan_jedi_configure_bundle() {
  monan_jedi_load_stack
  require_cmd ecbuild
  require_cmd cmake
  require_cmd python

  if [[ ! -d "${JEDI_BUNDLE_SRC_DIR}/.git" ]]; then
    log_error "JEDI bundle source not found: ${JEDI_BUNDLE_SRC_DIR}"
    exit 1
  fi

  rm -rf "${JEDI_BUNDLE_BUILD_DIR}"
  mkdir -p "${JEDI_BUNDLE_BUILD_DIR}" "${MONAN_JEDI_LOG_ROOT}"
  cd "${JEDI_BUNDLE_BUILD_DIR}"

  local cache_file="${JEDI_BUNDLE_BUILD_DIR}/monan-jedi-initial-cache.cmake"
  local after_project_file="${JEDI_BUNDLE_BUILD_DIR}/monan-jedi-after-project.cmake"
  local python_exe
  python_exe="$(command -v python)"

  cat > "${cache_file}" <<EOF
set(Python3_EXECUTABLE "${python_exe}" CACHE FILEPATH "" FORCE)
set(Python_EXECUTABLE "${python_exe}" CACHE FILEPATH "" FORCE)
set(PYTHON_EXECUTABLE "${python_exe}" CACHE FILEPATH "" FORCE)
set(Python3_FIND_STRATEGY LOCATION CACHE STRING "" FORCE)
set(Python3_FIND_REGISTRY NEVER CACHE STRING "" FORCE)
set(Python3_FIND_FRAMEWORK NEVER CACHE STRING "" FORCE)
EOF

  monan_jedi_record_environment_snapshot "${MONAN_JEDI_LOG_ROOT}/04_configure_environment.log"

  ecbuild "${JEDI_BUNDLE_SRC_DIR}" \
    "-C${cache_file}" \
    "-DCMAKE_PROJECT_INCLUDE=${after_project_file}" \
    "-DCMAKE_C_COMPILER=${CC}" \
    "-DCMAKE_CXX_COMPILER=${CXX}" \
    "-DCMAKE_Fortran_COMPILER=${FC}" \
    "-DMPI_C_COMPILER=${MPICC}" \
    "-DMPI_CXX_COMPILER=${MPICXX}" \
    "-DMPI_Fortran_COMPILER=${MPIFC}" \
    "-DBUILD_MPAS=ON" \
    "-DBUILD_GSIBEC=OFF" \
    2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/04_ecbuild.log"
}
