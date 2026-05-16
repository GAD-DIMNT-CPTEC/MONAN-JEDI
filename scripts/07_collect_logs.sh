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
  echo "## Last ctest lines"
  tail -n 120 "${MONAN_JEDI_LOG_ROOT}/06_ctest.log" 2>/dev/null || true
  echo
  echo "## Error scan"
  grep -RniE "error|failed|cannot|undefined reference|CMake Error|No such file|permission denied|fatal|killed" \
    "${MONAN_JEDI_LOG_ROOT}" | head -n 200 || true
} | tee "${MONAN_JEDI_LOG_ROOT}/07_summary.log"

log_info "Log collection completed: ${MONAN_JEDI_LOG_ROOT}/07_summary.log"
