#!/usr/bin/env bash
# =============================================================================
# 03_create_mpas_only_bundle.sh
# =============================================================================
# Replace jedi-bundle CMakeLists.txt with a reduced MPAS-JEDI-only bundle.
# =============================================================================

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00_common.sh
source "${script_dir}/00_common.sh"

load_monan_jedi_stack

if [[ ! -d "${JEDI_BUNDLE_SRC_DIR}/.git" ]]; then
  log_error "JEDI bundle source not found: ${JEDI_BUNDLE_SRC_DIR}"
  log_error "Run scripts/02_prepare_jedi_bundle.sh first."
  exit 1
fi

cd "${JEDI_BUNDLE_SRC_DIR}"

backup_file="CMakeLists.txt.monan-jedi-backup"
if [[ ! -f "${backup_file}" ]]; then
  cp CMakeLists.txt "${backup_file}"
fi

cat > CMakeLists.txt <<'EOF'
# MONAN-JEDI reduced MPAS-JEDI-only bundle for JACI validation.

cmake_minimum_required( VERSION 3.14 FATAL_ERROR )

find_package( ecbuild 3.6 REQUIRED HINTS ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/../ecbuild)

project( monan-jedi-mpas-only VERSION 0.1.0 LANGUAGES C CXX Fortran )

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

include( ecbuild_bundle )
include( GNUInstallDirs )

set( ECBUILD_DEFAULT_BUILD_TYPE Release )
set( ENABLE_MPI ON CACHE BOOL "Compile with MPI" )
set( ENABLE_OMP ON CACHE BOOL "Compile with OpenMP" )
set( Python3_FIND_STRATEGY LOCATION )

set(DEPEND_LIB_ROOT ${CMAKE_CURRENT_BINARY_DIR}/Depends)
list(APPEND CMAKE_PREFIX_PATH ${DEPEND_LIB_ROOT})
link_directories(${CMAKE_CURRENT_BINARY_DIR}/lib)

set(CMAKE_INSTALL_RPATH_USE_LINK_PATH ON)
set(CMAKE_BUILD_WITH_INSTALL_RPATH ON)

ecbuild_bundle_initialize()

if(DEFINED ENV{jedi_cmake_ROOT})
  include( $ENV{jedi_cmake_ROOT}/share/jedicmake/Functions/git_functions.cmake )
else()
  message(FATAL_ERROR "jedi_cmake_ROOT is not defined. Load the spack-stack JEDI environment first.")
endif()

option(BUILD_GSIBEC "Build GSIbec from source" OFF)
if(BUILD_GSIBEC)
  ecbuild_bundle( PROJECT gsibec GIT "https://github.com/geos-esm/GSIbec" TAG 1.2.1 )
endif()

# Common JEDI core needed by MPAS-JEDI.
ecbuild_bundle( PROJECT gsw      GIT "https://github.com/jcsda/GSW-Fortran.git" BRANCH develop UPDATE )
ecbuild_bundle( PROJECT oops     GIT "https://github.com/jcsda/oops.git"        BRANCH develop UPDATE )
ecbuild_bundle( PROJECT vader    GIT "https://github.com/jcsda/vader.git"       BRANCH develop UPDATE )
ecbuild_bundle( PROJECT saber    GIT "https://github.com/jcsda/saber.git"       BRANCH develop UPDATE )
ecbuild_bundle( PROJECT crtm     GIT "https://github.com/jcsda/CRTMv3.git"      BRANCH develop UPDATE )

option(ENABLE_IODA_DATA "Obtain ioda test data from ioda-data repository" ON)
if(ENABLE_IODA_DATA)
  ecbuild_bundle( PROJECT ioda-data GIT "https://github.com/jcsda-internal/ioda-data.git" BRANCH develop UPDATE )
endif()
ecbuild_bundle( PROJECT ioda     GIT "https://github.com/jcsda/ioda.git"        BRANCH develop UPDATE )

option(ENABLE_UFO_DATA "Obtain ufo test data from ufo-data repository" ON)
if(ENABLE_UFO_DATA)
  ecbuild_bundle( PROJECT ufo-data GIT "https://github.com/jcsda-internal/ufo-data.git" BRANCH develop UPDATE )
endif()
ecbuild_bundle( PROJECT ufo      GIT "https://github.com/jcsda/ufo.git"         BRANCH develop UPDATE )

option(BUILD_MPAS "Build mpas-jedi" ON)
if(BUILD_MPAS)
  set(MPAS_DOUBLE_PRECISION "ON" CACHE STRING "MPAS-Model: Use double precision 64-bit floating point.")
  set(MPAS_CORES init_atmosphere atmosphere CACHE STRING "MPAS-Model: cores to build.")
  set(MPAS_OPENMP "ON" CACHE STRING "MPAS-Model: Enable OpenMP.")

  ecbuild_bundle( PROJECT mpas           GIT "https://github.com/MPAS-Dev/MPAS-Model.git" TAG 0e5a47a0e1bcccd6e3d99909b76e740a643c4db6 )
  ecbuild_bundle( PROJECT mpas-jedi-data GIT "https://github.com/jcsda-internal/mpas-jedi-data.git" BRANCH develop UPDATE )
  ecbuild_bundle( PROJECT mpas-jedi      GIT "https://github.com/jcsda/mpas-jedi.git" BRANCH develop UPDATE )
endif()

ecbuild_bundle_finalize()
EOF

{
  echo "JEDI_BUNDLE_SRC_DIR=${JEDI_BUNDLE_SRC_DIR}"
  echo "backup=${backup_file}"
  echo "commit=$(git rev-parse HEAD)"
  echo
  git diff -- CMakeLists.txt || true
} | tee "${MONAN_JEDI_LOG_ROOT}/03_mpas_only_cmake_patch.log"

log_info "Reduced MPAS-JEDI-only CMakeLists.txt generated."
