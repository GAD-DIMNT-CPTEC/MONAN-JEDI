#!/usr/bin/env bash
# MONAN-JEDI workflow orchestrator.

set -euo pipefail
umask 002

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/lib/common.sh"
source "${script_dir}/lib/config.sh"
source "${script_dir}/lib/stack.sh"
source "${script_dir}/lib/test_data.sh"
source "${script_dir}/lib/configure.sh"
source "${script_dir}/lib/build.sh"
source "${script_dir}/lib/test.sh"
source "${script_dir}/lib/pbs.sh"
source "${script_dir}/lib/pbs_result.sh"
source "${script_dir}/lib/logs.sh"
source "${script_dir}/lib/obs2ioda.sh"
source "${script_dir}/lib/wps.sh"
source "${script_dir}/lib/install_test.sh"

usage() {
  cat <<'EOF_USAGE'
Usage:
  bash scripts/monan-jedi.sh <command> [--config config/jaci.yaml]

Commands:
  load             Load and validate the spack-stack environment
  configure        Configure the MONAN-JEDI bundle with ecbuild
  build            Build the configured bundle
  install          Install the configured bundle into install.root
  test             Run the login-node-safe CTest subset
  test-install     Validate the installed runtime contract and dependencies
  test-pbs         Submit CTest to PBS
  test-pbs-result  Validate the most recent PBS CTest result
  obs2ioda         Build and publish NCAR/obs2ioda
  wps              Build, validate and publish WPS/UNGRIB
  test-wps         Validate the published WPS/UNGRIB installation
  logs             Collect workflow logs
  all              Run the bundle, auxiliaries and installed-runtime validation
EOF_USAGE
}

monan_jedi_report_git_lfs_status() {
  if monan_jedi_git_lfs_available; then
    return 0
  fi

  log_warn "Git LFS is not currently available after loading the MONAN-JEDI stack."
  log_warn "  project_fallback_env=$(monan_jedi_git_lfs_root)"
  log_warn "The load command can continue, but configure/all will require Git LFS."
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
    monan_jedi_report_git_lfs_status
    monan_jedi_record_environment_snapshot "${MONAN_JEDI_LOG_ROOT}/01_stack_environment.log"
    ;;
  configure) monan_jedi_configure_bundle ;;
  build) monan_jedi_build_bundle ;;
  install) monan_jedi_install_bundle ;;
  test) monan_jedi_test_login ;;
  test-install) monan_jedi_test_install ;;
  test-pbs)
    # Preflight must use the same validated environment as configure/build.
    # Preserve the checkout directory because monan_jedi_load_stack enters the
    # stack root while initializing modules, whereas PBS generation must record
    # the MONAN-JEDI repository as its working directory.
    (
      test_pbs_repo_dir="$(pwd)"
      monan_jedi_load_stack
      cd "${test_pbs_repo_dir}" || {
        log_error "Failed to return to MONAN-JEDI repository: ${test_pbs_repo_dir}"
        exit 1
      }
      monan_jedi_report_git_lfs_status
      monan_jedi_test_pbs
    )
    ;;
  test-pbs-result) monan_jedi_test_pbs_result ;;
  obs2ioda) monan_jedi_build_obs2ioda ;;
  wps) monan_jedi_build_wps ;;
  test-wps) monan_jedi_test_wps ;;
  logs) monan_jedi_collect_logs ;;
  all)
    monan_jedi_load_stack
    monan_jedi_report_git_lfs_status
    monan_jedi_record_environment_snapshot "${MONAN_JEDI_LOG_ROOT}/01_stack_environment.log"
    monan_jedi_configure_bundle
    monan_jedi_build_bundle
    monan_jedi_install_bundle
    if monan_jedi_obs2ioda_enabled; then monan_jedi_build_obs2ioda; fi
    if monan_jedi_wps_enabled; then monan_jedi_build_wps; fi
    monan_jedi_test_login

    # Always collect the final log summary, including a failed installation
    # validation. This makes `all` end with one compact diagnostic record while
    # still returning non-zero when the installed runtime is unusable.
    all_install_test_status=0
    monan_jedi_test_install || all_install_test_status=$?
    monan_jedi_collect_logs
    if [[ "${all_install_test_status}" -ne 0 ]]; then
      log_error "MONAN-JEDI all failed installed-runtime validation."
      exit "${all_install_test_status}"
    fi
    ;;
  ""|-h|--help) usage ;;
  *) log_error "Unknown command: ${command_name}"; usage; exit 1 ;;
esac
