#!/usr/bin/env bash
# =============================================================================
# 11_test_all_ctest_pbs.sh
# =============================================================================
# Run the full configured CTest suite on JACI through PBS.
#
# Purpose
# -------
# The configured reduced JEDI/MPAS-JEDI bundle currently exposes more than 2000
# CTest tests, including MPI and non-MPI tests from OOPS, IODA, UFO, CRTM and
# MPAS-JEDI.
#
# This launcher runs the full suite by submitting scripts/06_test_mpas_jedi_pbs.sh
# with no CTest regex filter. This means no `-R` argument is passed to CTest.
#
# Usage
# -----
#   export STACK_TEST_ID=spack-stack-inpe-overlay-20260515T181917Z
#   export MONAN_JEDI_TEST_ID=monan-jedi-mpas-only-20260516T170436Z
#   bash scripts/11_test_all_ctest_pbs.sh
#
# Optional overrides
# ------------------
#   MONAN_JEDI_PBS_QUEUE=pesqmini
#   MONAN_JEDI_PBS_NCPUS=64
#   MONAN_JEDI_PBS_WALLTIME=04:00:00
#   MONAN_JEDI_CTEST_JOBS=1
#
# Notes
# -----
# This may take substantially longer than the MPAS-JEDI-only subset.
# The first full run should use MONAN_JEDI_CTEST_JOBS=1 for clearer diagnostics.
# =============================================================================

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export MONAN_JEDI_TEST_LABEL="${MONAN_JEDI_TEST_LABEL:-full_ctest}"
export MONAN_JEDI_CTEST_REGEX=""
export MONAN_JEDI_CTEST_EXCLUDE_REGEX="${MONAN_JEDI_CTEST_EXCLUDE_REGEX:-}"
export MONAN_JEDI_PBS_WALLTIME="${MONAN_JEDI_PBS_WALLTIME:-04:00:00}"
export MONAN_JEDI_CTEST_JOBS="${MONAN_JEDI_CTEST_JOBS:-1}"

bash "${script_dir}/06_test_mpas_jedi_pbs.sh"
