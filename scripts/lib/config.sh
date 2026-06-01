#!/usr/bin/env bash
# YAML configuration loader for MONAN-JEDI.

load_monan_jedi_config() {
  local default_config="config/jaci.yaml"
  local repo_root

  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

  export MONAN_JEDI_CONFIG="${MONAN_JEDI_CONFIG:-${default_config}}"

  if [[ ! -f "${MONAN_JEDI_CONFIG}" ]]; then
    log_error "Configuration file not found: ${MONAN_JEDI_CONFIG}"
    exit 1
  fi

  require_cmd python3

  # shellcheck disable=SC1090
  eval "$(python3 "$(dirname "${BASH_SOURCE[0]}")/read_config.py" "${MONAN_JEDI_CONFIG}")"

  export PROJECT_ROOT="${PROJECT_ROOT:-/p/projetos/monan_das/${USER}}"
  export STACK_OWNER="${STACK_OWNER:-${USER}}"

  if [[ -z "${STACK_INSTANCE:-}" ]]; then
    log_error "STACK_INSTANCE is empty. Set stack.instance in ${MONAN_JEDI_CONFIG}."
    exit 1
  fi

  if [[ -z "${STACK_ENV_NAME:-}" ]]; then
    log_error "STACK_ENV_NAME is empty. Set stack.env_name in ${MONAN_JEDI_CONFIG}."
    exit 1
  fi

  if [[ -z "${MONAN_JEDI_RUN_ID:-}" ]]; then
    log_error "MONAN_JEDI_RUN_ID is empty. Set build.id in ${MONAN_JEDI_CONFIG}."
    exit 1
  fi

  export STACK_WORK_ROOT="${STACK_WORK_ROOT:-/p/projetos/monan_das/${STACK_OWNER}/work/${STACK_INSTANCE}}"
  export STACK_ROOT="${STACK_ROOT:-${STACK_WORK_ROOT}/spack-stack}"
  export STACK_MODULE_ROOT="${STACK_MODULE_ROOT:-${STACK_ROOT}/envs/${STACK_ENV_NAME}/modules}"

  export MONAN_JEDI_WORK_ROOT="${MONAN_JEDI_WORK_ROOT:-${PROJECT_ROOT}/work/${MONAN_JEDI_RUN_ID}}"
  export MONAN_JEDI_LOG_ROOT="${MONAN_JEDI_LOG_ROOT:-${PROJECT_ROOT}/logs/${MONAN_JEDI_RUN_ID}}"

  # Source, build and install trees are intentionally independent.
  #
  # MONAN_JEDI_SOURCE_DIR is the repository root and normally should not be
  # changed by site YAML files. MONAN_JEDI_BUILD_DIR is the CMake/ecbuild build
  # tree. MONAN_JEDI_INSTALL_ROOT is the install prefix used by make install and
  # by auxiliary tools such as obs2ioda. MONAN_JEDI_INSTALL_BIN_DIR is the common
  # publication directory for final executables.
  export MONAN_JEDI_SOURCE_DIR="${MONAN_JEDI_SOURCE_DIR:-${repo_root}}"
  export MONAN_JEDI_BUILD_DIR="${MONAN_JEDI_BUILD_DIR:-${MONAN_JEDI_WORK_ROOT}/build}"
  export MONAN_JEDI_INSTALL_ROOT="${MONAN_JEDI_INSTALL_ROOT:-${PROJECT_ROOT}/builds/${MONAN_JEDI_RUN_ID}}"
  export MONAN_JEDI_INSTALL_BIN_DIR="${MONAN_JEDI_INSTALL_BIN_DIR:-${MONAN_JEDI_INSTALL_ROOT}/bin}"

  export MONAN_JEDI_CRTM_COEFFS_URL="${MONAN_JEDI_CRTM_COEFFS_URL:-https://bin.ssec.wisc.edu/pub/s4/CRTM/fix_REL-3.1.2.0.tgz}"
  export MONAN_JEDI_CRTM_COEFFS_TGZ="${MONAN_JEDI_CRTM_COEFFS_TGZ:-${MONAN_JEDI_WORK_ROOT}/cache/crtm/fix_REL-3.1.2.0.tgz}"

  export MONAN_JEDI_OBS2IODA_SOURCE_DIR="${MONAN_JEDI_OBS2IODA_SOURCE_DIR:-${MONAN_JEDI_WORK_ROOT}/obs2ioda/src}"
  export MONAN_JEDI_OBS2IODA_BUILD_DIR="${MONAN_JEDI_OBS2IODA_BUILD_DIR:-${MONAN_JEDI_WORK_ROOT}/obs2ioda/build}"
  export MONAN_JEDI_OBS2IODA_INSTALL_DIR="${MONAN_JEDI_OBS2IODA_INSTALL_DIR:-${MONAN_JEDI_INSTALL_ROOT}}"
  export MONAN_JEDI_OBS2IODA_EXECUTABLE_NAME="${MONAN_JEDI_OBS2IODA_EXECUTABLE_NAME:-obs2ioda_v3}"

  mkdir -p \
    "${MONAN_JEDI_WORK_ROOT}" \
    "${MONAN_JEDI_LOG_ROOT}" \
    "${MONAN_JEDI_BUILD_DIR}" \
    "${MONAN_JEDI_INSTALL_BIN_DIR}" \
    "$(dirname "${MONAN_JEDI_CRTM_COEFFS_TGZ}")"
}
