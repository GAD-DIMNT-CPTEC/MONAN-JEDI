#!/usr/bin/env bash
# PBS CTest result validation for the MONAN-JEDI workflow.
#
# Purpose:
#   Evaluate the most recent complete CTest execution submitted through
#   test-pbs and report an unambiguous PASS, FAIL or INCOMPLETE status.
#
# The preferred input is the machine-readable .result file written by newer
# PBS jobs. For compatibility with jobs submitted before this result file was
# introduced, the validator can also inspect the most recent timestamped
# jedi_all_tests_*.ctest.log file when there is no current submission metadata.
#
# Return codes:
#   0  PASS
#   1  FAIL
#   2  INCOMPLETE or no result available

_monan_jedi_parse_ctest_summary() {
  local ctest_log="$1"
  local summary_line

  [[ -f "${ctest_log}" ]] || return 1

  summary_line="$(grep -E '[0-9]+% tests passed, [0-9]+ tests failed out of [0-9]+' "${ctest_log}" | tail -n 1 || true)"
  [[ -n "${summary_line}" ]] || return 1

  if [[ "${summary_line}" =~ ([0-9]+)%[[:space:]]+tests[[:space:]]+passed,[[:space:]]+([0-9]+)[[:space:]]+tests[[:space:]]+failed[[:space:]]+out[[:space:]]+of[[:space:]]+([0-9]+) ]]; then
    MONAN_JEDI_RESULT_PERCENT="${BASH_REMATCH[1]}"
    MONAN_JEDI_RESULT_FAILED="${BASH_REMATCH[2]}"
    MONAN_JEDI_RESULT_TOTAL="${BASH_REMATCH[3]}"
    MONAN_JEDI_RESULT_PASSED=$((MONAN_JEDI_RESULT_TOTAL - MONAN_JEDI_RESULT_FAILED))
    export MONAN_JEDI_RESULT_PERCENT MONAN_JEDI_RESULT_FAILED
    export MONAN_JEDI_RESULT_TOTAL MONAN_JEDI_RESULT_PASSED
    return 0
  fi

  return 1
}

_monan_jedi_print_failed_tests() {
  local ctest_log="$1"
  local failed_lines

  [[ -f "${ctest_log}" ]] || return 0

  failed_lines="$(awk '
    /The following tests FAILED:/ { capture=1; next }
    capture && /^[[:space:]]*[0-9]+ - / {
      sub(/^[[:space:]]*/, "")
      print "  " $0
    }
  ' "${ctest_log}")"

  if [[ -n "${failed_lines}" ]]; then
    printf 'Failed tests:\n%s\n' "${failed_lines}"
  fi
}

_monan_jedi_read_key_value_file() {
  local input_file="$1"
  local prefix="$2"
  local key value

  [[ -f "${input_file}" ]] || return 1

  while IFS='=' read -r key value; do
    case "${key}" in
      TEST_STAMP|JOB_ID|RESULT_FILE|CTEST_LOG|PBS_LOG|RESULT|CTEST_EXIT_CODE|TOTAL_TESTS|PASSED_TESTS|FAILED_TESTS)
        printf -v "${prefix}_${key}" '%s' "${value}"
        ;;
    esac
  done < "${input_file}"
}

