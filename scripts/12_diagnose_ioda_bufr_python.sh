#!/usr/bin/env bash
# =============================================================================
# 12_diagnose_ioda_bufr_python.sh
# =============================================================================
# Diagnose the IODA BUFR Python test failures:
#
#   ioda_bufr_python_encoder
#   ioda_bufr_python_parallel
#
# Observed failure:
#
#   ModuleNotFoundError: No module named 'bufr'
#
# This script verifies whether the active JACI spack-stack environment exposes
# the Python module expected by those tests and collects the CTest commands,
# Python sys.path, loaded modules and Spack package inventory.
# =============================================================================

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00_common.sh
source "${script_dir}/00_common.sh"

load_monan_jedi_stack
require_cmd ctest
require_cmd python

export DIAG_DIR="${DIAG_DIR:-${MONAN_JEDI_LOG_ROOT}/diagnostics/ioda_bufr_python}"
mkdir -p "${DIAG_DIR}"

if [[ ! -d "${JEDI_BUNDLE_BUILD_DIR}" ]]; then
  log_error "JEDI_BUNDLE_BUILD_DIR not found: ${JEDI_BUNDLE_BUILD_DIR}"
  exit 1
fi

cd "${JEDI_BUNDLE_BUILD_DIR}"

{
  echo "# IODA BUFR Python diagnostic"
  echo "GeneratedAt=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Host=$(hostname)"
  echo "STACK_TEST_ID=${STACK_TEST_ID}"
  echo "MONAN_JEDI_TEST_ID=${MONAN_JEDI_TEST_ID}"
  echo "JEDI_BUNDLE_BUILD_DIR=${JEDI_BUNDLE_BUILD_DIR}"
  echo
  echo "## Module list"
  module list 2>&1 || true
  echo
  echo "## Python executable"
  command -v python || true
  python --version || true
  echo
  echo "## Python sys.path and import checks"
  python - <<'PY' || true
import importlib.util
import os
import sys
print("sys.executable=", sys.executable)
print("sys.prefix=", sys.prefix)
print("PYTHONPATH=", os.environ.get("PYTHONPATH", ""))
print("sys.path=")
for p in sys.path:
    print("  ", p)
for name in ["bufr", "eccodes", "pyiodaconv", "ioda"]:
    spec = importlib.util.find_spec(name)
    print(f"find_spec({name!r}) = {spec}")
    if spec is not None:
        try:
            mod = importlib.import_module(name)
            print(f"import {name}: OK from {getattr(mod, '__file__', 'built-in')}")
        except Exception as exc:
            print(f"import {name}: FAILED: {type(exc).__name__}: {exc}")
PY
  echo
  echo "## CTest command inventory"
  ctest -N -V -R '^(ioda_bufr_mhs|ioda_bufr_python_encoder|ioda_bufr_python_parallel)$' || true
  echo
  echo "## Test script imports"
  grep -RniE '^import |^from ' \
    "${JEDI_BUNDLE_BUILD_DIR}/ioda/test/testinput" \
    | grep -E 'bufr|eccodes|ioda|pyioda' || true
  echo
  echo "## Spack package inventory candidates"
  if command -v spack >/dev/null 2>&1; then
    spack find -lv 2>/dev/null | grep -Ei 'bufr|eccodes|ioda|ncep' || true
    echo
    echo "## Spack package-name search candidates"
    spack list 2>/dev/null | grep -Ei '(^|-)bufr|eccodes|ncep' || true
  else
    echo "spack command not available"
  fi
} | tee "${DIAG_DIR}/summary.log"

log_info "Running focused CTest diagnostics"
ctest --output-on-failure -V -R '^ioda_bufr_mhs$' \
  2>&1 | tee "${DIAG_DIR}/ioda_bufr_mhs.log" || true
ctest --output-on-failure -V -R '^ioda_bufr_python_encoder$' \
  2>&1 | tee "${DIAG_DIR}/ioda_bufr_python_encoder.log" || true
ctest --output-on-failure -V -R '^ioda_bufr_python_parallel$' \
  2>&1 | tee "${DIAG_DIR}/ioda_bufr_python_parallel.log" || true

log_info "IODA BUFR Python diagnostic written to: ${DIAG_DIR}"
