#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${repo_root}/scripts/lib/pbs.sh"

log_error() {
  printf 'ERROR: %s\n' "$*" >&2
}

assert_equal() {
  local expected="$1"
  local actual="$2"
  local description="$3"

  if [[ "${actual}" != "${expected}" ]]; then
    printf 'ERROR: %s: expected <%s>, got <%s>\n'       "${description}" "${expected}" "${actual}" >&2
    exit 1
  fi
}

assert_equal '#PBS -l place=excl'   "$(monan_jedi_pbs_placement_directive pesqmini)"   "compute queue placement"
assert_equal '#PBS -l place=excl'   "$(monan_jedi_pbs_placement_directive desenvolvimento@pbs-ha)"   "server-qualified compute queue placement"
assert_equal ''   "$(monan_jedi_pbs_placement_directive aux)"   "aux queue exception"
assert_equal ''   "$(monan_jedi_pbs_placement_directive aux@pbs-ha)"   "server-qualified aux queue exception"

test_dir="$(mktemp -d)"
trap 'rm -rf "${test_dir}"' EXIT

compute_script="${test_dir}/compute.pbs"
aux_script="${test_dir}/aux.pbs"

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

echo "PBS placement policy checks passed."
