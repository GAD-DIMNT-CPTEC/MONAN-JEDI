#!/usr/bin/env bash

set -euo pipefail

readonly SABER_COMMIT="d05c06fcc7da97389a19594a2e5424e709648330"
readonly MPAS_JEDI_COMMIT="19eb7fb3273c7b3094825201af184834c15afdd0"

root_dir="$(git rev-parse --show-toplevel)"
readonly root_dir

declare -a applied=()
declare -a already_applied=()

apply_patch() {
  local component="$1"
  local expected_commit="$2"
  local patch_file="$3"
  local component_dir="${root_dir}/${component}"
  local actual_commit

  if [[ ! -d "${component_dir}" ]]; then
    echo "ERROR: required component directory does not exist: ${component_dir}" >&2
    exit 1
  fi

  if ! git -C "${component_dir}" rev-parse --git-dir >/dev/null 2>&1; then
    echo "ERROR: component is not a Git worktree: ${component_dir}" >&2
    exit 1
  fi

  actual_commit="$(git -C "${component_dir}" rev-parse HEAD)"
  if [[ "${actual_commit}" != "${expected_commit}" ]]; then
    echo "ERROR: ${component} is at ${actual_commit}; expected ${expected_commit}" >&2
    exit 1
  fi

  if [[ ! -f "${patch_file}" ]]; then
    echo "ERROR: patch file does not exist: ${patch_file}" >&2
    exit 1
  fi

  if git -C "${component_dir}" apply --reverse --check "${patch_file}" >/dev/null 2>&1; then
    echo "${component}: patch already applied"
    already_applied+=("${component}")
    return
  fi

  echo "${component}: checking patch"
  git -C "${component_dir}" apply --check "${patch_file}"
  echo "${component}: applying patch"
  git -C "${component_dir}" apply "${patch_file}"
  applied+=("${component}")
}

apply_patch \
  "saber" \
  "${SABER_COMMIT}" \
  "${root_dir}/patches/unbalance/saber-unbalance-ensemble.patch"

apply_patch \
  "mpas-jedi" \
  "${MPAS_JEDI_COMMIT}" \
  "${root_dir}/patches/unbalance/mpas-jedi-unbalance-ensemble.patch"

echo
echo "Unbalance ensemble patch summary:"
if (( ${#applied[@]} > 0 )); then
  printf '  applied: %s\n' "${applied[*]}"
else
  echo "  applied: none"
fi
if (( ${#already_applied[@]} > 0 )); then
  printf '  already applied: %s\n' "${already_applied[*]}"
else
  echo "  already applied: none"
fi
