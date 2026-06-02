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
  install       Install the configured bundle into install.root
  test          Run login-node-safe CTest subset
  test-pbs      Submit CTest to PBS
  obs2ioda      Build and publish NCAR/obs2ioda with the MONAN-JEDI stack
  logs          Collect logs
  all           Run load, configure, build, install, obs2ioda, test, logs

Notes:
  The MONAN-JEDI repository root is the bundle source tree.
  build.dir controls the CMake/ecbuild build tree.
  install.root controls the installation prefix.
  install.bin_dir is the common executable publication directory.
  obs2ioda is built outside the main bundle build tree but published to install.bin_dir.
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
  install)
    monan_jedi_install_bundle
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
    monan_jedi_install_bundle
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
