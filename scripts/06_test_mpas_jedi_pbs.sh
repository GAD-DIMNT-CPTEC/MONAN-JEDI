#!/usr/bin/env bash
# =============================================================================
# 06_test_mpas_jedi_pbs.sh
# =============================================================================
# Submit CTest execution to a PBS compute node on JACI.
#
# This script follows the validated pattern from the predecessor repository:
# tests that use Cray PALS must run inside a scheduler allocation. On the login
# node, even simple MPI launches can fail with:
#
#   No host list provided
#
# Default test:
#   ^mpasjedi_geometry$
#
# For all MPAS-JEDI tests except the known numerical reference issue:
#
#   MONAN_JEDI_CTEST_REGEX='^mpasjedi_' \
#   MONAN_JEDI_CTEST_EXCLUDE_REGEX='^mpasjedi_lgetkf_height_vloc$' \
#   bash scripts/06_test_mpas_jedi_pbs.sh
#
# For the full CTest suite, prefer:
#
#   bash scripts/11_test_all_ctest_pbs.sh
#
# =============================================================================

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00_common.sh
source "${script_dir}/00_common.sh"

require_cmd qsub

export MONAN_JEDI_PBS_QUEUE="${MONAN_JEDI_PBS_QUEUE:-pesqmini}"
export MONAN_JEDI_PBS_NCPUS="${MONAN_JEDI_PBS_NCPUS:-64}"
export MONAN_JEDI_PBS_WALLTIME="${MONAN_JEDI_PBS_WALLTIME:-00:30:00}"
export MONAN_JEDI_CTEST_REGEX="${MONAN_JEDI_CTEST_REGEX:-^mpasjedi_geometry$}"
export MONAN_JEDI_CTEST_EXCLUDE_REGEX="${MONAN_JEDI_CTEST_EXCLUDE_REGEX:-}"
export MONAN_JEDI_CTEST_JOBS="${MONAN_JEDI_CTEST_JOBS:-1}"
export MONAN_JEDI_SUBMIT_JOB="${MONAN_JEDI_SUBMIT_JOB:-1}"
export MONAN_JEDI_TEST_LOG_STAMP="${MONAN_JEDI_TEST_LOG_STAMP:-$(date -u +%Y%m%dT%H%M%SZ)}"
export MONAN_JEDI_TEST_LABEL="${MONAN_JEDI_TEST_LABEL:-mpas_jedi_tests}"

mkdir -p "${MONAN_JEDI_LOG_ROOT}"

if [[ ! -d "${JEDI_BUNDLE_BUILD_DIR}" ]]; then
  log_error "JEDI_BUNDLE_BUILD_DIR not found: ${JEDI_BUNDLE_BUILD_DIR}"
  exit 1
fi