monan_jedi_test_pbs_result() {
  local submission_file="${MONAN_JEDI_LOG_ROOT}/11_ctest_all_pbs_submission.txt"
  local stable_result_file="${MONAN_JEDI_LOG_ROOT}/11_ctest_all_pbs.result"
  local jobid_file="${MONAN_JEDI_LOG_ROOT}/11_ctest_all_pbs_jobid.txt"
  local result_file=""
  local ctest_log=""
  local job_id=""
  local test_stamp=""
  local result=""
  local ctest_exit_code=""
  local total_tests=""
  local passed_tests=""
  local failed_tests=""
  local legacy_mode=0

  log_info "MONAN-JEDI PBS CTest validation"

  # New submissions record the exact result/log paths. If that metadata exists,
  # never fall back to an older log: a missing final result then means the
  # current submission is still incomplete or terminated before CTest finished.
  if [[ -f "${submission_file}" ]]; then
    _monan_jedi_read_key_value_file "${submission_file}" SUBMISSION
    test_stamp="${SUBMISSION_TEST_STAMP:-}"
    job_id="${SUBMISSION_JOB_ID:-}"
    result_file="${SUBMISSION_RESULT_FILE:-}"
    ctest_log="${SUBMISSION_CTEST_LOG:-}"

    if [[ -z "${result_file}" || ! -s "${result_file}" ]]; then
      log_info "  job_id=${job_id:-unknown}"
      log_info "  test_stamp=${test_stamp:-unknown}"
      [[ -n "${ctest_log}" ]] && log_info "  CTest log=${ctest_log}"
      printf '[INCOMPLETE] PBS CTest validation has no final result yet.\n'
      return 2
    fi
  elif [[ -s "${stable_result_file}" ]]; then
    # Compatibility with an existing stable result when submission metadata is
    # unavailable for any reason.
    result_file="${stable_result_file}"
    if [[ -f "${jobid_file}" ]]; then
      job_id="$(tail -n 1 "${jobid_file}" | awk '{print $1}')"
    fi
  else
    # Legacy compatibility: jobs submitted before .result files existed can be
    # validated directly from the newest timestamped CTest log.
    ctest_log="$(find "${MONAN_JEDI_LOG_ROOT}" -maxdepth 1 -type f -name 'jedi_all_tests_*.ctest.log' -printf '%T@ %p\n' 2>/dev/null \
      | sort -nr | head -n 1 | cut -d' ' -f2- || true)"

    if [[ -z "${ctest_log}" ]]; then
      printf '[INCOMPLETE] No PBS CTest result or CTest log was found.\n'
      return 2
    fi

    legacy_mode=1
    if [[ -f "${jobid_file}" ]]; then
      job_id="$(tail -n 1 "${jobid_file}" | awk '{print $1}')"
    fi
  fi

  if [[ -n "${result_file}" ]]; then
    _monan_jedi_read_key_value_file "${result_file}" PBS_RESULT
    result="${PBS_RESULT_RESULT:-}"
    ctest_exit_code="${PBS_RESULT_CTEST_EXIT_CODE:-}"
    total_tests="${PBS_RESULT_TOTAL_TESTS:-}"
    passed_tests="${PBS_RESULT_PASSED_TESTS:-}"
    failed_tests="${PBS_RESULT_FAILED_TESTS:-}"
    ctest_log="${PBS_RESULT_CTEST_LOG:-${ctest_log}}"
    job_id="${PBS_RESULT_JOB_ID:-${job_id}}"
    test_stamp="${PBS_RESULT_TEST_STAMP:-${test_stamp}}"
  fi

  # Parse the CTest summary as the source of the test counts. This also provides
  # backward compatibility for logs created before machine-readable result files.
  if _monan_jedi_parse_ctest_summary "${ctest_log}"; then
    total_tests="${MONAN_JEDI_RESULT_TOTAL}"
    passed_tests="${MONAN_JEDI_RESULT_PASSED}"
    failed_tests="${MONAN_JEDI_RESULT_FAILED}"

    if [[ ${legacy_mode} -eq 1 || -z "${result}" ]]; then
      if [[ "${failed_tests}" -eq 0 ]]; then
        result="PASS"
      else
        result="FAIL"
      fi
    fi
  elif [[ -z "${result}" || "${result}" == "PASS" ]]; then
    # A PASS result without a recognizable final CTest summary is not complete
    # enough to validate reproducibly.
    result="INCOMPLETE"
  fi

  log_info "  job_id=${job_id:-unknown}"
  [[ -n "${test_stamp}" ]] && log_info "  test_stamp=${test_stamp}"
  log_info "  total=${total_tests:-unknown}"
  log_info "  passed=${passed_tests:-unknown}"
  log_info "  failed=${failed_tests:-unknown}"
  [[ -n "${ctest_exit_code}" ]] && log_info "  CTest exit code=${ctest_exit_code}"
  log_info "  CTest log=${ctest_log:-unknown}"

  case "${result}" in
    PASS)
      printf '[PASS] Complete PBS CTest validation passed.\n'
      return 0
      ;;
    FAIL)
      printf '[FAIL] Complete PBS CTest validation failed.\n'
      _monan_jedi_print_failed_tests "${ctest_log}"
      return 1
      ;;
    *)
      printf '[INCOMPLETE] PBS CTest execution did not produce a complete final result.\n'
      return 2
      ;;
  esac
}
