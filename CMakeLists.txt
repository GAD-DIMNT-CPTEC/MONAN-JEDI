# MONAN-JEDI reduced MPAS-JEDI-only bundle for JACI validation.
#
# This is the project-controlled bundle definition used by MONAN-JEDI.
# It was derived from the JCSDA jedi-bundle workflow and reduced for the
# MPAS-JEDI-only validation workflow on JACI.
#
# The original upstream reference must be documented in docs/BUNDLE_ORIGIN.md.
# This repository now owns this CMakeLists.txt directly instead of cloning
# jedi-bundle and replacing its top-level CMakeLists.txt during the build.
#
# This file does not create or modify the Spack-stack environment. The required
# software stack must already have been created and validated separately.

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
ecbuild_bundle( PROJECT gsw      GIT "https://github.com/jcsda/GSW-Fortran.git" TAG 697cbeb7605d70ed3857664c5f54a5c05346e31f)
ecbuild_bundle( PROJECT oops     GIT "https://github.com/jcsda/oops.git"        TAG 192c83c4d706017d906ec0ad58d27e4093c7dced)
ecbuild_bundle( PROJECT vader    GIT "https://github.com/jcsda/vader.git"       TAG f74de9519c02084ac4ed80738374ddf1d7771e44)
ecbuild_bundle( PROJECT saber    GIT "https://github.com/jcsda/saber.git"       TAG d05c06fcc7da97389a19594a2e5424e709648330)
ecbuild_bundle( PROJECT crtm     GIT "https://github.com/jcsda/CRTMv3.git"      TAG 9b63e4ef162e4738ec807938122f2e21296a629a)

option(ENABLE_IODA_DATA "Obtain ioda test data from ioda-data repository" ON)
if(ENABLE_IODA_DATA)
  ecbuild_bundle( PROJECT ioda-data GIT "https://github.com/jcsda-internal/ioda-data.git" TAG f0f963eef555c6d7ce8b22da490128374da75bc7)
endif()
ecbuild_bundle( PROJECT ioda     GIT "https://github.com/jcsda/ioda.git"        TAG 1d390ad1c719cf9f8a30ff2f1e137461e4b925f9)

option(ENABLE_UFO_DATA "Obtain ufo test data from ufo-data repository" ON)
if(ENABLE_UFO_DATA)
  ecbuild_bundle( PROJECT ufo-data GIT "https://github.com/jcsda-internal/ufo-data.git" TAG d8c77d388cd43b017fce3964b5a6c90e371015a7)
endif()
ecbuild_bundle( PROJECT ufo      GIT "https://github.com/jcsda/ufo.git"         TAG 90979fa048477f2b240117d98efd1d1bfa8acd4d)

option(BUILD_MPAS "Build mpas-jedi" ON)
if(BUILD_MPAS)
  set(MPAS_DOUBLE_PRECISION "ON" CACHE STRING "MPAS-Model: Use double precision 64-bit floating point.")
  set(MPAS_CORES init_atmosphere atmosphere CACHE STRING "MPAS-Model: cores to build.")
  set(MPAS_OPENMP "ON" CACHE STRING "MPAS-Model: Enable OpenMP.")

  ecbuild_bundle( PROJECT mpas           GIT "https://github.com/MPAS-Dev/MPAS-Model.git" TAG 0e5a47a0e1bcccd6e3d99909b76e740a643c4db6 )
  ecbuild_bundle( PROJECT mpas-jedi-data GIT "https://github.com/jcsda-internal/mpas-jedi-data.git" TAG 3307edcdb27cef650fe121367c3bb48d6cfa968b)
  ecbuild_bundle( PROJECT mpas-jedi      GIT "https://github.com/jcsda/mpas-jedi.git" TAG 19eb7fb3273c7b3094825201af184834c15afdd0)
endif()

ecbuild_bundle_finalize()
