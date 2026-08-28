#!/usr/bin/env bash
# Generate a compact index and tail summary for workflow logs.

monan_jedi_collect_logs() {
  [[ -d "${MONAN_JEDI_LOG_ROOT}" ]] || {
    log_error "Log directory not found: ${MONAN_JEDI_LOG_ROOT}"
    exit 1
  }

  local summary_file="${MONAN_JEDI_LOG_ROOT}/99_summary.log"
  {
    echo "# MONAN-JEDI log summary"
    echo "GeneratedAt=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo
    echo "## Files"
    find "${MONAN_JEDI_LOG_ROOT}" -type f | sort
    echo

    local label file lines
    while IFS='|' read -r label file lines; do
      echo "## ${label}"
      tail -n "${lines}" "${MONAN_JEDI_LOG_ROOT}/${file}" 2>/dev/null || true
      echo
    done <<'EOF_TAILS'
Configure tail|04_ecbuild.log|80
Bundle build tail|05_make.log|120
Bundle install tail|06_make_install.log|120
CTest tail|07_ctest.log|120
obs2ioda build tail|08_obs2ioda_build.log|120
WPS configure tail|09_wps_cmake.log|120
WPS build tail|09_wps_build.log|120
WPS validation|09_wps_validate.log|120
Installed runtime validation|10_install_test.log|200
EOF_TAILS
  } | tee "${summary_file}"

  log_info "Log summary written to ${summary_file}"
}
