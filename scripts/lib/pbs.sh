#!/usr/bin/env bash
# PBS test submission.
#
# Purpose:
#   Centralize PBS-related variables and provide the interface for submitting
#   larger MONAN-JEDI test workloads to the JACI batch system.
#
# Current state:
#   This module is intentionally minimal. The current implementation only
#   validates qsub availability and exports the PBS-specific CTest regex.
#   The complete PBS generation and submission logic from the older workflow
#   still needs to be migrated.
#
# Expected future result:
#   Submit a PBS batch job that executes the configured CTest subset outside
#   the login node.

monan_jedi_test_pbs() {
  require_cmd qsub

  export MONAN_JEDI_CTEST_REGEX="${MONAN_JEDI_CTEST_PBS_REGEX:-^mpasjedi_geometry$}"

  log_warn "PBS implementation should reuse the current generation logic from scripts/06_test_mpas_jedi_pbs.sh."
  log_warn "This module defines the interface and centralizes PBS variables from YAML."
}
