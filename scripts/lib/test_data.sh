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
  local provider="$1"
  local git_lfs_root="$2"
  local executable=""
  local version=""

  [[ "${MONAN_JEDI_GIT_LFS_REPORTED:-0}" == "1" ]] && return 0

  executable="$(command -v git-lfs 2>/dev/null || true)"
  version="$(git lfs version 2>/dev/null || true)"

  log_info "Git LFS is available"
  [[ -n "${version}" ]] && log_info "  version=${version}"
  [[ -n "${executable}" ]] && log_info "  executable=${executable}"
  log_info "  provider=${provider}"
  if [[ "${provider}" == "project-local fallback" ]]; then
    log_info "  project_fallback_env=${git_lfs_root}"
  fi
  export MONAN_JEDI_GIT_LFS_REPORTED=1
}

monan_jedi_git_lfs_available() {
  local git_lfs_root=""
  local project_git_lfs_bin=""
  local executable=""

  command -v git >/dev/null 2>&1 || return 1

  git_lfs_root="$(monan_jedi_git_lfs_root)"
  project_git_lfs_bin="${git_lfs_root}/bin"

  # Preferred path: the validated MONAN-JEDI spack-stack environment already
  # provides Git LFS. This is the normal JACI baseline and requires no separate
  # Conda installation by the user.
  if git lfs version >/dev/null 2>&1; then
    executable="$(command -v git-lfs 2>/dev/null || true)"
    case "${executable}" in
      "${project_git_lfs_bin}"/*)
        monan_jedi_report_git_lfs_found "project-local fallback" "${git_lfs_root}"
        ;;
      *)
        monan_jedi_report_git_lfs_found "loaded stack/environment" "${git_lfs_root}"
        ;;
    esac
    return 0
  fi

  # Fallback for a custom/older stack that does not provide Git LFS. Reuse a
  # user-owned project-local installation without requiring Conda activation or
  # shell state from a previous login session.
  if [[ -x "${project_git_lfs_bin}/git-lfs" ]]; then
    export PATH="${project_git_lfs_bin}:${PATH}"
    if git lfs version >/dev/null 2>&1; then
      monan_jedi_report_git_lfs_found "project-local fallback" "${git_lfs_root}"
      return 0
    fi
  fi

  return 1
}

monan_jedi_print_git_lfs_recovery() {
  local git_lfs_env=""
  git_lfs_env="$(monan_jedi_git_lfs_root)"

  log_error "Git LFS is not available after loading the MONAN-JEDI stack."
  log_error "The current JACI baseline normally provides Git LFS through the validated spack-stack environment."
  log_error "Check the stack first with: bash scripts/monan-jedi.sh load --config \"${MONAN_JEDI_CONFIG:-config/jaci.yaml}\""
  log_error "If a custom/older stack does not provide Git LFS, the supported user fallback is: ${git_lfs_env}"
  log_error "If ${git_lfs_env}/bin/git-lfs already exists, do not reinstall it; MONAN-JEDI discovers it automatically."
  log_error "For a first-time fallback installation on a JACI login node, run:"
  log_error "  module load anaconda"
  log_error "  start_conda"
  log_error "  conda create -y -p \"${git_lfs_env}\" -c conda-forge git-lfs"
  log_error "  export PATH=\"${git_lfs_env}/bin:\${PATH}\""
  log_error "  git lfs install"
  log_error "  git lfs version"
  log_error "The (base) Conda environment is shared and is not the installation target."
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

monan_jedi_validate_build_data_link() {
  local build_link="$1"
  local source_target="$2"
  local label="$3"
  local resolved_build=""
  local resolved_source=""

  if [[ ! -e "${build_link}" ]]; then
    log_error "CTest test-data link is missing from the build tree: ${build_link}"
    log_error "Rerun configure to recreate the ${label} test-data links."
    return 1
  fi

  if [[ ! -L "${build_link}" ]]; then
    log_error "CTest test-data path is not the expected symbolic link: ${build_link}"
    log_error "Rerun configure to recreate the ${label} test-data links."
    return 1
  fi

  resolved_build="$(readlink -f "${build_link}" 2>/dev/null || true)"
  resolved_source="$(readlink -f "${source_target}" 2>/dev/null || true)"

  if [[ -z "${resolved_build}" || -z "${resolved_source}" || "${resolved_build}" != "${resolved_source}" ]]; then
    log_error "CTest ${label} data link does not resolve to the pinned source data."
    log_error "  build_link=${build_link}"
    log_error "  resolved_build=${resolved_build:-unresolved}"
    log_error "  expected_source=${resolved_source:-${source_target}}"
    log_error "Rerun configure to recreate the build-tree data links."
    return 1
  fi

  log_info "Validated ${label} CTest data link"
  log_info "  build=${build_link}"
  log_info "  source=${resolved_source}"
}

monan_jedi_validate_bundle_test_data() {
  local repository_name=""
  local ioda_data_link=""
  local ufo_data_link=""
  local mpas_384_data_link=""
  local mpas_480_data_link=""
  local ioda_sentinel=""

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

  # Follow the exact CMake layouts used by the pinned projects. IODA and UFO
  # create their Data links from test/CMakeLists.txt, so the build-tree paths are
  # below ioda/test and ufo/test. MPAS-JEDI likewise creates Data below
  # mpas-jedi/test and links the 384km/480km background directories there.
  ioda_data_link="${MONAN_JEDI_BUILD_DIR}/ioda/test/Data/testinput_tier_1"
  ufo_data_link="${MONAN_JEDI_BUILD_DIR}/ufo/test/Data/ufo/testinput_tier_1"
  mpas_384_data_link="${MONAN_JEDI_BUILD_DIR}/mpas-jedi/test/Data/384km/bg"
  mpas_480_data_link="${MONAN_JEDI_BUILD_DIR}/mpas-jedi/test/Data/480km/bg"

  monan_jedi_validate_build_data_link \
    "${ioda_data_link}" \
    "${MONAN_JEDI_SOURCE_DIR}/ioda-data/testinput_tier_1" \
    "IODA" || return 1

  monan_jedi_validate_build_data_link \
    "${ufo_data_link}" \
    "${MONAN_JEDI_SOURCE_DIR}/ufo-data/testinput_tier_1" \
    "UFO" || return 1

  monan_jedi_validate_build_data_link \
    "${mpas_384_data_link}" \
    "${MONAN_JEDI_SOURCE_DIR}/mpas-jedi-data/testinput_tier_1/384km/bg" \
    "MPAS-JEDI 384km" || return 1

  monan_jedi_validate_build_data_link \
    "${mpas_480_data_link}" \
    "${MONAN_JEDI_SOURCE_DIR}/mpas-jedi-data/testinput_tier_1/480km/bg" \
    "MPAS-JEDI 480km" || return 1

  # Keep a representative binary-file check through the exact path used by
  # IODA CTest. This catches a pointer that somehow survived source validation.
  ioda_sentinel="${ioda_data_link}/sondes_obs_2018041500_m.nc4"
  if [[ ! -s "${ioda_sentinel}" ]]; then
    log_error "Representative IODA CTest data file is missing or empty: ${ioda_sentinel}"
    return 1
  fi

  if monan_jedi_file_is_lfs_pointer "${ioda_sentinel}"; then
    log_error "CTest resolves an unmaterialized Git LFS pointer through the IODA build-tree link."
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
