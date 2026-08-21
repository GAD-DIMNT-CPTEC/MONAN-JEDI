#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
configure_script="${repo_root}/scripts/lib/configure.sh"
build_script="${repo_root}/scripts/lib/build.sh"
doc_file="${repo_root}/docs/unbalance_ensemble_executable.md"

require_text() {
  local file="$1"
  local text="$2"
  if ! grep -Fq "${text}" "${file}"; then
    echo "ERROR: expected text not found in ${file}: ${text}" >&2
    exit 1
  fi
}

require_text "${configure_script}" 'apply_unbalance_ensemble_patches.sh'
require_text "${configure_script}" '04_ecbuild_materialize.log'
require_text "${configure_script}" 'mpasjedi_unbalance_ensemble.x'
require_text "${configure_script}" 'monan_jedi_validate_unbalance_patch_markers'
require_text "${configure_script}" 'target_help="$(cmake --build'
require_text "${configure_script}" 'CMAKE_RUNTIME_OUTPUT_DIRECTORY=${MONAN_JEDI_INSTALL_BIN_DIR}'
require_text "${build_script}" 'mpasjedi_process_perts.x'
require_text "${build_script}" 'mpasjedi_unbalance_ensemble.x'
require_text "${build_script}" 'MONAN_JEDI_BUILD_DIR}/bin'
require_text "${build_script}" 'MONAN_JEDI_INSTALL_BIN_DIR'
require_text "${build_script}" '"build"'
require_text "${build_script}" '"install"'
require_text "${doc_file}" 'applies the required patches automatically'
require_text "${doc_file}" '${build.dir}/bin/mpasjedi_unbalance_ensemble.x'
require_text "${doc_file}" '${install.root}/bin/mpasjedi_unbalance_ensemble.x'

# Regression test for the pipefail/SIGPIPE false negative observed on JACI.
# The previous implementation piped this large listing directly into grep -q.
# Once grep found the target, the producer received SIGPIPE and the pipeline
# was treated as failed even though the target was registered.
source "${configure_script}"

log_info() { :; }
log_error() { printf 'ERROR: %s\n' "$*" >&2; }

MONAN_JEDI_BUILD_DIR="/tmp/monan-jedi-target-validation"
MONAN_JEDI_INSTALL_BIN_DIR="/tmp/monan-jedi-target-validation/bin"

cmake() {
  printf '%s\n' "... mpasjedi_unbalance_ensemble.x"
  seq 1 200000
}

set -o pipefail
monan_jedi_validate_unbalance_target

echo "Unbalance build contract checks passed."
