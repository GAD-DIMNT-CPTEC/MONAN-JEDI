#!/usr/bin/env bash
# PBS test submission.

monan_jedi_test_pbs() {
  require_cmd qsub

  export MONAN_JEDI_CTEST_REGEX="${MONAN_JEDI_CTEST_PBS_REGEX:-^mpasjedi_geometry$}"

  log_warn "PBS implementation should reuse the current generation logic from scripts/06_test_mpas_jedi_pbs.sh."
  log_warn "This module defines the interface and centralizes PBS variables from YAML."
}
