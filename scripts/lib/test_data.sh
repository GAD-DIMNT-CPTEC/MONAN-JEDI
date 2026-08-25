#!/usr/bin/env bash
# Git LFS test-data preparation and validation for the JEDI bundle.
#
# The ecbuild bundle materializes ioda-data, ufo-data and mpas-jedi-data in the
# MONAN-JEDI source tree. Their scientific test files are stored with Git LFS.
# A normal Git clone succeeds without the Git LFS client, leaving small pointer
# files that CMake accepts but NetCDF/HDF5 tests cannot read.

monan_jedi_git_lfs_root() {
  local default_project_root="/p/projetos/monan_das/${USER:-unknown}"
  printf '%s\n' "${MONAN_JEDI_GIT_LFS_ROOT:-${PROJECT_ROOT:-${default_project_root}}/envs/git-lfs}"
}

monan_jedi_report_git_lfs_found() {
  local git_lfs_root="$1"
  local executable=""
  local version=""

  [[ "${MONAN_JEDI_GIT_LFS_REPORTED:-0}" == "1" ]] && return 0

  executable="$(command -v git-lfs 2>/dev/null || true)"
  version="$(git lfs version 2>/dev/null || true)"

  log_info "Git LFS is available"
  [[ -n "${version}" ]] && log_info "  version=${version}"
  [[ -n "${executable}" ]] && log_info "  executable=${executable}"
  log_info "  persistent_project_env=${git_lfs_root}"
  export MONAN_JEDI_GIT_LFS_REPORTED=1
}

monan_jedi_git_lfs_available() {
  local git_lfs_root=""
  local project_git_lfs_bin=""

  command -v git >/dev/null 2>&1 || return 1

  git_lfs_root="$(monan_jedi_git_lfs_root)"
  project_git_lfs_bin="${git_lfs_root}/bin"

  if git lfs version >/dev/null 2>&1; then
    monan_jedi_report_git_lfs_found "${git_lfs_root}"
    return 0
  fi

  # JACI's base Conda environment is shared and read-only. Reuse the persistent
  # project-local Git LFS environment instead of relying on Conda activation or
  # shell state from a previous login session.
  if [[ -x "${project_git_lfs_bin}/git-lfs" ]]; then
    export PATH="${project_git_lfs_bin}:${PATH}"
    if git lfs version >/dev/null 2>&1; then
      monan_jedi_report_git_lfs_found "${git_lfs_root}"
      return 0
    fi
  fi

  return 1
}

monan_jedi_print_git_lfs_recovery() {
  local git_lfs_env=""
  git_lfs_env="$(monan_jedi_git_lfs_root)"

  log_error "Git LFS is not available to MONAN-JEDI."
  log_error "Persistent JACI location: ${git_lfs_env}"
  log_error "If ${git_lfs_env}/bin/git-lfs already exists, do not reinstall it; MONAN-JEDI normally discovers it automatically."
  log_error "For a first-time installation on a JACI login node, run:"
  log_error "  module load anaconda"
  log_error "  start_conda"
  log_error "  conda create -y -p \"${git_lfs_env}\" -c conda-forge git-lfs"
  log_error "  export PATH=\"${git_lfs_env}/bin:\${PATH}\""
  log_error "  git lfs install"
  log_error "  git lfs version"
  log_error "The (base) Conda environment is shared and is not the persistent installation target."
  log_error "For an existing MONAN-JEDI source tree, then run:"
  log_error "  for repo in ioda-data ufo-data mpas-jedi-data; do git -C \"\${repo}\" lfs pull && git -C \"\${repo}\" lfs checkout; done"
}

monan_jedi_file_is_lfs_pointer() {
  local path="$1"
  local first_line=""

  [[ -f "${path}" ]] || return 1
  IFS= read -r first_line < "${path}" || true
  [[ "${first_line}" == "version https://git-lfs.github.com/spec/v1" ]]
}

