#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${repo_root}/scripts/lib/test_data.sh"
source "${repo_root}/scripts/lib/pbs.sh"

log_error() {
  printf 'ERROR: %s\n' "$*" >&2
}

log_info() {
  :
}

assert_equal() {
  local expected="$1"
  local actual="$2"
  local description="$3"

  if [[ "${actual}" != "${expected}" ]]; then
    printf 'ERROR: %s: expected <%s>, got <%s>\n' \
      "${description}" "${expected}" "${actual}" >&2
    exit 1
  fi
}

assert_equal '#PBS -l place=excl' \
  "$(monan_jedi_pbs_placement_directive pesqmini)" \
  "compute queue placement"
assert_equal '#PBS -l place=excl' \
  "$(monan_jedi_pbs_placement_directive desenvolvimento@pbs-ha)" \
  "server-qualified compute queue placement"
assert_equal '' \
  "$(monan_jedi_pbs_placement_directive aux)" \
  "aux queue exception"
assert_equal '' \
  "$(monan_jedi_pbs_placement_directive aux@pbs-ha)" \
  "server-qualified aux queue exception"

test_dir="$(mktemp -d)"
trap 'rm -rf "${test_dir}"' EXIT

compute_script="${test_dir}/compute.pbs"
aux_script="${test_dir}/aux.pbs"

lfs_pointer="${test_dir}/pointer.nc4"
real_data="${test_dir}/real.nc4"
printf '%s\n' \
  'version https://git-lfs.github.com/spec/v1' \
  'oid sha256:0123456789abcdef' \
  'size 304016' > "${lfs_pointer}"
printf '\211HDF\r\n\032\n' > "${real_data}"

if ! monan_jedi_file_is_lfs_pointer "${lfs_pointer}"; then
  echo "ERROR: Git LFS pointer signature was not detected" >&2
  exit 1
fi
if monan_jedi_file_is_lfs_pointer "${real_data}"; then
  echo "ERROR: materialized HDF5 data was classified as a Git LFS pointer" >&2
  exit 1
fi

assert_equal \
  '/p/projetos/monan_das/test-user/envs/git-lfs' \
  "$(USER=test-user PROJECT_ROOT= MONAN_JEDI_GIT_LFS_ROOT= monan_jedi_git_lfs_root)" \
  "default project Git LFS fallback location"
assert_equal \
  '/custom/project/envs/git-lfs' \
  "$(PROJECT_ROOT=/custom/project MONAN_JEDI_GIT_LFS_ROOT= monan_jedi_git_lfs_root)" \
  "project-derived Git LFS fallback location"
assert_equal \
  '/custom/git-lfs' \
  "$(PROJECT_ROOT=/custom/project MONAN_JEDI_GIT_LFS_ROOT=/custom/git-lfs monan_jedi_git_lfs_root)" \
  "explicit Git LFS fallback location"

printf '%s\n' '#!/bin/bash' '#PBS -q pesqmini' '#PBS -l place=excl' > "${compute_script}"
printf '%s\n' '#!/bin/bash' '#PBS -q aux' > "${aux_script}"

monan_jedi_validate_pbs_placement_policy "${compute_script}" pesqmini
monan_jedi_validate_pbs_placement_policy "${aux_script}" aux

if (monan_jedi_validate_pbs_placement_policy "${aux_script}" pesqmini) 2>/dev/null; then
  echo "ERROR: compute queue validation accepted a missing exclusive directive" >&2
  exit 1
fi

printf '%s\n' '#PBS -l place=excl' >> "${aux_script}"
if (monan_jedi_validate_pbs_placement_policy "${aux_script}" aux) 2>/dev/null; then
  echo "ERROR: aux queue validation accepted an exclusive directive" >&2
  exit 1
fi

# Bootstrap regression checks: compute nodes may still expose Python 3.6.
read_config="${repo_root}/scripts/lib/read_config.py"
config_lib="${repo_root}/scripts/lib/config.sh"
stack_lib="${repo_root}/scripts/lib/stack.sh"
pbs_lib="${repo_root}/scripts/lib/pbs.sh"
test_data_lib="${repo_root}/scripts/lib/test_data.sh"
configure_lib="${repo_root}/scripts/lib/configure.sh"
readme="${repo_root}/README.md"
test_data_doc="${repo_root}/docs/jedi-test-data.md"

