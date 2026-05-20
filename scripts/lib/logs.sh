#!/usr/bin/env bash
# Log collection helpers for MONAN-JEDI.

monan_jedi_collect_logs() {
  if [[ ! -d "${MONAN_JEDI_LOG_ROOT}" ]]; then
    log_error "Log directory not found: ${MONAN_JEDI_LOG_ROOT}"
    exit 1
  fi

  local summary_file="${MONAN_JEDI_LOG_ROOT}/07_summary.log"

  {
    echo "# MONAN-JEDI log summary"
    echo "GeneratedAt=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo
    echo "## Files"
    find "${MONAN_JEDI_LOG_ROOT}" -type f | sort
    echo
    echo "## Configure tail"
    tail -n 80 "${MONAN_JEDI_LOG_ROOT}/04_ecbuild.log" 2>/dev/null || true
    echo
    echo "## Build tail"
    tail -n 120 "${MONAN_JEDI_LOG_ROOT}/05_make.log" 2>/dev/null || true
    echo
    echo "## CTest tail"
    tail -n 120 "${MONAN_JEDI_LOG_ROOT}/06_ctest.log" 2>/dev/null || true
  } | tee "${summary_file}"

  log_info "Log summary written to ${summary_file}"
}
