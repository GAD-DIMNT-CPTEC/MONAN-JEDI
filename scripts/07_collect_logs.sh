#!/usr/bin/env bash
# =============================================================================
# 07_collect_logs.sh
# =============================================================================
# Collect and summarize MONAN-JEDI build logs.
# =============================================================================

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00_common.sh
source "${script_dir}/00_common.sh"

log_info "MONAN_JEDI_LOG_ROOT=${MONAN_JEDI_LOG_ROOT}"

if [[ ! -d "${MONAN_JEDI_LOG_ROOT}" ]]; then
  log_error "Log directory not found: ${MONAN_JEDI_LOG_ROOT}"
  exit 1
fi

scan_file_for_errors() {
  local file="$1"

  # Avoid scanning generated summaries recursively and avoid known files where
  # words like FATAL_ERROR appear only inside an intentional CMake diff.
  case "$(basename "${file}")" in
    07_summary.log|03_mpas_only_cmake_patch.log)
      return 0
      ;;
  esac

  grep -nEi \
    '(^|[[:space:]])(error:|fatal:|segmentation fault|undefined reference|CMake Error|No such file or directory|permission denied|killed|abort|[1-9][0-9]* tests failed)' \
    "${file}" 2>/dev/null \
    | grep -viE 'Performing Test .* - Failed' \
    | grep -viE '100% tests passed, 0 tests failed' \
    || true
}

print_ctest_result_summary() {
  local file="$1"

  if [[ ! -f "${file}" ]]; then
    return 0
  fi

  grep -nE 'tests passed|tests failed|The following tests FAILED|Total Test time|Label Time Summary' "${file}" || true
}

{
  echo "# MONAN-JEDI log summary"
  echo "GeneratedAt=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  echo "## Files"
  find "${MONAN_JEDI_LOG_ROOT}" -type f | sort
  echo
  echo "## Last configure lines"
  tail -n 80 "${MONAN_JEDI_LOG_ROOT}/04_ecbuild.log" 2>/dev/null || true
  echo
  echo "## Last build lines"
  tail -n 120 "${MONAN_JEDI_LOG_ROOT}/05_make.log" 2>/dev/null || true
  echo
  echo "## Login-node CTest final result"
  print_ctest_result_summary "${MONAN_JEDI_LOG_ROOT}/06_ctest.log"
  echo
  echo "## Login-node CTest tail"
  tail -n 80 "${MONAN_JEDI_LOG_ROOT}/06_ctest.log" 2>/dev/null || true
  echo
  echo "## PBS CTest final result"
  print_ctest_result_summary "${MONAN_JEDI_LOG_ROOT}/06_ctest_pbs.log"
  echo
  echo "## PBS CTest tail"
  tail -n 160 "${MONAN_JEDI_LOG_ROOT}/06_ctest_pbs.log" 2>/dev/null || true
  echo
  echo "## Focused error scan"
  while IFS= read -r file; do
    scan_file_for_errors "${file}" | sed "s#^#${file}:#"
  done < <(find "${MONAN_JEDI_LOG_ROOT}" -type f | sort) | head -n 200
} | tee "${MONAN_JEDI_LOG_ROOT}/07_summary.log"

log_info "Log collection completed: ${MONAN_JEDI_LOG_ROOT}/07_summary.log"
