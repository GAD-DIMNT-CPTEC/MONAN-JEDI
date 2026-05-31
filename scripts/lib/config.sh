#!/usr/bin/env bash
# YAML configuration loader for MONAN-JEDI.
#
# Purpose:
#   Read the selected YAML configuration file and export the environment
#   variables used by the MONAN-JEDI workflow.
#
# Configuration model:
#   The YAML file separates:
#
#     stack.*
#       Shared spack-stack installation and module environment.
#
#     build.*
#       User-owned MONAN-JEDI workflow instance.
#
#     obs2ioda.*
#       Auxiliary NCAR/obs2ioda source, build and install settings.
#
#     compilers.*, mpi.*
#       Compiler and MPI wrapper commands.
#
#     ctest.*, pbs.*
#       Test and batch-system settings.
#
# Expected result:
#   After load_monan_jedi_config completes, the workflow modules can use the
#   derived stack paths, work paths, log paths, source path, build path and tool
#   variables without reading the YAML file again.

load_monan_jedi_config() {
  local default_config="config/jaci.yaml"
  local repo_root

  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

  # Allow the user to override the configuration file while keeping the JACI
  # configuration as the default workflow entry point.
  export MONAN_JEDI_CONFIG="${MONAN_JEDI_CONFIG:-${default_config}}"

  if [[ ! -f "${MONAN_JEDI_CONFIG}" ]]; then
    log_error "Configuration file not found: ${MONAN_JEDI_CONFIG}"
    exit 1
  fi

  require_cmd python3

  # Convert YAML values into shell exports. The output is generated with shell
  # quoting by read_config.py and is evaluated in the current shell.
  # shellcheck disable=SC1090
  eval "$(python3 "$(dirname "${BASH_SOURCE[0]}")/read_config.py" "${MONAN_JEDI_CONFIG}")"

  # PROJECT_ROOT is the user-owned workspace root. STACK_OWNER may be different
  # from USER when the spack-stack installation is shared by another account.
  export PROJECT_ROOT="${PROJECT_ROOT:-/p/projetos/monan_das/${USER}}"
  export STACK_OWNER="${STACK_OWNER:-${USER}}"

  # These identifiers define the stack instance, stack environment and workflow
  # instance. Empty values would make the derived paths unsafe or ambiguous.
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

  # The stack may be owned by another account, while PROJECT_ROOT is the
  # user-owned MONAN-JEDI workspace. Do not derive STACK_WORK_ROOT from
  # PROJECT_ROOT unless stack.work_root is explicitly set that way.
  export STACK_WORK_ROOT="${STACK_WORK_ROOT:-/p/projetos/monan_das/${STACK_OWNER}/work/${STACK_INSTANCE}}"
  export STACK_ROOT="${STACK_ROOT:-${STACK_WORK_ROOT}/spack-stack}"
  export STACK_MODULE_ROOT="${STACK_MODULE_ROOT:-${STACK_ROOT}/envs/${STACK_ENV_NAME}/modules}"

  # User-owned workflow directories. Logs are kept outside the repository by
  # default, while the build tree defaults to ${repo_root}/build so manual and
  # scripted workflows use the same location.
  export MONAN_JEDI_WORK_ROOT="${MONAN_JEDI_WORK_ROOT:-${PROJECT_ROOT}/work/${MONAN_JEDI_RUN_ID}}"
  export MONAN_JEDI_LOG_ROOT="${MONAN_JEDI_LOG_ROOT:-${PROJECT_ROOT}/logs/${MONAN_JEDI_RUN_ID}}"

  # The MONAN-JEDI repository root is now the bundle source tree. Keep the old
  # JEDI_BUNDLE_* variable names as compatibility aliases for test and PBS code.
  export MONAN_JEDI_SOURCE_DIR="${MONAN_JEDI_SOURCE_DIR:-${repo_root}}"
  export MONAN_JEDI_BUILD_DIR="${MONAN_JEDI_BUILD_DIR:-${MONAN_JEDI_SOURCE_DIR}/build}"
  export JEDI_BUNDLE_SRC_DIR="${JEDI_BUNDLE_SRC_DIR:-${MONAN_JEDI_SOURCE_DIR}}"
  export JEDI_BUNDLE_BUILD_DIR="${JEDI_BUNDLE_BUILD_DIR:-${MONAN_JEDI_BUILD_DIR}}"

  # obs2ioda is an auxiliary executable built with the same stack environment,
  # but outside the main MONAN-JEDI bundle build tree.
  export MONAN_JEDI_OBS2IODA_SOURCE_DIR="${MONAN_JEDI_OBS2IODA_SOURCE_DIR:-${PROJECT_ROOT}/work/obs2ioda}"
  export MONAN_JEDI_OBS2IODA_BUILD_DIR="${MONAN_JEDI_OBS2IODA_BUILD_DIR:-${PROJECT_ROOT}/work/obs2ioda/build}"
  export MONAN_JEDI_OBS2IODA_INSTALL_DIR="${MONAN_JEDI_OBS2IODA_INSTALL_DIR:-${PROJECT_ROOT}/install/obs2ioda}"

  mkdir -p "${MONAN_JEDI_WORK_ROOT}" "${MONAN_JEDI_LOG_ROOT}"
}