monan_jedi_validate_lfs_repository() {
  local repository_dir="$1"
  local repository_name="$2"
  local tracked_files=""
  local relative_path=""
  local file_count=0
  local invalid_count=0

  if [[ ! -d "${repository_dir}" ]]; then
    log_error "Required test-data repository is missing: ${repository_dir}"
    log_error "Run the MONAN-JEDI configure step to materialize ${repository_name}."
    return 1
  fi

  if ! git -C "${repository_dir}" rev-parse --git-dir >/dev/null 2>&1; then
    log_error "Test-data path is not a Git repository: ${repository_dir}"
    return 1
  fi

  if ! tracked_files="$(git -C "${repository_dir}" lfs ls-files -n 2>/dev/null)"; then
    log_error "Could not inspect Git LFS files in ${repository_dir}"
    monan_jedi_print_git_lfs_recovery
    return 1
  fi

  if [[ -z "${tracked_files}" ]]; then
    log_error "No Git LFS files were reported in ${repository_dir}"
    log_error "The pinned ${repository_name} checkout is incomplete or inconsistent."
    return 1
  fi

  while IFS= read -r relative_path; do
    [[ -n "${relative_path}" ]] || continue
    file_count=$((file_count + 1))

    if [[ ! -s "${repository_dir}/${relative_path}" ]]; then
      log_error "Git LFS test-data file is missing or empty: ${repository_dir}/${relative_path}"
      invalid_count=$((invalid_count + 1))
    elif monan_jedi_file_is_lfs_pointer "${repository_dir}/${relative_path}"; then
      log_error "Git LFS pointer was not materialized: ${repository_dir}/${relative_path}"
      invalid_count=$((invalid_count + 1))
    fi
  done <<< "${tracked_files}"

  if [[ "${invalid_count}" -ne 0 ]]; then
    log_error "${repository_name} has ${invalid_count} unavailable test-data file(s) out of ${file_count} Git LFS paths."
    monan_jedi_print_git_lfs_recovery
    return 1
  fi

  log_info "Validated ${repository_name} Git LFS data: ${file_count} files"
}

monan_jedi_sync_lfs_repository() {
  local repository_dir="$1"
  local repository_name="$2"

  log_info "Materializing ${repository_name} Git LFS test data"
  log_info "  repository=${repository_dir}"

  if ! git -C "${repository_dir}" lfs pull; then
    log_error "Git LFS download failed for ${repository_name}: ${repository_dir}"
    monan_jedi_print_git_lfs_recovery
    return 1
  fi

  if ! git -C "${repository_dir}" lfs checkout; then
    log_error "Git LFS checkout failed for ${repository_name}: ${repository_dir}"
    return 1
  fi

  monan_jedi_validate_lfs_repository "${repository_dir}" "${repository_name}"
}

monan_jedi_validate_bundle_test_data() {
  local repository_name=""

  if ! monan_jedi_git_lfs_available; then
    log_error "Git LFS is required for the JEDI test-data repositories, but 'git lfs' is unavailable."
    monan_jedi_print_git_lfs_recovery
    return 1
  fi

  for repository_name in ioda-data ufo-data mpas-jedi-data; do
    monan_jedi_validate_lfs_repository \
      "${MONAN_JEDI_SOURCE_DIR}/${repository_name}" \
      "${repository_name}" || return 1
  done

  # Validate representative files through the exact build-tree paths used by
  # CTest. This catches broken or stale Data links even when source data is valid.
  local sentinel=""
  for sentinel in \
    "${MONAN_JEDI_BUILD_DIR}/ioda/Data/testinput_tier_1/sondes_obs_2018041500_m.nc4" \
    "${MONAN_JEDI_BUILD_DIR}/ufo/Data/testinput_tier_1" \
    "${MONAN_JEDI_BUILD_DIR}/mpas-jedi/Data/testinput_tier_1"
  do
    if [[ ! -e "${sentinel}" ]]; then
      log_error "CTest test-data path is missing from the build tree: ${sentinel}"
      log_error "Rerun configure after materializing all Git LFS repositories."
      return 1
    fi
  done

  if monan_jedi_file_is_lfs_pointer \
    "${MONAN_JEDI_BUILD_DIR}/ioda/Data/testinput_tier_1/sondes_obs_2018041500_m.nc4"; then
    log_error "CTest resolves an unmaterialized Git LFS pointer through the build tree."
    monan_jedi_print_git_lfs_recovery
    return 1
  fi

  log_info "Validated bundle test-data paths used by CTest"
}

monan_jedi_prepare_bundle_test_data() {
  local repository_name=""

  if ! monan_jedi_git_lfs_available; then
    log_error "Git LFS is required before configuring the JEDI bundle."
    monan_jedi_print_git_lfs_recovery
    return 1
  fi

  for repository_name in ioda-data ufo-data mpas-jedi-data; do
    monan_jedi_sync_lfs_repository \
      "${MONAN_JEDI_SOURCE_DIR}/${repository_name}" \
      "${repository_name}" || return 1
  done
}
