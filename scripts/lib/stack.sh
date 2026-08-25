#!/usr/bin/env bash
# Stack environment handling.
#
# Purpose:
#   Detect, load and validate the exact JACI/spack-stack environment selected by
#   the MONAN-JEDI configuration. Every workflow command may be invoked in a new
#   login session, so no command is allowed to assume that a previous command
#   left modules, compiler wrappers or stack tools active in the caller shell.

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

monan_jedi_expose_spack_cli() {
  local spack_bin="${STACK_ROOT}/spack/bin"

  if [[ -x "${spack_bin}/spack" ]]; then
    case ":${PATH}:" in
      *":${spack_bin}:"*) ;;
      *) export PATH="${spack_bin}:${PATH}" ;;
    esac
  fi
}

monan_jedi_module_is_loaded() {
  local module_name="$1"
  local loaded_modules=""

  type module >/dev/null 2>&1 || return 1
  loaded_modules="$(module list 2>&1 || true)"
  grep -Fq -- "${module_name}" <<< "${loaded_modules}"
}

monan_jedi_command_in_cmake_prefix() {
  local command_name="$1"
  local executable=""
  local executable_real=""
  local prefix=""
  local prefix_real=""

  [[ -n "${CMAKE_PREFIX_PATH:-}" ]] || return 1
  executable="$(command -v "${command_name}" 2>/dev/null || true)"
  [[ -n "${executable}" ]] || return 1
  executable_real="$(readlink -f "${executable}" 2>/dev/null || printf '%s' "${executable}")"

  IFS=':' read -r -a _monan_jedi_prefix_entries <<< "${CMAKE_PREFIX_PATH}"
  for prefix in "${_monan_jedi_prefix_entries[@]}"; do
    [[ -n "${prefix}" ]] || continue
    prefix="${prefix%/.}"
    prefix_real="$(readlink -f "${prefix}" 2>/dev/null || printf '%s' "${prefix}")"
    case "${executable_real}" in
      "${prefix_real}"/*) return 0 ;;
    esac
  done

  return 1
}

monan_jedi_compiler_binding_is_valid() {
  local variable_name="$1"
  local configured_command="$2"
  local current_value=""
  local expected_value=""

  current_value="${!variable_name:-}"
  expected_value="$(command -v "${configured_command}" 2>/dev/null || true)"

  [[ -n "${current_value}" && -n "${expected_value}" && "${current_value}" == "${expected_value}" ]]
}

monan_jedi_stack_environment_ready() {
  local command_name=""

  [[ -d "${STACK_ROOT}" ]] || return 1
  [[ -d "${STACK_MODULE_ROOT}" ]] || return 1
  monan_jedi_module_is_loaded "${STACK_ENV_MODULE}" || return 1

  # The JEDI module must have populated the package prefix used by downstream
  # CMake discovery. This catches partially loaded or stale module sessions.
  [[ -n "${CMAKE_PREFIX_PATH:-}" ]] || return 1
  [[ -n "${jedi_cmake_ROOT:-}" && -d "${jedi_cmake_ROOT}" ]] || return 1

  # These tools must resolve from one of the package prefixes exported by the
  # configured stack. A system/Conda command shadowing the stack is treated as
  # an inconsistent environment and triggers a clean reload.
  for command_name in ecbuild cmake ctest git python; do
    monan_jedi_command_in_cmake_prefix "${command_name}" || return 1
  done

  # Compiler variables are part of the MONAN-JEDI execution contract. A user
  # may have the module loaded manually but still have stale CC/CXX/FC values.
  monan_jedi_compiler_binding_is_valid CC "${MONAN_JEDI_CC}" || return 1
  monan_jedi_compiler_binding_is_valid CXX "${MONAN_JEDI_CXX}" || return 1
  monan_jedi_compiler_binding_is_valid FC "${MONAN_JEDI_FC}" || return 1
  monan_jedi_compiler_binding_is_valid F77 "${MONAN_JEDI_F77}" || return 1
  monan_jedi_compiler_binding_is_valid F90 "${MONAN_JEDI_F90}" || return 1
  monan_jedi_compiler_binding_is_valid MPICC "${MONAN_JEDI_MPICC}" || return 1
  monan_jedi_compiler_binding_is_valid MPICXX "${MONAN_JEDI_MPICXX}" || return 1
  monan_jedi_compiler_binding_is_valid MPIFC "${MONAN_JEDI_MPIFC}" || return 1
  monan_jedi_compiler_binding_is_valid MPIF77 "${MONAN_JEDI_MPIF77}" || return 1
  monan_jedi_compiler_binding_is_valid MPIF90 "${MONAN_JEDI_MPIF90}" || return 1

  return 0
}

monan_jedi_report_stack_environment() {
  local state="$1"

  log_info "MONAN-JEDI stack environment ${state}"
  log_info "  STACK_INSTANCE=${STACK_INSTANCE}"
  log_info "  MONAN_JEDI_RUN_ID=${MONAN_JEDI_RUN_ID}"
  log_info "  STACK_ROOT=${STACK_ROOT}"
  log_info "  STACK_SITE_SETUP=${STACK_SITE_SETUP}"
  log_info "  STACK_ENV_MODULE=${STACK_ENV_MODULE}"
  log_info "  SPACK=$(command -v spack 2>/dev/null || echo unavailable)"
  log_info "  ECBUILD=$(command -v ecbuild 2>/dev/null || echo unavailable)"
  log_info "  CMAKE=$(command -v cmake 2>/dev/null || echo unavailable)"
  log_info "  CTEST=$(command -v ctest 2>/dev/null || echo unavailable)"
  log_info "  PYTHON=$(command -v python 2>/dev/null || echo unavailable)"
  log_info "  GIT=$(command -v git 2>/dev/null || echo unavailable)"
  log_info "  CC=${CC:-unavailable}"
  log_info "  CXX=${CXX:-unavailable}"
  log_info "  FC=${FC:-unavailable}"
}

monan_jedi_load_stack() {
  local setup_script=""
  local original_dir="${PWD}"
  local setup_status=0

  # Individual workflow commands are frequently executed in fresh login
  # sessions. Reuse a fully valid inherited environment, but never assume that
  # a loaded module alone means all tools/compiler variables are correct.
  if monan_jedi_stack_environment_ready; then
    monan_jedi_expose_spack_cli
    monan_jedi_report_stack_environment "already loaded and valid; reusing"
    return 0
  fi

  log_info "MONAN-JEDI stack environment is missing or incomplete; loading configured stack"

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

  if ! type module >/dev/null 2>&1; then
    log_error "Environment Modules command is unavailable; cannot load ${STACK_ENV_MODULE}."
    exit 1
  fi

  monan_jedi_reset_modules

  # The site setup script expects to run from STACK_ROOT. Restore the caller's
  # directory immediately afterwards so commands such as test-pbs keep the
  # MONAN-JEDI checkout as their working directory.
  cd "${STACK_ROOT}" || {
    log_error "Failed to enter stack root: ${STACK_ROOT}"
    exit 1
  }
  if source "${setup_script}"; then
    setup_status=0
  else
    setup_status=$?
  fi
  cd "${original_dir}" || {
    log_error "Failed to restore working directory after stack setup: ${original_dir}"
    exit 1
  }
  if [[ "${setup_status}" -ne 0 ]]; then
    log_error "STACK site setup failed with status ${setup_status}: ${setup_script}"
    exit "${setup_status}"
  fi

  module use "${STACK_MODULE_ROOT}"
  module load "${STACK_ENV_MODULE}"

  # The generated environment module provides compilers and libraries, but it
  # does not necessarily place the Spack CLI itself in PATH. Auxiliary builds
  # use `spack location -i` only for dependency discovery, so expose the CLI
  # shipped with this exact stack installation without sourcing stack setup.sh.
  monan_jedi_expose_spack_cli

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

  if ! monan_jedi_stack_environment_ready; then
    log_error "Configured MONAN-JEDI stack was loaded, but the resulting environment is incomplete or inconsistent."
    log_error "Expected module: ${STACK_ENV_MODULE}"
    log_error "Run 'bash scripts/monan-jedi.sh load --config ${MONAN_JEDI_CONFIG:-config/jaci.yaml}' for diagnostics."
    exit 1
  fi

  monan_jedi_report_stack_environment "loaded and validated"
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
    echo "STACK_ENVIRONMENT_READY=$(monan_jedi_stack_environment_ready && echo yes || echo no)"
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
