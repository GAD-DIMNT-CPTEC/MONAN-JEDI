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

# Bootstrap regression checks: compute nodes may still expose Python 3.6.
read_config="${repo_root}/scripts/lib/read_config.py"
config_lib="${repo_root}/scripts/lib/config.sh"
pbs_lib="${repo_root}/scripts/lib/pbs.sh"

if grep -Fq 'from __future__ import annotations' "${read_config}"; then
  echo "ERROR: read_config.py requires Python 3.7 annotations support" >&2
  exit 1
fi
grep -Fq 'from typing import Any, Dict' "${read_config}"
grep -Fq 'if ! config_exports="$(python3' "${config_lib}"
grep -Fq 'trap finalize_pbs_result EXIT' "${pbs_lib}"
grep -Fq 'ERROR_PHASE=' "${pbs_lib}"
grep -Fq 'PBS_LOG=' "${pbs_lib}"
# Positional parameters belong to the generated PBS signal handler. They must
# remain escaped in this outer heredoc or set -u aborts test-pbs generation.
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
