#!/usr/bin/env bash
# Log collection helpers for MONAN-JEDI.
#
# Purpose:
#   Generate a compact summary of the logs produced during the MONAN-JEDI
#   workflow execution.
#
# Produces:
#   ${MONAN_JEDI_LOG_ROOT}/09_summary.log
#
# Expected result:
#   The summary file contains the list of generated logs and the tail sections
#   of configure, build, install and CTest logs for quick inspection.

monan_jedi_collect_logs() {
  if [[ ! -d "${MONAN_JEDI_LOG_ROOT}" ]]; then
    log_error "Log directory not found: ${MONAN_JEDI_LOG_ROOT}"
    exit 1
  fi

  local summary_file="${MONAN_JEDI_LOG_ROOT}/09_summary.log"

  {
    echo "# MONAN-JEDI log summary"
    echo "GeneratedAt=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo

    # List all generated logs so the summary works as a compact index.
    echo "## Files"
    find "${MONAN_JEDI_LOG_ROOT}" -type f | sort
    echo

    # Tail sections keep the summary readable while still exposing the most
    # relevant failures usually printed near the end of each log.
    echo "## Configure tail"
    tail -n 80 "${MONAN_JEDI_LOG_ROOT}/04_ecbuild.log" 2>/dev/null || true
    echo

    echo "## Build tail"
    tail -n 120 "${MONAN_JEDI_LOG_ROOT}/05_make.log" 2>/dev/null || true
    echo

    echo "## Install tail"
    tail -n 120 "${MONAN_JEDI_LOG_ROOT}/06_make_install.log" 2>/dev/null || true
    echo

    echo "## CTest tail"
    tail -n 120 "${MONAN_JEDI_LOG_ROOT}/07_ctest.log" 2>/dev/null || true
    echo

    echo "## obs2ioda tail"
    tail -n 120 "${MONAN_JEDI_LOG_ROOT}/08_obs2ioda_build.log" 2>/dev/null || true
  } | tee "${summary_file}"

  log_info "Log summary written to ${summary_file}"
}
