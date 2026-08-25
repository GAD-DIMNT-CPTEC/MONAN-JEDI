#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${repo_root}/scripts/lib/common.sh"
source "${repo_root}/scripts/lib/stack.sh"

test_dir="$(mktemp -d)"
trap 'rm -rf "${test_dir}"' EXIT

# A fully valid inherited environment must be reused instead of purged/reloaded.
reuse_log="${test_dir}/reuse.log"
(
  monan_jedi_stack_environment_ready() { return 0; }
  monan_jedi_expose_spack_cli() { printf 'expose-spack\n'; }
  monan_jedi_report_stack_environment() { printf 'report:%s\n' "$*"; }
  monan_jedi_reset_modules() {
    printf 'ERROR: reset called for a valid environment\n' >&2
    return 1
  }

  monan_jedi_load_stack
) >"${reuse_log}" 2>&1

grep -Fq 'report:already loaded and valid; reusing' "${reuse_log}"
if grep -Fq 'reset called' "${reuse_log}"; then
  echo 'ERROR: valid inherited stack environment was unnecessarily reset' >&2
  exit 1
fi

# An incomplete environment must be rebuilt, validated and leave the caller in
# the same working directory. Mock site/module operations so this runs in CI.
stack_root="${test_dir}/stack"
module_root="${test_dir}/modules"
work_dir="${test_dir}/checkout"
mkdir -p "${stack_root}/configs/sites/tier2/jaci" "${stack_root}/spack/bin" "${module_root}" "${work_dir}"
printf ':\n' > "${stack_root}/configs/sites/tier2/jaci/setup.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "${stack_root}/spack/bin/spack"
chmod +x "${stack_root}/spack/bin/spack"

(
  cd "${work_dir}"
  original_dir="${PWD}"

  export STACK_ROOT="${stack_root}"
  export STACK_MODULE_ROOT="${module_root}"
  export STACK_SITE_SETUP='configs/sites/tier2/jaci/setup.sh'
  export STACK_ENV_MODULE='fake/jedi-mpas-env/1.0.0'
  export STACK_INSTANCE='fake-stack'
  export MONAN_JEDI_RUN_ID='test'
  export MONAN_JEDI_CONFIG='config/test.yaml'

  export MONAN_JEDI_CC='cc'
  export MONAN_JEDI_CXX='CC'
  export MONAN_JEDI_FC='ftn'
  export MONAN_JEDI_F77='ftn'
  export MONAN_JEDI_F90='ftn'
  export MONAN_JEDI_MPICC='cc'
  export MONAN_JEDI_MPICXX='CC'
  export MONAN_JEDI_MPIFC='ftn'
  export MONAN_JEDI_MPIF77='ftn'
  export MONAN_JEDI_MPIF90='ftn'

  ready_calls=0
  monan_jedi_stack_environment_ready() {
    ready_calls=$((ready_calls + 1))
    [[ "${ready_calls}" -ge 2 ]]
  }
  monan_jedi_reset_modules() { :; }
  monan_jedi_expose_spack_cli() { :; }
  monan_jedi_report_stack_environment() { :; }
  module() { :; }
  resolve_cmd() { printf '/bin/true\n'; }

  monan_jedi_load_stack

  [[ "${PWD}" == "${original_dir}" ]] || {
    echo "ERROR: stack bootstrap changed working directory from ${original_dir} to ${PWD}" >&2
    exit 1
  }
  [[ "${ready_calls}" -ge 2 ]] || {
    echo 'ERROR: stack bootstrap did not validate the loaded environment' >&2
    exit 1
  }
  [[ "${CC}" == '/bin/true' && "${CXX}" == '/bin/true' && "${FC}" == '/bin/true' ]] || {
    echo 'ERROR: stack bootstrap did not normalize compiler variables' >&2
    exit 1
  }
)

# Every entry point that actually uses stack software must bootstrap through the
# common loader. Result/log inspection commands intentionally do not need it.
for path in \
  scripts/lib/configure.sh \
  scripts/lib/build.sh \
  scripts/lib/test.sh \
  scripts/lib/obs2ioda.sh \
  scripts/lib/wps.sh
do
  grep -Fq 'monan_jedi_load_stack' "${repo_root}/${path}" || {
    echo "ERROR: stack-dependent workflow module does not bootstrap environment: ${path}" >&2
    exit 1
  }
done

grep -A20 -F 'test-pbs)' "${repo_root}/scripts/monan-jedi.sh" | grep -Fq 'monan_jedi_load_stack'

echo 'Stack environment bootstrap contract checks passed.'
