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
#     compilers.*, mpi.*
#       Compiler and MPI wrapper commands.
#
#     ctest.*, pbs.*
#       Test and batch-system settings.
#
# Expected result:
#   After load_monan_jedi_config completes, the workflow modules can use the
#   derived stack paths, work paths, log paths, JEDI bundle paths and tool
#   variables without reading the YAML file again.

load_monan_jedi_config() {
  local default_config="config/jaci.yaml"

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

  # User-owned workflow directories. They are intentionally derived separately
  # from the shared spack-stack installation.
  export MONAN_JEDI_WORK_ROOT="${MONAN_JEDI_WORK_ROOT:-${PROJECT_ROOT}/work/${MONAN_JEDI_RUN_ID}}"
  export MONAN_JEDI_LOG_ROOT="${MONAN_JEDI_LOG_ROOT:-${PROJECT_ROOT}/logs/${MONAN_JEDI_RUN_ID}}"

  # Default JEDI bundle source and build paths for the selected run id.
  export JEDI_BUNDLE_SRC_DIR="${JEDI_BUNDLE_SRC_DIR:-${MONAN_JEDI_WORK_ROOT}/jedi-bundle}"
  export JEDI_BUNDLE_BUILD_DIR="${JEDI_BUNDLE_BUILD_DIR:-${MONAN_JEDI_WORK_ROOT}/build-jedi-bundle-mpas-only}"

  mkdir -p "${MONAN_JEDI_WORK_ROOT}" "${MONAN_JEDI_LOG_ROOT}"
}
