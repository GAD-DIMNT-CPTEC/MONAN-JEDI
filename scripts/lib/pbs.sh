#!/usr/bin/env bash
# PBS test submission for the MONAN-JEDI reduced MPAS-JEDI workflow.
#
# Purpose:
#   Submit the complete configured JEDI/MPAS-JEDI CTest suite to a JACI PBS
#   compute node. This is required for the full test suite because many tests
#   use MPI and must not be executed directly on login nodes.
#
# Requires:
#   A configured and built JEDI bundle under JEDI_BUNDLE_BUILD_DIR.
#   qsub available in PATH.
#
# Produces:
#   ${MONAN_JEDI_LOG_ROOT}/11_jedi_all_tests.pbs
#   ${MONAN_JEDI_LOG_ROOT}/11_ctest_all_pbs.out
#   ${MONAN_JEDI_LOG_ROOT}/11_ctest_all_pbs.log
#   ${MONAN_JEDI_LOG_ROOT}/11_ctest_all_pbs_jobid.txt, when submitted
#
# Expected result:
#   The PBS job runs ctest without a broad -R selection. If
#   MONAN_JEDI_CTEST_EXCLUDE_REGEX is set, the listed known-failing tests are
#   excluded with ctest -E.

monan_jedi_test_pbs() {
  require_cmd qsub

  if [[ ! -d "${JEDI_BUNDLE_BUILD_DIR}" ]]; then
    log_error "JEDI_BUNDLE_BUILD_DIR not found: ${JEDI_BUNDLE_BUILD_DIR}"
    exit 1
  fi

  if [[ ! -f "${JEDI_BUNDLE_BUILD_DIR}/CTestTestfile.cmake" ]]; then
    log_error "Build tree does not contain CTestTestfile.cmake: ${JEDI_BUNDLE_BUILD_DIR}"
    exit 1
  fi

  # The PBS job must be able to cd back into the repository from the compute
  # node. Restrict execution to shared filesystems used on JACI.
  case "${PWD}" in
    /p/*|/lustre/*) ;;
    *)
      log_error "Current repository directory is not under /p or /lustre: ${PWD}"
      exit 1
      ;;
  esac

  local script_dir repo_dir test_stamp
  local pbs_script pbs_log ctest_log
  local latest_pbs_script latest_pbs_log latest_pbs_err latest_ctest_log

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  repo_dir="$(pwd)"
  test_stamp="${MONAN_JEDI_TEST_LOG_STAMP:-$(date -u +%Y%m%dT%H%M%SZ)}"

  # Default PBS and CTest settings. The YAML configuration or environment can
  # override these values before this routine is called.
  export MONAN_JEDI_PBS_QUEUE="${MONAN_JEDI_PBS_QUEUE:-pesqmini}"
  export MONAN_JEDI_PBS_NCPUS="${MONAN_JEDI_PBS_NCPUS:-64}"
  export MONAN_JEDI_PBS_WALLTIME="${MONAN_JEDI_PBS_WALLTIME:-06:00:00}"
  export MONAN_JEDI_CTEST_JOBS="${MONAN_JEDI_CTEST_JOBS:-1}"
  export MONAN_JEDI_CTEST_EXCLUDE_REGEX="${MONAN_JEDI_CTEST_EXCLUDE_REGEX:-^(ioda_bufr_python_encoder|ioda_bufr_python_parallel|mpasjedi_lgetkf_height_vloc)$}"
  export MONAN_JEDI_SUBMIT_JOB="${MONAN_JEDI_SUBMIT_JOB:-1}"

  mkdir -p "${MONAN_JEDI_LOG_ROOT}"

  # Timestamped files keep previous runs available. The 11_* files provide
  # stable names for the most recent PBS and CTest execution.
  pbs_script="${MONAN_JEDI_LOG_ROOT}/jedi_all_tests_${test_stamp}.pbs"
  pbs_log="${MONAN_JEDI_LOG_ROOT}/jedi_all_tests_${test_stamp}.pbs.log"
  ctest_log="${MONAN_JEDI_LOG_ROOT}/jedi_all_tests_${test_stamp}.ctest.log"
  latest_pbs_script="${MONAN_JEDI_LOG_ROOT}/11_jedi_all_tests.pbs"
  latest_pbs_log="${MONAN_JEDI_LOG_ROOT}/11_ctest_all_pbs.out"
  latest_pbs_err="${MONAN_JEDI_LOG_ROOT}/11_ctest_all_pbs.err"
  latest_ctest_log="${MONAN_JEDI_LOG_ROOT}/11_ctest_all_pbs.log"

  # Generate the PBS job script with the current configuration exported
  # explicitly. This makes the job reproducible from the submitted script alone.
  cat > "${pbs_script}" <<EOF
#!/bin/bash
#PBS -N jedi_all_ctest
#PBS -q ${MONAN_JEDI_PBS_QUEUE}
#PBS -l select=1:ncpus=${MONAN_JEDI_PBS_NCPUS}
#PBS -l walltime=${MONAN_JEDI_PBS_WALLTIME}
#PBS -j oe
#PBS -o ${pbs_log}

set -euo pipefail

# Keep CTest logs and generated files writable by the project group.
umask 002

cd ${repo_dir}

export MONAN_JEDI_CONFIG=${MONAN_JEDI_CONFIG}
export PROJECT_ROOT=${PROJECT_ROOT}
export STACK_OWNER=${STACK_OWNER}
export STACK_INSTANCE=${STACK_INSTANCE}
export STACK_WORK_ROOT=${STACK_WORK_ROOT}
export STACK_ENV_NAME=${STACK_ENV_NAME}
export STACK_ROOT=${STACK_ROOT}
export STACK_MODULE_ROOT=${STACK_MODULE_ROOT}
export STACK_SITE_SETUP=${STACK_SITE_SETUP}
export STACK_ENV_MODULE=${STACK_ENV_MODULE}
export MONAN_JEDI_RUN_ID=${MONAN_JEDI_RUN_ID}
export MONAN_JEDI_WORK_ROOT=${MONAN_JEDI_WORK_ROOT}
export MONAN_JEDI_LOG_ROOT=${MONAN_JEDI_LOG_ROOT}
export JEDI_BUNDLE_SRC_DIR=${JEDI_BUNDLE_SRC_DIR}
export JEDI_BUNDLE_BUILD_DIR=${JEDI_BUNDLE_BUILD_DIR}
export MONAN_JEDI_CTEST_EXCLUDE_REGEX='${MONAN_JEDI_CTEST_EXCLUDE_REGEX}'
export MONAN_JEDI_CTEST_JOBS=${MONAN_JEDI_CTEST_JOBS}
export CTEST_LOG='${ctest_log}'
export LATEST_CTEST_LOG='${latest_ctest_log}'

source ${script_dir}/lib/common.sh
source ${script_dir}/lib/config.sh
source ${script_dir}/lib/stack.sh
load_monan_jedi_config
monan_jedi_load_stack

cd "${JEDI_BUNDLE_BUILD_DIR}"

ctest_args=(--output-on-failure -j "\${MONAN_JEDI_CTEST_JOBS}")
if [[ -n "\${MONAN_JEDI_CTEST_EXCLUDE_REGEX}" ]]; then
  ctest_args+=(-E "\${MONAN_JEDI_CTEST_EXCLUDE_REGEX}")
fi

{
  echo "=== Complete JEDI CTest PBS job ==="
  echo "GeneratedAt=\$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Host=\$(hostname)"
  echo "PBS_JOBID=\${PBS_JOBID:-}"
  echo "Umask=\$(umask)"
  echo "MONAN_JEDI_CTEST_EXCLUDE_REGEX=\${MONAN_JEDI_CTEST_EXCLUDE_REGEX}"
  module list 2>&1 || true
  echo "=== CTest inventory ==="
  ctest -N | tail -n 20
  echo "=== MPI smoke test ==="
  mpiexec -n 1 /bin/hostname
  echo "=== Complete CTest execution ==="
} | tee "${MONAN_JEDI_LOG_ROOT}/11_ctest_all_pbs_environment.log"

ctest "\${ctest_args[@]}" 2>&1 | tee "\${CTEST_LOG}"
cp -f "\${CTEST_LOG}" "\${LATEST_CTEST_LOG}"
EOF

  chmod +x "${pbs_script}"

  # Update stable latest-file references for users and post-processing scripts.
  cp -f "${pbs_script}" "${latest_pbs_script}"
  : > "${latest_pbs_err}"
  ln -sfn "$(basename "${pbs_log}")" "${latest_pbs_log}"

  log_info "Complete JEDI CTest PBS job prepared"
  log_info "  PBS script=${pbs_script}"
  log_info "  CTest log=${ctest_log}"
  log_info "  queue=${MONAN_JEDI_PBS_QUEUE}"
  log_info "  ncpus=${MONAN_JEDI_PBS_NCPUS}"
  log_info "  walltime=${MONAN_JEDI_PBS_WALLTIME}"
  log_info "  jobs=${MONAN_JEDI_CTEST_JOBS}"
  log_info "  exclude=${MONAN_JEDI_CTEST_EXCLUDE_REGEX}"

  # Submit automatically by default, but allow review-only mode through the YAML
  # configuration or environment.
  if [[ "${MONAN_JEDI_SUBMIT_JOB}" == "1" ]]; then
    qsub "${pbs_script}" | tee "${MONAN_JEDI_LOG_ROOT}/11_ctest_all_pbs_jobid.txt"
  else
    log_info "Not submitting automatically. Review and submit with: qsub ${pbs_script}"
  fi
}
