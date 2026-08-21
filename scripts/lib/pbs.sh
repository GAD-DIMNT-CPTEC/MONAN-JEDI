#!/usr/bin/env bash
# PBS test submission for the MONAN-JEDI reduced MPAS-JEDI workflow.
#
# Purpose:
#   Submit the complete configured JEDI/MPAS-JEDI CTest suite to a JACI PBS
#   compute node. This is required for the full test suite because many tests
#   use MPI and must not be executed directly on login nodes.
#
# Requires:
#   A configured and built MONAN-JEDI build tree under MONAN_JEDI_BUILD_DIR.
#   qsub available in PATH.
#
# Produces:
#   ${MONAN_JEDI_LOG_ROOT}/11_jedi_all_tests.pbs
#   ${MONAN_JEDI_LOG_ROOT}/11_ctest_all_pbs.out
#   ${MONAN_JEDI_LOG_ROOT}/11_ctest_all_pbs.log
#   ${MONAN_JEDI_LOG_ROOT}/11_ctest_all_pbs.result
#   ${MONAN_JEDI_LOG_ROOT}/11_ctest_all_pbs_submission.txt
#   ${MONAN_JEDI_LOG_ROOT}/11_ctest_all_pbs_jobid.txt, when submitted
#
# Expected result:
#   The PBS job runs ctest without a broad -R selection. If
#   MONAN_JEDI_CTEST_EXCLUDE_REGEX is set, the listed known-failing tests are
#   excluded with ctest -E. At completion, the job writes a machine-readable
#   result file that can be evaluated with the test-pbs-result command.

monan_jedi_pbs_placement_directive() {
  local queue="$1"
  local queue_name="${queue%%@*}"

  # JACI policy: jobs on compute-node queues must have exclusive node
  # placement. The aux queue is the only documented sharing exception.
  if [[ "${queue_name}" == "aux" ]]; then
    return 0
  fi

  printf '%s\n' '#PBS -l place=excl'
}

monan_jedi_validate_pbs_placement_policy() {
  local pbs_script="$1"
  local queue="$2"
  local queue_name="${queue%%@*}"
  local directive='#PBS -l place=excl'

  if [[ "${queue_name}" == "aux" ]]; then
    if grep -Fxq -- "${directive}" "${pbs_script}"; then
      log_error "PBS aux job must not request exclusive placement: ${pbs_script}"
      exit 1
    fi
    return 0
  fi

  if ! grep -Fxq -- "${directive}" "${pbs_script}"; then
    log_error "PBS compute-node job is missing required exclusive placement: ${pbs_script}"
    exit 1
  fi
}

