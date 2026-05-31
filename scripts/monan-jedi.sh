#!/usr/bin/env bash
# =============================================================================
# MONAN-JEDI workflow orchestrator
# =============================================================================

set -euo pipefail

# Keep generated files group-writable by default on shared project areas.
# This supports collaborative validation under the monan_das group without
# opening permissions to all users.
umask 002

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/common.sh
source "${script_dir}/lib/common.sh"
# shellcheck source=lib/config.sh
source "${script_dir}/lib/config.sh"
# shellcheck source=lib/stack.sh
source "${script_dir}/lib/stack.sh"
# shellcheck source=lib/configure.sh
source "${script_dir}/lib/configure.sh"
# shellcheck source=lib/build.sh
source "${script_dir}/lib/build.sh"
# shellcheck source=lib/test.sh
source "${script_dir}/lib/test.sh"
# shellcheck source=lib/pbs.sh
source "${script_dir}/lib/pbs.sh"
# shellcheck source=lib/logs.sh
source "${script_dir}/lib/logs.sh"
# shellcheck source=lib/obs2ioda.sh
source "${script_dir}/lib/obs2ioda.sh"

usage() {
  cat <<EOF
Usage:
  bash scripts/monan-jedi.sh <command> [--config config/jaci.yaml]

Commands:
  load          Load and validate the spack-stack environment
  configure     Configure the MONAN-JEDI bundle with ecbuild
  build         Build the configured bundle
  test          Run login-node-safe CTest subset
  test-pbs      Submit CTest to PBS
  obs2ioda      Build NCAR/obs2ioda with the MONAN-JEDI stack environment
  logs          Collect logs
  all           Run load, configure, build, test, logs

Notes:
  The MONAN-JEDI repository root is now the bundle source tree.
  Commands prepare and reduce were removed from the main workflow.
  Generated files use umask 002 to remain writable by the project group.
  MPAS precision is configured in YAML with model.double_precision.
  Use ON for CTest validation and OFF only when a workflow/tutorial requires single precision.
  obs2ioda is built as an auxiliary executable outside the main bundle build tree.
EOF
}

command_name="${1:-}"
shift || true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      export MONAN_JEDI_CONFIG="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log_error "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

load_monan_jedi_config

case "${command_name}" in
  load)
    monan_jedi_load_stack
    monan_jedi_record_environment_snapshot "${MONAN_JEDI_LOG_ROOT}/01_stack_environment.log"
    ;;
  configure)
    monan_jedi_configure_bundle
    ;;
  build)
    monan_jedi_build_bundle
    ;;
  test)
    monan_jedi_test_login
    ;;
  test-pbs)
    monan_jedi_test_pbs
    ;;
  obs2ioda)
    monan_jedi_build_obs2ioda
    ;;
  logs)
    monan_jedi_collect_logs
    ;;
  all)
    monan_jedi_load_stack
    monan_jedi_record_environment_snapshot "${MONAN_JEDI_LOG_ROOT}/01_stack_environment.log"
    monan_jedi_configure_bundle
    monan_jedi_build_bundle
    monan_jedi_build_obs2ioda
    monan_jedi_test_login
    monan_jedi_collect_logs
    ;;
  ""|-h|--help)
    usage
    ;;
  *)
    log_error "Unknown command: ${command_name}"
    usage
    exit 1
    ;;
esac
