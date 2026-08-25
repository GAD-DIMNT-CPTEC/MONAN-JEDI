#!/usr/bin/env bash
# Git LFS test-data preparation and validation for the JEDI bundle.
#
# The ecbuild bundle materializes ioda-data, ufo-data and mpas-jedi-data in the
# MONAN-JEDI source tree. Their scientific test files are stored with Git LFS.
# A normal Git clone succeeds without the Git LFS client, leaving small pointer
# files that CMake accepts but NetCDF/HDF5 tests cannot read.

monan_jedi_git_lfs_available() {
  local project_git_lfs_bin="${PROJECT_ROOT:-}/envs/git-lfs/bin"

  command -v git >/dev/null 2>&1 || return 1

  if git lfs version >/dev/null 2>&1; then
    return 0
  fi

  # JACI's base Conda environment is shared and read-only. Automatically reuse
  # the documented project-local environment without requiring users to edit
  # PATH in every new login session.
  if [[ -x "${project_git_lfs_bin}/git-lfs" ]]; then
    export PATH="${project_git_lfs_bin}:${PATH}"
    git lfs version >/dev/null 2>&1
    return $?
  fi

  return 1
}

monan_jedi_print_git_lfs_recovery() {
  local git_lfs_env="${PROJECT_ROOT:-/p/projetos/monan_das/\${USER}}/envs/git-lfs"

  log_error "Install Git LFS on the login node, then materialize the bundle data."
  log_error "JACI's shared base environment (/p/app/anaconda) is not writable."
  log_error "Create a project-local environment instead:"
  log_error "  conda create -y -p \"${git_lfs_env}\" -c conda-forge git-lfs"
  log_error "The workflow discovers ${git_lfs_env}/bin/git-lfs automatically."
  log_error "Then run: ${git_lfs_env}/bin/git-lfs install"
  log_error "For an existing source tree, run:"
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
    monan_jedi_validate_lfs_repository       "${MONAN_JEDI_SOURCE_DIR}/${repository_name}"       "${repository_name}" || return 1
  done

  # Validate representative files through the exact build-tree paths used by
  # CTest. This catches broken or stale Data links even when source data is valid.
  local sentinel=""
  for sentinel in     "${MONAN_JEDI_BUILD_DIR}/ioda/Data/testinput_tier_1/sondes_obs_2018041500_m.nc4"     "${MONAN_JEDI_BUILD_DIR}/ufo/Data/testinput_tier_1"     "${MONAN_JEDI_BUILD_DIR}/mpas-jedi/Data/testinput_tier_1"
  do
    if [[ ! -e "${sentinel}" ]]; then
      log_error "CTest test-data path is missing from the build tree: ${sentinel}"
      log_error "Rerun configure after materializing all Git LFS repositories."
      return 1
    fi
  done

  if monan_jedi_file_is_lfs_pointer     "${MONAN_JEDI_BUILD_DIR}/ioda/Data/testinput_tier_1/sondes_obs_2018041500_m.nc4"; then
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
    monan_jedi_sync_lfs_repository       "${MONAN_JEDI_SOURCE_DIR}/${repository_name}"       "${repository_name}" || return 1
  done
}