monan_jedi_test_pbs() {
  require_cmd qsub

  if [[ ! -d "${MONAN_JEDI_BUILD_DIR}" ]]; then
    log_error "MONAN_JEDI_BUILD_DIR not found: ${MONAN_JEDI_BUILD_DIR}"
    exit 1
  fi

  if [[ ! -f "${MONAN_JEDI_BUILD_DIR}/CTestTestfile.cmake" ]]; then
    log_error "Build tree does not contain CTestTestfile.cmake: ${MONAN_JEDI_BUILD_DIR}"
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
  local pbs_script pbs_log ctest_log result_file
  local latest_pbs_script latest_pbs_log latest_pbs_err latest_ctest_log
  local latest_result_file submission_file jobid_file
  local pbs_placement_directive

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
  pbs_placement_directive="$(monan_jedi_pbs_placement_directive "${MONAN_JEDI_PBS_QUEUE}")"

  mkdir -p "${MONAN_JEDI_LOG_ROOT}"

  # Timestamped files keep previous runs available. The 11_* files provide
  # stable names for the most recent PBS and CTest execution.
  pbs_script="${MONAN_JEDI_LOG_ROOT}/jedi_all_tests_${test_stamp}.pbs"
  pbs_log="${MONAN_JEDI_LOG_ROOT}/jedi_all_tests_${test_stamp}.pbs.log"
  ctest_log="${MONAN_JEDI_LOG_ROOT}/jedi_all_tests_${test_stamp}.ctest.log"
  result_file="${MONAN_JEDI_LOG_ROOT}/jedi_all_tests_${test_stamp}.result"
  latest_pbs_script="${MONAN_JEDI_LOG_ROOT}/11_jedi_all_tests.pbs"
  latest_pbs_log="${MONAN_JEDI_LOG_ROOT}/11_ctest_all_pbs.out"
  latest_pbs_err="${MONAN_JEDI_LOG_ROOT}/11_ctest_all_pbs.err"
  latest_ctest_log="${MONAN_JEDI_LOG_ROOT}/11_ctest_all_pbs.log"
  latest_result_file="${MONAN_JEDI_LOG_ROOT}/11_ctest_all_pbs.result"
  submission_file="${MONAN_JEDI_LOG_ROOT}/11_ctest_all_pbs_submission.txt"
  jobid_file="${MONAN_JEDI_LOG_ROOT}/11_ctest_all_pbs_jobid.txt"

  # Generate the PBS job script with the current configuration exported
  # explicitly. This makes the job reproducible from the submitted script alone.
  cat > "${pbs_script}" <<EOF_PBS
#!/bin/bash
#PBS -N jedi_all_ctest
#PBS -q ${MONAN_JEDI_PBS_QUEUE}
#PBS -l select=1:ncpus=${MONAN_JEDI_PBS_NCPUS}
${pbs_placement_directive}
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
export MONAN_JEDI_SOURCE_DIR=${MONAN_JEDI_SOURCE_DIR}
export MONAN_JEDI_BUILD_DIR=${MONAN_JEDI_BUILD_DIR}
export MONAN_JEDI_INSTALL_ROOT=${MONAN_JEDI_INSTALL_ROOT}
export MONAN_JEDI_INSTALL_BIN_DIR=${MONAN_JEDI_INSTALL_BIN_DIR}
export MONAN_JEDI_CTEST_EXCLUDE_REGEX='${MONAN_JEDI_CTEST_EXCLUDE_REGEX}'
export MONAN_JEDI_CTEST_JOBS=${MONAN_JEDI_CTEST_JOBS}
export TEST_STAMP='${test_stamp}'
export CTEST_LOG='${ctest_log}'
export LATEST_CTEST_LOG='${latest_ctest_log}'
export RESULT_FILE='${result_file}'
export LATEST_RESULT_FILE='${latest_result_file}'
export PBS_LOG='${pbs_log}'

# Always publish a machine-readable result, including failures that happen
# during configuration or stack bootstrap before CTest starts.
job_phase="bootstrap"
finalize_pbs_result() {
  local job_rc="\$?"
  local result_tmp

  trap - EXIT
  if [[ ! -s "\${RESULT_FILE}" ]]; then
    result_tmp="\${RESULT_FILE}.tmp.\$\$"
    cat > "\${result_tmp}" <<EOF_EARLY_RESULT
TEST_STAMP=\${TEST_STAMP}
JOB_ID=\${PBS_JOBID:-}
RESULT=INCOMPLETE
CTEST_EXIT_CODE=\${job_rc}
TOTAL_TESTS=
PASSED_TESTS=
FAILED_TESTS=
ERROR_PHASE=\${job_phase}
CTEST_LOG=\${CTEST_LOG}
PBS_LOG=\${PBS_LOG}
EOF_EARLY_RESULT
    mv -f "\${result_tmp}" "\${RESULT_FILE}"
    cp -f "\${RESULT_FILE}" "\${LATEST_RESULT_FILE}"
  fi

  exit "\${job_rc}"
}
trap finalize_pbs_result EXIT

source ${script_dir}/lib/common.sh
source ${script_dir}/lib/config.sh
source ${script_dir}/lib/stack.sh
load_monan_jedi_config
job_phase="stack-load"
monan_jedi_load_stack

job_phase="ctest-environment"
cd "\${MONAN_JEDI_BUILD_DIR}"

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

job_phase="ctest-execution"
# CTest returns non-zero when tests fail. Capture that status instead of letting
# set -e/pipefail terminate the PBS script before the log/result files are
# finalized.
set +e
ctest "\${ctest_args[@]}" 2>&1 | tee "\${CTEST_LOG}"
pipeline_status=("\${PIPESTATUS[@]}")
set -e
ctest_rc="\${pipeline_status[0]}"
tee_rc="\${pipeline_status[1]}"

cp -f "\${CTEST_LOG}" "\${LATEST_CTEST_LOG}"

summary_line="\$(grep -E '[0-9]+% tests passed, [0-9]+ tests failed out of [0-9]+' "\${CTEST_LOG}" | tail -n 1 || true)"
total_tests=""
passed_tests=""
failed_tests=""
result="INCOMPLETE"
result_exit=2

if [[ "\${summary_line}" =~ ([0-9]+)%[[:space:]]+tests[[:space:]]+passed,[[:space:]]+([0-9]+)[[:space:]]+tests[[:space:]]+failed[[:space:]]+out[[:space:]]+of[[:space:]]+([0-9]+) ]]; then
  failed_tests="\${BASH_REMATCH[2]}"
  total_tests="\${BASH_REMATCH[3]}"
  passed_tests=\$((total_tests - failed_tests))

  if [[ "\${ctest_rc}" -eq 0 && "\${tee_rc}" -eq 0 && "\${failed_tests}" -eq 0 ]]; then
    result="PASS"
    result_exit=0
  else
    result="FAIL"
    result_exit="\${ctest_rc}"
    [[ "\${result_exit}" -eq 0 ]] && result_exit=1
  fi
fi

result_tmp="\${RESULT_FILE}.tmp.\$\$"
cat > "\${result_tmp}" <<EOF_RESULT
TEST_STAMP=\${TEST_STAMP}
JOB_ID=\${PBS_JOBID:-}
RESULT=\${result}
CTEST_EXIT_CODE=\${ctest_rc}
TOTAL_TESTS=\${total_tests}
PASSED_TESTS=\${passed_tests}
FAILED_TESTS=\${failed_tests}
ERROR_PHASE=
CTEST_LOG=\${CTEST_LOG}
PBS_LOG=\${PBS_LOG}
EOF_RESULT
mv -f "\${result_tmp}" "\${RESULT_FILE}"
cp -f "\${RESULT_FILE}" "\${LATEST_RESULT_FILE}"

exit "\${result_exit}"
EOF_PBS

  monan_jedi_validate_pbs_placement_policy "${pbs_script}" "${MONAN_JEDI_PBS_QUEUE}"
  chmod +x "${pbs_script}"

  # Update stable latest-file references for users and post-processing scripts.
  cp -f "${pbs_script}" "${latest_pbs_script}"
  : > "${latest_pbs_err}"
  ln -sfn "$(basename "${pbs_log}")" "${latest_pbs_log}"

  log_info "Complete JEDI CTest PBS job prepared"
  log_info "  PBS script=${pbs_script}"
  log_info "  CTest log=${ctest_log}"
  log_info "  Result file=${result_file}"
  log_info "  queue=${MONAN_JEDI_PBS_QUEUE}"
  if [[ -n "${pbs_placement_directive}" ]]; then
    log_info "  placement=exclusive"
  else
    log_info "  placement=shared (aux queue exception)"
  fi
  log_info "  ncpus=${MONAN_JEDI_PBS_NCPUS}"
  log_info "  walltime=${MONAN_JEDI_PBS_WALLTIME}"
  log_info "  jobs=${MONAN_JEDI_CTEST_JOBS}"
  log_info "  exclude=${MONAN_JEDI_CTEST_EXCLUDE_REGEX}"

  # Submit automatically by default, but allow review-only mode through the YAML
  # configuration or environment.
  if [[ "${MONAN_JEDI_SUBMIT_JOB}" == "1" ]]; then
    local job_id
    job_id="$(qsub "${pbs_script}")"
    printf '%s\n' "${job_id}" | tee "${jobid_file}"

    cat > "${submission_file}" <<EOF_SUBMISSION
TEST_STAMP=${test_stamp}
JOB_ID=${job_id}
RESULT_FILE=${result_file}
CTEST_LOG=${ctest_log}
PBS_LOG=${pbs_log}
EOF_SUBMISSION

    log_info "After the PBS job completes, validate the result with:"
    log_info "  bash scripts/monan-jedi.sh test-pbs-result --config ${MONAN_JEDI_CONFIG}"
  else
    log_info "Not submitting automatically. Review and submit with: qsub ${pbs_script}"
  fi
}
