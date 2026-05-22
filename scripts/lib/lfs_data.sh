#!/usr/bin/env bash
# Large file data helpers for MONAN-JEDI test data.

monan_jedi_ensure_lfs_test_data() {
  require_cmd git

  if ! git -C "${MONAN_JEDI_SOURCE_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log_warn "MONAN-JEDI source directory is not a Git working tree; skipping large test data update"
    return 0
  fi

  if ! git -C "${MONAN_JEDI_SOURCE_DIR}" lfs version >/dev/null 2>&1; then
    log_error "git-lfs is required to materialize MONAN-JEDI test data, but it is not available"
    log_error "Load or install git-lfs, then rerun the configure step"
    exit 1
  fi

  log_info "Ensuring large test data tracked by Git LFS are available"
  git -C "${MONAN_JEDI_SOURCE_DIR}" lfs install --local
  git -C "${MONAN_JEDI_SOURCE_DIR}" lfs pull
  git -C "${MONAN_JEDI_SOURCE_DIR}" submodule foreach --recursive 'git lfs pull || true'

  monan_jedi_check_ioda_tier1_data
}

monan_jedi_check_ioda_tier1_data() {
  local ioda_data_dir="${MONAN_JEDI_SOURCE_DIR}/ioda-data/testinput_tier_1"
  local suspect_file
  local pointer_found=0

  if [[ ! -d "${ioda_data_dir}" ]]; then
    log_error "IODA tier-1 test data directory not found: ${ioda_data_dir}"
    log_error "The MONAN-JEDI tests expect data under ioda-data/testinput_tier_1"
    exit 1
  fi

  while IFS= read -r suspect_file; do
    if [[ -f "${suspect_file}" ]] && grep -q '^version https://git-lfs.github.com/spec/v1' "${suspect_file}"; then
      log_error "Git LFS pointer found instead of real test data: ${suspect_file}"
      pointer_found=1
    fi
  done < <(find "${ioda_data_dir}" -type f -name '*.nc4' | sort)

  if [[ "${pointer_found}" -ne 0 ]]; then
    log_error "Some IODA .nc4 files are still Git LFS pointer files"
    log_error "Run from the MONAN-JEDI repository root: git lfs pull"
    exit 1
  fi
}
