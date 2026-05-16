#!/usr/bin/env bash
# =============================================================================
# 02_prepare_jedi_bundle.sh
# =============================================================================
# Clone or update JCSDA/jedi-bundle and initialize submodules.
# =============================================================================

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00_common.sh
source "${script_dir}/00_common.sh"

require_cmd git
load_monan_jedi_stack

mkdir -p "$(dirname "${JEDI_BUNDLE_SRC_DIR}")" "${MONAN_JEDI_LOG_ROOT}"

log_info "Preparing JEDI bundle source"
log_info "  JEDI_BUNDLE_REPO=${JEDI_BUNDLE_REPO}"
log_info "  JEDI_BUNDLE_REF=${JEDI_BUNDLE_REF}"
log_info "  JEDI_BUNDLE_SRC_DIR=${JEDI_BUNDLE_SRC_DIR}"

if [[ ! -d "${JEDI_BUNDLE_SRC_DIR}/.git" ]]; then
  git clone "${JEDI_BUNDLE_REPO}" "${JEDI_BUNDLE_SRC_DIR}"
fi

cd "${JEDI_BUNDLE_SRC_DIR}"
git fetch --all --tags --prune
git checkout "${JEDI_BUNDLE_REF}"
git submodule sync --recursive || true
git submodule update --init --recursive --checkout || true

{
  echo "JEDI_BUNDLE_REPO=${JEDI_BUNDLE_REPO}"
  echo "JEDI_BUNDLE_REF=${JEDI_BUNDLE_REF}"
  echo "JEDI_BUNDLE_SRC_DIR=${JEDI_BUNDLE_SRC_DIR}"
  echo "commit=$(git rev-parse HEAD)"
  echo "describe=$(git describe --tags --always --dirty || true)"
  echo
  git status --short
  echo
  git submodule status --recursive || true
} | tee "${MONAN_JEDI_LOG_ROOT}/02_jedi_bundle_source_state.log"

log_info "JEDI bundle source preparation completed."