if grep -Fq 'from __future__ import annotations' "${read_config}"; then
  echo "ERROR: read_config.py requires Python 3.7 annotations support" >&2
  exit 1
fi
grep -Fq 'from typing import Any, Dict' "${read_config}"
grep -Fq 'if ! config_exports="$(python3' "${config_lib}"
grep -Fq 'trap finalize_pbs_result EXIT' "${pbs_lib}"
grep -Fq 'ERROR_PHASE=' "${pbs_lib}"
grep -Fq 'PBS_LOG=' "${pbs_lib}"
grep -Fq 'monan_jedi_validate_bundle_test_data' "${pbs_lib}"
grep -Fq 'monan_jedi_prepare_bundle_test_data' "${configure_lib}"
grep -Fq 'version https://git-lfs.github.com/spec/v1' "${test_data_lib}"
grep -Fq 'envs/git-lfs' "${test_data_lib}"
grep -Fq 'provider=${provider}' "${test_data_lib}"
grep -Fq 'loaded stack/environment' "${test_data_lib}"
grep -Fq 'project-local fallback' "${test_data_lib}"
grep -Fq 'project_fallback_env=' "${test_data_lib}"
grep -Fq 'module load anaconda' "${test_data_lib}"
grep -Fq 'start_conda' "${test_data_lib}"
grep -Fq 'command -v git-lfs' "${stack_lib}"
grep -Fq 'git lfs version' "${stack_lib}"
grep -Fq 'spack-stack already provides Git LFS' "${readme}"
grep -Fq 'provider=loaded stack/environment' "${readme}"
grep -Fq 'No Conda installation is required' "${test_data_doc}"
grep -Fq 'project-local persistent installation is used only as fallback' "${test_data_doc}"

# Variables evaluated only by the generated PBS job must remain escaped in the
# outer heredoc. Audit the complete generated body so a future unescaped
# runtime variable fails CI before test-pbs reaches JACI.
generated_pbs_body="$(
  sed -n '/cat > .*<<EOF_PBS/,/^EOF_PBS$/p' "${pbs_lib}"
)"
# Only job-local variables are listed here. Configuration variables exported
# by the generator intentionally have both expanded and escaped occurrences.
runtime_variables=(
  job_phase termination_reason job_rc result_tmp ctest_rc
  total_tests passed_tests failed_tests result result_exit
  ctest_args PIPESTATUS pipeline_status tee_rc summary_line BASH_REMATCH
)
for runtime_variable in "${runtime_variables[@]}"; do
  if grep -Eq '(^|[^\\])\$\{'"${runtime_variable}"'\}' <<< "${generated_pbs_body}"; then
    echo "ERROR: generated PBS runtime variable is expanded by the outer heredoc: ${runtime_variable}" >&2
    exit 1
  fi
done

# Positional parameters in the generated signal handler require the same
# protection but do not use braced variable syntax.
grep -Fq 'termination_reason="\$1"' "${pbs_lib}"
grep -Fq 'exit "\$2"' "${pbs_lib}"

python3 "${read_config}" "${repo_root}/config/jaci.yaml" > "${test_dir}/exports.sh"
bash -n "${test_dir}/exports.sh"

fake_bin="${test_dir}/bin"
mkdir -p "${fake_bin}"
cat > "${fake_bin}/python3" <<'EOF_FAKE_PYTHON'
#!/usr/bin/env bash
echo "simulated configuration reader failure" >&2
exit 42
EOF_FAKE_PYTHON
chmod +x "${fake_bin}/python3"

if (
  PATH="${fake_bin}:${PATH}"
  MONAN_JEDI_CONFIG="${repo_root}/config/jaci.yaml"
  source "${repo_root}/scripts/lib/common.sh"
  source "${config_lib}"
  load_monan_jedi_config
) >"${test_dir}/loader.out" 2>"${test_dir}/loader.err"; then
  echo "ERROR: configuration loader ignored reader failure" >&2
  exit 1
fi
grep -Fq 'Failed to load configuration' "${test_dir}/loader.err"
if grep -Fq 'unbound variable' "${test_dir}/loader.err"; then
  echo "ERROR: configuration loader continued after reader failure" >&2
  exit 1
fi

echo "PBS placement and bootstrap contract checks passed."
