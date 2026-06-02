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
}

monan_jedi_install_bundle() {
  monan_jedi_load_stack
  require_cmd make

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
}
