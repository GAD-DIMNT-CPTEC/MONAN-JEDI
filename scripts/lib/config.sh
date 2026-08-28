#!/usr/bin/env bash
# YAML configuration loader and derived MONAN-JEDI paths.

load_monan_jedi_config() {
  local default_config="config/jaci.yaml"
  local repo_root config_exports

  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  export MONAN_JEDI_CONFIG="${MONAN_JEDI_CONFIG:-${default_config}}"

  if [[ ! -f "${MONAN_JEDI_CONFIG}" ]]; then
    log_error "Configuration file not found: ${MONAN_JEDI_CONFIG}"
    exit 1
  fi

  require_cmd python3
  if ! config_exports="$(python3 "$(dirname "${BASH_SOURCE[0]}")/read_config.py" "${MONAN_JEDI_CONFIG}")"; then
    log_error "Failed to load configuration: ${MONAN_JEDI_CONFIG}"
    exit 1
  fi

  # The reader emits only shell-quoted export statements. Do not evaluate
  # partial or empty output when the reader fails.
  if ! eval "${config_exports}"; then
    log_error "Failed to apply configuration exports: ${MONAN_JEDI_CONFIG}"
    exit 1
  fi

  export PROJECT_ROOT="${PROJECT_ROOT:-/p/projetos/monan_das/${USER}}"
  export STACK_OWNER="${STACK_OWNER:-${USER}}"

  [[ -n "${STACK_INSTANCE:-}" ]] || {
    log_error "STACK_INSTANCE is empty. Set stack.instance in ${MONAN_JEDI_CONFIG}."
    exit 1
  }
  [[ -n "${STACK_ENV_NAME:-}" ]] || {
    log_error "STACK_ENV_NAME is empty. Set stack.env_name in ${MONAN_JEDI_CONFIG}."
    exit 1
  }
  [[ -n "${MONAN_JEDI_RUN_ID:-}" ]] || {
    log_error "MONAN_JEDI_RUN_ID is empty. Set build.id in ${MONAN_JEDI_CONFIG}."
    exit 1
  }

  export STACK_WORK_ROOT="${STACK_WORK_ROOT:-/p/projetos/monan_das/${STACK_OWNER}/work/${STACK_INSTANCE}}"
  export STACK_ROOT="${STACK_ROOT:-${STACK_WORK_ROOT}/spack-stack}"
  export STACK_MODULE_ROOT="${STACK_MODULE_ROOT:-${STACK_ROOT}/envs/${STACK_ENV_NAME}/modules}"

  # Files below work/ are private, rebuildable products. Files below build/ are
  # the public runtime installation consumed by mpaswf, MPAS-BMatrix and other
  # workflows. Consumers must never depend on MONAN_JEDI_WORK_ROOT or source
  # checkouts created by ecbuild_bundle.
  export MONAN_JEDI_WORK_ROOT="${MONAN_JEDI_WORK_ROOT:-${PROJECT_ROOT}/work/${MONAN_JEDI_RUN_ID}}"
  export MONAN_JEDI_LOG_ROOT="${MONAN_JEDI_LOG_ROOT:-${PROJECT_ROOT}/logs/${MONAN_JEDI_RUN_ID}}"
  export MONAN_JEDI_SOURCE_DIR="${MONAN_JEDI_SOURCE_DIR:-${repo_root}}"
  export MONAN_JEDI_BUILD_DIR="${MONAN_JEDI_BUILD_DIR:-${MONAN_JEDI_WORK_ROOT}/build}"
  export MONAN_JEDI_INSTALL_ROOT="${MONAN_JEDI_INSTALL_ROOT:-${PROJECT_ROOT}/build/${MONAN_JEDI_RUN_ID}}"
  export MONAN_JEDI_INSTALL_BIN_DIR="${MONAN_JEDI_INSTALL_BIN_DIR:-${MONAN_JEDI_INSTALL_ROOT}/bin}"

  export MONAN_JEDI_DATA_ROOT="${MONAN_JEDI_DATA_ROOT:-${MONAN_JEDI_WORK_ROOT}/cache/data}"
  export MONAN_JEDI_DATA_LOCAL_ROOT="${MONAN_JEDI_DATA_LOCAL_ROOT:-}"
  export MONAN_JEDI_DATA_DOWNLOAD_MISSING="${MONAN_JEDI_DATA_DOWNLOAD_MISSING:-1}"
  export MONAN_JEDI_CRTM_COEFFS_URL="${MONAN_JEDI_CRTM_COEFFS_URL:-https://bin.ssec.wisc.edu/pub/s4/CRTM/fix_REL-3.1.2.0.tgz}"
  export MONAN_JEDI_CRTM_COEFFS_TGZ="${MONAN_JEDI_CRTM_COEFFS_TGZ:-${MONAN_JEDI_DATA_ROOT}/crtm/fix_REL-3.1.2.0.tgz}"

  export MONAN_JEDI_OBS2IODA_SOURCE_DIR="${MONAN_JEDI_OBS2IODA_SOURCE_DIR:-${MONAN_JEDI_WORK_ROOT}/obs2ioda/src}"
  export MONAN_JEDI_OBS2IODA_BUILD_DIR="${MONAN_JEDI_OBS2IODA_BUILD_DIR:-${MONAN_JEDI_WORK_ROOT}/obs2ioda/build}"
  export MONAN_JEDI_OBS2IODA_INSTALL_DIR="${MONAN_JEDI_OBS2IODA_INSTALL_DIR:-${MONAN_JEDI_INSTALL_ROOT}}"
  export MONAN_JEDI_OBS2IODA_EXECUTABLE_NAME="${MONAN_JEDI_OBS2IODA_EXECUTABLE_NAME:-obs2ioda_v3}"

  export MONAN_JEDI_WPS_SOURCE_DIR="${MONAN_JEDI_WPS_SOURCE_DIR:-${MONAN_JEDI_WORK_ROOT}/wps/src}"
  export MONAN_JEDI_WPS_BUILD_DIR="${MONAN_JEDI_WPS_BUILD_DIR:-${MONAN_JEDI_WORK_ROOT}/wps/build}"
  # Versioned WPS releases are implementation details. Stable public entry
  # points are always install/bin and install/share/wps.
  export MONAN_JEDI_WPS_RELEASES_DIR="${MONAN_JEDI_WPS_RELEASES_DIR:-${MONAN_JEDI_INSTALL_ROOT}/libexec/monan-jedi/wps}"
  export MONAN_JEDI_WPS_INSTALL_DIR="${MONAN_JEDI_WPS_INSTALL_DIR:-${MONAN_JEDI_WPS_RELEASES_DIR}/WPS-${MONAN_JEDI_WPS_VERSION}}"
  export MONAN_JEDI_WPS_PATCH_DIR="${MONAN_JEDI_WPS_PATCH_DIR:-${MONAN_JEDI_SOURCE_DIR}/patches/wps}"

  mkdir -p \
    "${MONAN_JEDI_WORK_ROOT}" \
    "${MONAN_JEDI_LOG_ROOT}" \
    "${MONAN_JEDI_BUILD_DIR}" \
    "${MONAN_JEDI_INSTALL_BIN_DIR}" \
    "${MONAN_JEDI_DATA_ROOT}" \
    "${MONAN_JEDI_WPS_RELEASES_DIR}" \
    "$(dirname "${MONAN_JEDI_CRTM_COEFFS_TGZ}")"
}
