#!/usr/bin/env bash
# =============================================================================
# 01_load_stack_env.sh
# =============================================================================
# Load and validate the JACI spack-stack environment used by MONAN-JEDI.
# =============================================================================

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00_common.sh
source "${script_dir}/00_common.sh"

load_monan_jedi_stack

record_environment_snapshot "${MONAN_JEDI_LOG_ROOT}/01_stack_environment.log"

python --version | tee "${MONAN_JEDI_LOG_ROOT}/01_python_version.log"
python -c "import mpi4py; print('mpi4py ok')" | tee "${MONAN_JEDI_LOG_ROOT}/01_mpi4py.log"
python -c "import netCDF4; print('netCDF4 ok')" | tee "${MONAN_JEDI_LOG_ROOT}/01_netcdf4.log"

log_info "Stack environment validation completed."
