#!/usr/bin/env bash
# =============================================================================
# Common helpers for MONAN-JEDI JACI workflow
# =============================================================================

set -euo pipefail

log_info()  { printf '[INFO] %s\n' "$*"; }
log_warn()  { printf '[WARN] %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }

require_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    log_error "Required command not found: ${cmd}"
    exit 1
  fi
}

# =============================================================================
# Directory model
# =============================================================================
# MONAN-JEDI consumes a previously installed spack-stack environment.
# The stack may be shared and read-only, while the MONAN-JEDI work and log trees
# belong to the user running this workflow.
#
# Important separation:
#   PROJECT_ROOT            user workspace for MONAN-JEDI builds and logs
#   STACK_ROOT              shared spack-stack installation, usually read-only
#   MONAN_JEDI_WORK_ROOT    user-owned build/source workspace
#   MONAN_JEDI_LOG_ROOT     user-owned logs
#
# Do not source ${STACK_ROOT}/setup.sh in this workflow. That script initializes
# the spack-stack administration environment and may update files inside the
# shared Spack tree. Normal MONAN-JEDI users should consume only the generated
# environment modules.
# =============================================================================

export PROJECT_ROOT="${PROJECT_ROOT:-/p/projetos/monan_das/${USER}}"
export STACK_OWNER="${STACK_OWNER:-${USER}}"
export STACK_TEST_ID="${STACK_TEST_ID:-spack-stack-inpe-overlay-20260515T181917Z}"
export MONAN_JEDI_TEST_ID="${MONAN_JEDI_TEST_ID:-monan-jedi-mpas-only}"

export STACK_WORK_ROOT="${STACK_WORK_ROOT:-/p/projetos/monan_das/${STACK_OWNER}/work/${STACK_TEST_ID}}"
export STACK_ENV_NAME="${STACK_ENV_NAME:-jaci-mpas-jedi-gcc12-craympich}"
export STACK_ROOT="${STACK_ROOT:-${STACK_WORK_ROOT}/spack-stack}"
export STACK_MODULE_ROOT="${STACK_MODULE_ROOT:-${STACK_ROOT}/envs/${STACK_ENV_NAME}/modules}"
export STACK_ENV_MODULE="${STACK_ENV_MODULE:-cray-mpich/8.1.31/none/none/jedi-mpas-env/1.0.0}"

export MONAN_JEDI_WORK_ROOT="${MONAN_JEDI_WORK_ROOT:-${PROJECT_ROOT}/work/${MONAN_JEDI_TEST_ID}}"
export MONAN_JEDI_LOG_ROOT="${MONAN_JEDI_LOG_ROOT:-${PROJECT_ROOT}/logs/${MONAN_JEDI_TEST_ID}}"

export JEDI_BUNDLE_REPO="${JEDI_BUNDLE_REPO:-https://github.com/JCSDA/jedi-bundle.git}"
export JEDI_BUNDLE_REF="${JEDI_BUNDLE_REF:-develop}"
export JEDI_BUNDLE_SRC_DIR="${JEDI_BUNDLE_SRC_DIR:-${MONAN_JEDI_WORK_ROOT}/jedi-bundle}"
export JEDI_BUNDLE_BUILD_DIR="${JEDI_BUNDLE_BUILD_DIR:-${MONAN_JEDI_WORK_ROOT}/build-jedi-bundle-mpas-only}"

validate_monan_jedi_paths() {
  local vars=(
    PROJECT_ROOT
    STACK_WORK_ROOT
    STACK_ROOT
    STACK_MODULE_ROOT
    MONAN_JEDI_WORK_ROOT
    MONAN_JEDI_LOG_ROOT
    JEDI_BUNDLE_SRC_DIR
    JEDI_BUNDLE_BUILD_DIR
  )

  local var value
  for var in "${vars[@]}"; do
    value="${!var:-}"
    if [[ -z "${value}" ]]; then
      log_error "Required path variable is empty: ${var}"
      exit 1
    fi
    if [[ "${value}" == *"}" ]]; then
      log_error "Invalid trailing brace detected in ${var}: ${value}"
      log_error "Check exported variables and scripts/00_common.sh."
      exit 1
    fi
  done
}

validate_monan_jedi_paths
mkdir -p "${MONAN_JEDI_WORK_ROOT}" "${MONAN_JEDI_LOG_ROOT}"