case "${PWD}" in
  /p/*|/lustre/*) ;;
  *)
    log_error "Current repository directory is not under /p or /lustre: ${PWD}"
    log_error "JACI compute nodes require programs and data under /p or /lustre."
    exit 1
    ;;
esac

case "${JEDI_BUNDLE_BUILD_DIR}" in
  /p/*|/lustre/*) ;;
  *)
    log_error "JEDI_BUNDLE_BUILD_DIR is not under /p or /lustre: ${JEDI_BUNDLE_BUILD_DIR}"
    log_error "JACI compute nodes require programs and data under /p or /lustre."
    exit 1
    ;;
esac

safe_regex_name="$(printf '%s' "${MONAN_JEDI_CTEST_REGEX:-all}" | sed -E 's/[^A-Za-z0-9_.-]+/_/g; s/^_+//; s/_+$//')"
[[ -n "${safe_regex_name}" ]] || safe_regex_name="all"
safe_label_name="$(printf '%s' "${MONAN_JEDI_TEST_LABEL}" | sed -E 's/[^A-Za-z0-9_.-]+/_/g; s/^_+//; s/_+$//')"
[[ -n "${safe_label_name}" ]] || safe_label_name="ctest"

pbs_script="${MONAN_JEDI_LOG_ROOT}/${safe_label_name}_${safe_regex_name}_${MONAN_JEDI_TEST_LOG_STAMP}.pbs"
pbs_log="${MONAN_JEDI_LOG_ROOT}/${safe_label_name}_${safe_regex_name}_${MONAN_JEDI_TEST_LOG_STAMP}.pbs.log"
ctest_log="${MONAN_JEDI_LOG_ROOT}/${safe_label_name}_${safe_regex_name}_${MONAN_JEDI_TEST_LOG_STAMP}.ctest.log"
latest_pbs_script="${MONAN_JEDI_LOG_ROOT}/06_mpas_jedi_ctest.pbs"
latest_pbs_log="${MONAN_JEDI_LOG_ROOT}/06_ctest_pbs.out"
latest_pbs_err="${MONAN_JEDI_LOG_ROOT}/06_ctest_pbs.err"
latest_ctest_log="${MONAN_JEDI_LOG_ROOT}/06_ctest_pbs.log"

cat > "${pbs_script}" <<EOF
#!/bin/bash
#PBS -N monan_jedi_ctest
#PBS -q ${MONAN_JEDI_PBS_QUEUE}
#PBS -l select=1:ncpus=${MONAN_JEDI_PBS_NCPUS}
#PBS -l walltime=${MONAN_JEDI_PBS_WALLTIME}
#PBS -j oe
#PBS -o ${pbs_log}

set -euo pipefail

cd ${PWD}

export PROJECT_ROOT=${PROJECT_ROOT}
export STACK_TEST_ID=${STACK_TEST_ID}
export MONAN_JEDI_TEST_ID=${MONAN_JEDI_TEST_ID}
export STACK_WORK_ROOT=${STACK_WORK_ROOT}
export STACK_ENV_NAME=${STACK_ENV_NAME}
export STACK_ROOT=${STACK_ROOT}
export STACK_MODULE_ROOT=${STACK_MODULE_ROOT}
export STACK_ENV_MODULE=${STACK_ENV_MODULE}
export MONAN_JEDI_WORK_ROOT=${MONAN_JEDI_WORK_ROOT}
export MONAN_JEDI_LOG_ROOT=${MONAN_JEDI_LOG_ROOT}
export JEDI_BUNDLE_SRC_DIR=${JEDI_BUNDLE_SRC_DIR}
export JEDI_BUNDLE_BUILD_DIR=${JEDI_BUNDLE_BUILD_DIR}
export MONAN_JEDI_CTEST_REGEX='${MONAN_JEDI_CTEST_REGEX}'
export MONAN_JEDI_CTEST_EXCLUDE_REGEX='${MONAN_JEDI_CTEST_EXCLUDE_REGEX}'
export MONAN_JEDI_CTEST_JOBS=${MONAN_JEDI_CTEST_JOBS}
export CTEST_LOG='${ctest_log}'
export LATEST_CTEST_LOG='${latest_ctest_log}'

source ${script_dir}/00_common.sh
load_monan_jedi_stack

cd "${JEDI_BUNDLE_BUILD_DIR}"

ctest_args=(--output-on-failure -j "\${MONAN_JEDI_CTEST_JOBS}")
if [[ -n "\${MONAN_JEDI_CTEST_REGEX}" ]]; then
  ctest_args+=(-R "\${MONAN_JEDI_CTEST_REGEX}")
fi
if [[ -n "\${MONAN_JEDI_CTEST_EXCLUDE_REGEX}" ]]; then
  ctest_args+=(-E "\${MONAN_JEDI_CTEST_EXCLUDE_REGEX}")
fi

{
  echo "=== MONAN-JEDI PBS CTest job ==="
  echo "GeneratedAt=\$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Host=\$(hostname)"
  echo "PBS_JOBID=\${PBS_JOBID:-}"
  echo "PBS_QUEUE=\${PBS_QUEUE:-}"
  echo "PBS_NODEFILE=\${PBS_NODEFILE:-}"
  echo "PWD=\$(pwd)"
  echo "MONAN_JEDI_CTEST_REGEX=\${MONAN_JEDI_CTEST_REGEX}"
  echo "MONAN_JEDI_CTEST_EXCLUDE_REGEX=\${MONAN_JEDI_CTEST_EXCLUDE_REGEX}"
  echo "MONAN_JEDI_CTEST_JOBS=\${MONAN_JEDI_CTEST_JOBS}"
  echo "CTEST_LOG=\${CTEST_LOG}"
  echo "which ctest=\$(command -v ctest || echo NOT_FOUND)"
  echo "which mpiexec=\$(command -v mpiexec || echo NOT_FOUND)"
  echo "which mpirun=\$(command -v mpirun || echo NOT_FOUND)"
  module list 2>&1 || true
  echo "=== MPI smoke test ==="
  mpiexec -n 1 /bin/hostname
  echo "=== CTest execution ==="
  printf 'ctest command:'
  printf ' %q' ctest "\${ctest_args[@]}"
  printf '\n'
} | tee "${MONAN_JEDI_LOG_ROOT}/06_ctest_pbs_environment.log"

ctest "\${ctest_args[@]}" 2>&1 | tee "\${CTEST_LOG}"
cp -f "\${CTEST_LOG}" "\${LATEST_CTEST_LOG}"
EOF

chmod +x "${pbs_script}"
cp -f "${pbs_script}" "${latest_pbs_script}"
: > "${latest_pbs_err}"
ln -sfn "$(basename "${pbs_log}")" "${latest_pbs_log}"

log_info "PBS CTest job prepared"
log_info "  PBS script=${pbs_script}"
log_info "  latest PBS script=${latest_pbs_script}"
log_info "  PBS output=${pbs_log}"
log_info "  latest PBS output=${latest_pbs_log}"
log_info "  CTest log=${ctest_log}"
log_info "  latest CTest log=${latest_ctest_log}"
log_info "  queue=${MONAN_JEDI_PBS_QUEUE}"
log_info "  ncpus=${MONAN_JEDI_PBS_NCPUS}"
log_info "  walltime=${MONAN_JEDI_PBS_WALLTIME}"
log_info "  regex=${MONAN_JEDI_CTEST_REGEX:-<none, full suite>}"
log_info "  exclude=${MONAN_JEDI_CTEST_EXCLUDE_REGEX:-<none>}"

if [[ "${MONAN_JEDI_SUBMIT_JOB}" == "1" ]]; then
  qsub "${pbs_script}" | tee "${MONAN_JEDI_LOG_ROOT}/06_ctest_pbs_jobid.txt"
else
  log_info "Not submitting automatically. Review and submit with: qsub ${pbs_script}"
fi
