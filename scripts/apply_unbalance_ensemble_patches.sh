#!/usr/bin/env bash

set -euo pipefail

readonly SABER_COMMIT="d05c06fcc7da97389a19594a2e5424e709648330"
readonly MPAS_JEDI_COMMIT="19eb7fb3273c7b3094825201af184834c15afdd0"

root_dir="$(git rev-parse --show-toplevel)"
readonly root_dir

declare -a applied=()
declare -a already_applied=()

saber_patch_state() {
  local component_dir="$1"
  local markers=0

  [[ -f "${component_dir}/src/saber/oops/UnbalanceEnsemble.h" ]] && ((markers += 1))
  grep -q "leftInverseMultiply" \
    "${component_dir}/src/saber/oops/UnbalanceEnsemble.h" 2>/dev/null && ((markers += 1))
  grep -q "UnbalanceEnsemble.h" \
    "${component_dir}/src/saber/oops/CMakeLists.txt" 2>/dev/null && ((markers += 1))

  case "${markers}" in
    0) echo "not-applied" ;;
    3) echo "applied" ;;
    *) echo "partial" ;;
  esac
}

mpas_jedi_patch_state() {
  local component_dir="$1"
  local markers=0

  [[ -f "${component_dir}/src/mains/mpasUnbalanceEnsemble.cc" ]] && ((markers += 1))
  grep -q "UnbalanceEnsemble<mpas::Traits>" \
    "${component_dir}/src/mains/mpasUnbalanceEnsemble.cc" 2>/dev/null && ((markers += 1))
  grep -q "unbalance_ensemble" \
    "${component_dir}/src/mains/CMakeLists.txt" 2>/dev/null && ((markers += 1))

  case "${markers}" in
    0) echo "not-applied" ;;
    3) echo "applied" ;;
    *) echo "partial" ;;
  esac
}

apply_patch() {
  local component="$1"
  local expected_commit="$2"
  local patch_file="$3"
  local state_function="$4"
  local component_dir="${root_dir}/${component}"
  local actual_commit
  local patch_state

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

  patch_state="$(${state_function} "${component_dir}")"
  case "${patch_state}" in
    applied)
      echo "${component}: patch already applied"
      already_applied+=("${component}")
      return
      ;;
    partial)
      echo "ERROR: ${component} patch is partially applied; manual intervention is required" >&2
      exit 1
      ;;
    not-applied)
      ;;
    *)
      echo "ERROR: unexpected ${component} patch state: ${patch_state}" >&2
      exit 1
      ;;
  esac

  echo "${component}: checking patch"
  git -C "${component_dir}" apply --check "${patch_file}"
  echo "${component}: applying patch"
  git -C "${component_dir}" apply "${patch_file}"
  applied+=("${component}")
}

apply_patch \
  "saber" \
  "${SABER_COMMIT}" \
  "${root_dir}/patches/unbalance/saber-unbalance-ensemble.patch" \
  saber_patch_state

apply_patch \
  "mpas-jedi" \
  "${MPAS_JEDI_COMMIT}" \
  "${root_dir}/patches/unbalance/mpas-jedi-unbalance-ensemble.patch" \
  mpas_jedi_patch_state

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
