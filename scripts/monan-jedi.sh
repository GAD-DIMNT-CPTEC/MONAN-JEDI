#!/usr/bin/env bash
# =============================================================================
# MONAN-JEDI workflow orchestrator
# =============================================================================

set -euo pipefail
umask 002

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/lib/common.sh"
source "${script_dir}/lib/config.sh"
source "${script_dir}/lib/stack.sh"
source "${script_dir}/lib/configure.sh"
source "${script_dir}/lib/build.sh"
source "${script_dir}/lib/test.sh"
source "${script_dir}/lib/pbs.sh"
source "${script_dir}/lib/logs.sh"
source "${script_dir}/lib/obs2ioda.sh"
source "${script_dir}/lib/wps.sh"

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
  wps           Build and publish WPS/UNGRIB with the MONAN-JEDI stack
  logs          Collect logs
  all           Run load, configure, build, install, enabled tools, test, logs

WPS requires an explicit numeric wps.configure_option from the JACI GRIB2
configure menu. It is built outside the main bundle and published under the
same install root used by the MONAN-JEDI executables.
EOF
}

command_name="${1:-}"
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) export MONAN_JEDI_CONFIG="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) log_error "Unknown argument: $1"; usage; exit 1 ;;
  esac
done

load_monan_jedi_config
case "${command_name}" in
  load)
    monan_jedi_load_stack
    monan_jedi_record_environment_snapshot "${MONAN_JEDI_LOG_ROOT}/01_stack_environment.log"
    ;;
  configure) monan_jedi_configure_bundle ;;
  build) monan_jedi_build_bundle ;;
  install) monan_jedi_install_bundle ;;
  test) monan_jedi_test_login ;;
  test-pbs) monan_jedi_test_pbs ;;
  obs2ioda) monan_jedi_build_obs2ioda ;;
  wps) monan_jedi_build_wps ;;
  logs) monan_jedi_collect_logs ;;
  all)
    monan_jedi_load_stack
    monan_jedi_record_environment_snapshot "${MONAN_JEDI_LOG_ROOT}/01_stack_environment.log"
    monan_jedi_configure_bundle
    monan_jedi_build_bundle
    monan_jedi_install_bundle
    monan_jedi_build_obs2ioda
    monan_jedi_load_wps_config
    if monan_jedi_wps_enabled; then monan_jedi_build_wps; fi
    monan_jedi_test_login
    monan_jedi_collect_logs
    ;;
  ""|-h|--help) usage ;;
  *) log_error "Unknown command: ${command_name}"; usage; exit 1 ;;
esac
