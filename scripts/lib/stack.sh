#!/usr/bin/env bash
# Stack environment handling.
#
# Purpose:
#   Load the JACI CrayPE environment and the selected spack-stack module set
#   required by MONAN-JEDI.

monan_jedi_reset_modules() {
  module --force purge 2>/dev/null || module purge 2>/dev/null || true

  module unload gcc/12.3.0/zstd/1.5.7 2>/dev/null || true
  module unload gcc 2>/dev/null || true
  module unload stack-gcc 2>/dev/null || true
  module unload gcc-native 2>/dev/null || true

  if [[ -n "${MODULEPATH:-}" ]]; then
    local cleaned_modulepath=""
    local entry
    IFS=':' read -r -a _monan_jedi_modulepath_entries <<< "${MODULEPATH}"
    for entry in "${_monan_jedi_modulepath_entries[@]}"; do
      case "${entry}" in
        *spack*modules*|*spack-stack*modules*|*envs/*/modules*)
          ;;
        *)
          if [[ -z "${cleaned_modulepath}" ]]; then
            cleaned_modulepath="${entry}"
          else
            cleaned_modulepath="${cleaned_modulepath}:${entry}"
          fi
          ;;
      esac
    done
    export MODULEPATH="${cleaned_modulepath}"
  fi

  for d in \
    /opt/cray/pe/modulefiles \
    /opt/cray/modulefiles \
    /opt/cray/pe/craype-targets/default/modulefiles \
    /p/app/modulefiles \
    /opt/cray/pals/modulefiles
  do
    [[ -d "${d}" ]] && module use "${d}"
  done
}

monan_jedi_load_stack() {
  local setup_script
  local spack_bin

  if [[ ! -d "${STACK_ROOT}" ]]; then
    log_error "STACK_ROOT not found: ${STACK_ROOT}"
    exit 1
  fi

  if [[ ! -d "${STACK_MODULE_ROOT}" ]]; then
    log_error "STACK_MODULE_ROOT not found: ${STACK_MODULE_ROOT}"
    exit 1
  fi

  setup_script="${STACK_ROOT}/${STACK_SITE_SETUP}"
  if [[ ! -f "${setup_script}" ]]; then
    log_error "STACK site setup script not found: ${setup_script}"
    exit 1
  fi

  monan_jedi_reset_modules

  cd "${STACK_ROOT}" || {
    log_error "Failed to enter stack root: ${STACK_ROOT}"
    exit 1
  }
  # shellcheck disable=SC1090
  source "${setup_script}"

  module use "${STACK_MODULE_ROOT}"
  module load "${STACK_ENV_MODULE}"

  # The generated environment module provides compilers and libraries, but it
  # does not necessarily place the Spack CLI itself in PATH. Auxiliary builds
  # use `spack location -i` only for dependency discovery, so expose the CLI
  # shipped with this exact stack installation without sourcing stack setup.sh.
  spack_bin="${STACK_ROOT}/spack/bin"
  if [[ -x "${spack_bin}/spack" ]]; then
    case ":${PATH}:" in
      *":${spack_bin}:"*) ;;
      *) export PATH="${spack_bin}:${PATH}" ;;
    esac
  fi

  export CC="$(resolve_cmd CC "${MONAN_JEDI_CC}")"
  export CXX="$(resolve_cmd CXX "${MONAN_JEDI_CXX}")"
  export FC="$(resolve_cmd FC "${MONAN_JEDI_FC}")"
  export F77="$(resolve_cmd F77 "${MONAN_JEDI_F77}")"
  export F90="$(resolve_cmd F90 "${MONAN_JEDI_F90}")"

  export MPICC="$(resolve_cmd MPICC "${MONAN_JEDI_MPICC}")"
  export MPICXX="$(resolve_cmd MPICXX "${MONAN_JEDI_MPICXX}")"
  export MPIFC="$(resolve_cmd MPIFC "${MONAN_JEDI_MPIFC}")"
  export MPIF77="$(resolve_cmd MPIF77 "${MONAN_JEDI_MPIF77}")"
  export MPIF90="$(resolve_cmd MPIF90 "${MONAN_JEDI_MPIF90}")"

  log_info "Loaded MONAN-JEDI stack environment"
  log_info "  STACK_INSTANCE=${STACK_INSTANCE}"
  log_info "  MONAN_JEDI_RUN_ID=${MONAN_JEDI_RUN_ID}"
  log_info "  STACK_ROOT=${STACK_ROOT}"
  log_info "  STACK_SITE_SETUP=${STACK_SITE_SETUP}"
  log_info "  STACK_ENV_MODULE=${STACK_ENV_MODULE}"
  log_info "  SPACK=$(command -v spack 2>/dev/null || echo unavailable)"
  log_info "  CC=${CC}"
  log_info "  CXX=${CXX}"
  log_info "  FC=${FC}"
}

monan_jedi_record_environment_snapshot() {
  local output_file="$1"

  {
    echo "GeneratedAt=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "MONAN_JEDI_CONFIG=${MONAN_JEDI_CONFIG}"
    echo "PROJECT_ROOT=${PROJECT_ROOT}"
    echo "STACK_INSTANCE=${STACK_INSTANCE}"
    echo "STACK_ROOT=${STACK_ROOT}"
    echo "STACK_ENV_NAME=${STACK_ENV_NAME}"
    echo "STACK_SITE_SETUP=${STACK_SITE_SETUP}"
    echo "STACK_ENV_MODULE=${STACK_ENV_MODULE}"
    echo "MONAN_JEDI_RUN_ID=${MONAN_JEDI_RUN_ID}"
    echo "MONAN_JEDI_WORK_ROOT=${MONAN_JEDI_WORK_ROOT}"
    echo "MONAN_JEDI_LOG_ROOT=${MONAN_JEDI_LOG_ROOT}"
    echo "MONAN_JEDI_SOURCE_DIR=${MONAN_JEDI_SOURCE_DIR}"
    echo "MONAN_JEDI_BUILD_DIR=${MONAN_JEDI_BUILD_DIR}"
    echo "MONAN_JEDI_INSTALL_ROOT=${MONAN_JEDI_INSTALL_ROOT}"
    echo "MONAN_JEDI_INSTALL_BIN_DIR=${MONAN_JEDI_INSTALL_BIN_DIR}"
    echo
    echo "module list:"
    module list 2>&1 || true
    echo
    echo "MODULEPATH=${MODULEPATH:-}"
    echo
    echo "tool resolution:"
    command -v spack || true
    command -v ecbuild || true
    command -v cmake || true
    command -v make || true
    command -v ctest || true
    command -v python || true
    command -v git || true
    command -v git-lfs || true
    git lfs version 2>/dev/null || true
    echo
    echo "compiler variables:"
    echo "CC=${CC:-}"
    echo "CXX=${CXX:-}"
    echo "FC=${FC:-}"
    echo "F77=${F77:-}"
    echo "F90=${F90:-}"
    echo "MPICC=${MPICC:-}"
    echo "MPICXX=${MPICXX:-}"
    echo "MPIFC=${MPIFC:-}"
    echo "MPIF77=${MPIF77:-}"
    echo "MPIF90=${MPIF90:-}"
    echo
    echo "CMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH:-}"
  } | tee "${output_file}"
}