reset_jaci_modules() {
  # Start from a clean module state. This avoids conflicts when the user shell
  # already has generated Spack modules loaded, for example gcc/12.3.0/zstd/1.5.7.
  module --force purge 2>/dev/null || module purge 2>/dev/null || true

  for d in \
    /opt/cray/pe/modulefiles \
    /opt/cray/modulefiles \
    /opt/cray/pe/craype-targets/default/modulefiles \
    /p/app/modulefiles \
    /opt/cray/pals/modulefiles
  do
    if [[ -d "${d}" ]]; then
      module use "${d}"
    fi
  done
}

load_monan_jedi_stack() {
  if [[ ! -d "${STACK_ROOT}" ]]; then
    log_error "STACK_ROOT not found: ${STACK_ROOT}"
    log_error "Create and validate the stack first using spack-stack-inpe, or set STACK_ROOT explicitly."
    exit 1
  fi

  if [[ ! -d "${STACK_MODULE_ROOT}" ]]; then
    log_error "STACK_MODULE_ROOT not found: ${STACK_MODULE_ROOT}"
    log_error "Run module generation in spack-stack-inpe first, or set STACK_MODULE_ROOT explicitly."
    exit 1
  fi

  reset_jaci_modules

  # Load the JACI site baseline from the shared stack configuration. This sets
  # the CrayPE programming environment and compiler drivers, but does not source
  # the spack-stack administration setup.
  # shellcheck disable=SC1091
  source "${STACK_ROOT}/configs/sites/tier2/jaci/setup.sh"

  # Load only the generated environment module. This is the user-mode interface
  # to a shared spack-stack installation.
  module use "${STACK_MODULE_ROOT}"
  module load "${STACK_ENV_MODULE}"

  export CC="$(command -v cc)"
  export CXX="$(command -v CC)"
  export FC="$(command -v ftn)"
  export F77="${FC}"
  export F90="${FC}"
  export MPICC="${CC}"
  export MPICXX="${CXX}"
  export MPIFC="${FC}"
  export MPIF77="${FC}"
  export MPIF90="${FC}"

  log_info "Loaded MONAN-JEDI stack environment in user mode"
  log_info "  PROJECT_ROOT=${PROJECT_ROOT}"
  log_info "  STACK_ROOT=${STACK_ROOT}"
  log_info "  STACK_MODULE_ROOT=${STACK_MODULE_ROOT}"
  log_info "  STACK_ENV_MODULE=${STACK_ENV_MODULE}"
  log_info "  MONAN_JEDI_WORK_ROOT=${MONAN_JEDI_WORK_ROOT}"
  log_info "  MONAN_JEDI_LOG_ROOT=${MONAN_JEDI_LOG_ROOT}"
  log_info "  CC=${CC}"
  log_info "  CXX=${CXX}"
  log_info "  FC=${FC}"
}

record_environment_snapshot() {
  local output_file="$1"
  {
    echo "GeneratedAt=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "PROJECT_ROOT=${PROJECT_ROOT}"
    echo "STACK_OWNER=${STACK_OWNER}"
    echo "STACK_TEST_ID=${STACK_TEST_ID}"
    echo "STACK_WORK_ROOT=${STACK_WORK_ROOT}"
    echo "STACK_ROOT=${STACK_ROOT}"
    echo "STACK_ENV_NAME=${STACK_ENV_NAME}"
    echo "STACK_MODULE_ROOT=${STACK_MODULE_ROOT}"
    echo "STACK_ENV_MODULE=${STACK_ENV_MODULE}"
    echo "MONAN_JEDI_TEST_ID=${MONAN_JEDI_TEST_ID}"
    echo "MONAN_JEDI_WORK_ROOT=${MONAN_JEDI_WORK_ROOT}"
    echo "MONAN_JEDI_LOG_ROOT=${MONAN_JEDI_LOG_ROOT}"
    echo "JEDI_BUNDLE_REPO=${JEDI_BUNDLE_REPO}"
    echo "JEDI_BUNDLE_REF=${JEDI_BUNDLE_REF}"
    echo "JEDI_BUNDLE_SRC_DIR=${JEDI_BUNDLE_SRC_DIR}"
    echo "JEDI_BUNDLE_BUILD_DIR=${JEDI_BUNDLE_BUILD_DIR}"
    echo
    echo "module list:"
    module list 2>&1 || true
    echo
    echo "tool resolution:"
    command -v ecbuild || true
    command -v cmake || true
    command -v make || true
    command -v ctest || true
    command -v python || true
    echo
    echo "compiler variables:"
    echo "CC=${CC:-}"
    echo "CXX=${CXX:-}"
    echo "FC=${FC:-}"
    echo "MPICC=${MPICC:-}"
    echo "MPICXX=${MPICXX:-}"
    echo "MPIFC=${MPIFC:-}"
    echo
    echo "CMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH:-}"
  } | tee "${output_file}"
}
