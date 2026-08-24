#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${repo_root}/scripts/lib/pbs_result.sh"

log_info() {
  printf '[INFO] %s\n' "$*"
}

test_dir="$(mktemp -d)"
trap 'rm -rf "${test_dir}"' EXIT
export MONAN_JEDI_LOG_ROOT="${test_dir}"

stamp="20260821T195040Z"
job_id="380928.pbs-ha"
ctest_log="${test_dir}/jedi_all_tests_${stamp}.ctest.log"
result_file="${test_dir}/jedi_all_tests_${stamp}.result"

cat > "${MONAN_JEDI_LOG_ROOT}/11_ctest_all_pbs_submission.txt" <<EOF_SUBMISSION
TEST_STAMP=${stamp}
JOB_ID=${job_id}
RESULT_FILE=${result_file}
CTEST_LOG=${ctest_log}
PBS_LOG=${test_dir}/jedi_all_tests_${stamp}.pbs.log
EOF_SUBMISSION

cat > "${ctest_log}" <<'EOF_CTEST'
Test project /tmp/build
 696/2294 Test #696: interrupted_test ... ***Failed
EOF_CTEST

cat > "${result_file}" <<EOF_RESULT
TEST_STAMP=${stamp}
JOB_ID=${job_id}
RESULT=INCOMPLETE
CTEST_EXIT_CODE=0
TOTAL_TESTS=
PASSED_TESTS=
FAILED_TESTS=
ERROR_PHASE=ctest-execution
CTEST_LOG=${ctest_log}
PBS_LOG=${test_dir}/jedi_all_tests_${stamp}.pbs.log
EOF_RESULT

qstat() {
  cat <<EOF_QSTAT
    resources_used.walltime = 00:30:30
    job_state = F
    comment = Job run on cn-0093 and exceeded walltime
    Exit_status = -29
EOF_QSTAT
}

set +e
timeout_output="$(monan_jedi_test_pbs_result 2>&1)"
timeout_rc=$?
set -e

if [[ "${timeout_rc}" -ne 1 ]]; then
  printf 'ERROR: expected timeout rc=1, got %s\n%s\n'     "${timeout_rc}" "${timeout_output}" >&2
  exit 1
fi

grep -Fq '[TIMEOUT]' <<< "${timeout_output}"
grep -Fq 'PBS Exit_status=-29' <<< "${timeout_output}"
grep -Fq 'PBS walltime used=00:30:30' <<< "${timeout_output}"
grep -Fq 'error phase=ctest-execution' <<< "${timeout_output}"
grep -Fq 'exceeded walltime' <<< "${timeout_output}"

cat > "${ctest_log}" <<'EOF_CTEST_PASS'
Test project /tmp/build
100% tests passed, 0 tests failed out of 12
EOF_CTEST_PASS

cat > "${result_file}" <<EOF_RESULT_PASS
TEST_STAMP=${stamp}
JOB_ID=${job_id}
RESULT=PASS
CTEST_EXIT_CODE=0
JOB_EXIT_CODE=0
TOTAL_TESTS=12
PASSED_TESTS=12
FAILED_TESTS=0
ERROR_PHASE=
CTEST_LOG=${ctest_log}
PBS_LOG=${test_dir}/jedi_all_tests_${stamp}.pbs.log
EOF_RESULT_PASS

set +e
pass_output="$(monan_jedi_test_pbs_result 2>&1)"
pass_rc=$?
set -e

if [[ "${pass_rc}" -ne 0 ]]; then
  printf 'ERROR: expected pass rc=0, got %s\n%s\n'     "${pass_rc}" "${pass_output}" >&2
  exit 1
fi

grep -Fq '[PASS]' <<< "${pass_output}"
grep -Fq 'total=12' <<< "${pass_output}"

echo "PBS result timeout diagnostics checks passed."
