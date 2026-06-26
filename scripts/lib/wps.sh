#!/usr/bin/env bash
# Build WPS/UNGRIB with the MONAN-JEDI stack and publish stable runtime paths.
#
# WPS uses its legacy in-source ./configure + ./compile workflow. The selected
# configure menu entry is therefore explicit in site YAML and recorded in a
# manifest; it must be reviewed whenever compilers or the stack change.

monan_jedi_wps_enabled() {
  case "${MONAN_JEDI_WPS_ENABLED:-0}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

monan_jedi_find_wps_jasper_root() {
  if [[ -n "${MONAN_JEDI_WPS_JASPER_ROOT:-}" ]]; then
    [[ -d "${MONAN_JEDI_WPS_JASPER_ROOT}" ]] || {
      log_error "Configured Jasper root not found: ${MONAN_JEDI_WPS_JASPER_ROOT}"
      exit 1
    }
    printf '%s\n' "${MONAN_JEDI_WPS_JASPER_ROOT}"
    return 0
  fi

  local root
  root="$(spack location -i jasper 2>/dev/null || true)"
  if [[ -n "${root}" && -d "${root}" ]]; then
    printf '%s\n' "${root}"
    return 0
  fi

  log_error "Could not locate Jasper. Set wps.jasper_root in the YAML configuration."
  exit 1
}

monan_jedi_prepare_wps_source() {
  require_cmd git
  mkdir -p "$(dirname "${MONAN_JEDI_WPS_SOURCE_DIR}")"

  if [[ ! -d "${MONAN_JEDI_WPS_SOURCE_DIR}/.git" ]]; then
    git clone "${MONAN_JEDI_WPS_REPO}" "${MONAN_JEDI_WPS_SOURCE_DIR}" \
      2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/09_wps_clone.log"
  fi

  cd "${MONAN_JEDI_WPS_SOURCE_DIR}"
  git fetch --tags origin 2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/09_wps_fetch.log"
  git checkout --detach "${MONAN_JEDI_WPS_REF}" \
    2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/09_wps_checkout.log"
  git reset --hard HEAD 2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/09_wps_reset.log"
  git clean -fdx 2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/09_wps_clean.log"
}

monan_jedi_publish_wps_file() {
  local source="$1"
  local target="$2"

  [[ -f "${source}" ]] || {
    log_error "WPS publication source not found: ${source}"
    exit 1
  }
  install -D -m 755 "${source}" "${target}"
}

monan_jedi_write_wps_manifest() {
  local commit="$1"
  local netcdf_root="$2"
  local jasper_root="$3"
  local manifest="${MONAN_JEDI_WPS_INSTALL_DIR}/build-manifest.json"

  python3 - "${manifest}" "${commit}" "${netcdf_root}" "${jasper_root}" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

path = Path(sys.argv[1])
record = {
    "schema_version": 1,
    "built_at": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
    "source_repo": __import__("os").environ["MONAN_JEDI_WPS_REPO"],
    "source_ref": __import__("os").environ["MONAN_JEDI_WPS_REF"],
    "source_commit": sys.argv[2],
    "version_label": __import__("os").environ["MONAN_JEDI_WPS_VERSION"],
    "configure_option": __import__("os").environ["MONAN_JEDI_WPS_CONFIGURE_OPTION"],
    "compile_target": __import__("os").environ["MONAN_JEDI_WPS_COMPILE_TARGET"],
    "netcdf_root": sys.argv[3],
    "jasper_root": sys.argv[4],
    "published": {
        "ungrib": str(path.parent / "ungrib.exe"),
        "link_grib": str(path.parent / "link_grib.csh"),
        "vtable_gfs": str(path.parent / "ungrib" / "Variable_Tables" / "Vtable.GFS"),
    },
}
path.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
}

monan_jedi_build_wps() {
  monan_jedi_wps_enabled || {
    log_error "WPS is disabled in ${MONAN_JEDI_CONFIG}. Set wps.enabled: true."
    exit 1
  }

  [[ -n "${MONAN_JEDI_WPS_CONFIGURE_OPTION:-}" ]] || {
    log_error "wps.configure_option is required; it is the serial GRIB2 menu choice from ./configure."
    exit 1
  }

  monan_jedi_load_stack
  require_cmd git
  require_cmd install
  require_cmd nc-config
  require_cmd spack

  mkdir -p "${MONAN_JEDI_LOG_ROOT}" "${MONAN_JEDI_WPS_INSTALL_DIR}" "${MONAN_JEDI_INSTALL_BIN_DIR}"
  monan_jedi_prepare_wps_source

  local netcdf_root jasper_root source_commit
  netcdf_root="$(nc-config --prefix)"
  jasper_root="$(monan_jedi_find_wps_jasper_root)"
  source_commit="$(git -C "${MONAN_JEDI_WPS_SOURCE_DIR}" rev-parse HEAD)"

  export NETCDF="${netcdf_root}"
  export JASPERINC="${jasper_root}/include"
  export JASPERLIB="${jasper_root}/lib"

  log_info "Configuring WPS"
  log_info "  source=${MONAN_JEDI_WPS_SOURCE_DIR}"
  log_info "  ref=${MONAN_JEDI_WPS_REF} (${source_commit})"
  log_info "  configure_option=${MONAN_JEDI_WPS_CONFIGURE_OPTION}"
  log_info "  NETCDF=${NETCDF}"
  log_info "  JASPERINC=${JASPERINC}"
  log_info "  JASPERLIB=${JASPERLIB}"

  cd "${MONAN_JEDI_WPS_SOURCE_DIR}"
  printf '%s\n' "${MONAN_JEDI_WPS_CONFIGURE_OPTION}" \
    | ./configure 2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/09_wps_configure.log"
  [[ -f configure.wps ]] || {
    log_error "WPS configure did not create configure.wps. Review 09_wps_configure.log."
    exit 1
  }

  ./compile "${MONAN_JEDI_WPS_COMPILE_TARGET}" \
    2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/09_wps_compile.log"

  local published_ungrib published_link published_vtable
  published_ungrib="${MONAN_JEDI_WPS_INSTALL_DIR}/ungrib.exe"
  published_link="${MONAN_JEDI_WPS_INSTALL_DIR}/link_grib.csh"
  published_vtable="${MONAN_JEDI_WPS_INSTALL_DIR}/ungrib/Variable_Tables/Vtable.GFS"

  monan_jedi_publish_wps_file "${MONAN_JEDI_WPS_SOURCE_DIR}/ungrib.exe" "${published_ungrib}"
  monan_jedi_publish_wps_file "${MONAN_JEDI_WPS_SOURCE_DIR}/link_grib.csh" "${published_link}"
  [[ -f "${MONAN_JEDI_WPS_SOURCE_DIR}/ungrib/Variable_Tables/Vtable.GFS" ]] || {
    log_error "WPS Vtable.GFS not found in source checkout."
    exit 1
  }
  install -D -m 644 "${MONAN_JEDI_WPS_SOURCE_DIR}/ungrib/Variable_Tables/Vtable.GFS" "${published_vtable}"

  ln -sfn "${published_ungrib}" "${MONAN_JEDI_INSTALL_BIN_DIR}/${MONAN_JEDI_WPS_UNGRIB_NAME}"
  ln -sfn "${published_link}" "${MONAN_JEDI_INSTALL_BIN_DIR}/${MONAN_JEDI_WPS_LINK_GRIB_NAME}"

  if ldd "${published_ungrib}" 2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/09_wps_ungrib_ldd.log" | grep -q 'not found'; then
    log_error "Missing runtime library for ${published_ungrib}"
    exit 1
  fi

  monan_jedi_write_wps_manifest "${source_commit}" "${netcdf_root}" "${jasper_root}"
  log_info "WPS published=${MONAN_JEDI_WPS_INSTALL_DIR}"
  log_info "ungrib=${MONAN_JEDI_INSTALL_BIN_DIR}/${MONAN_JEDI_WPS_UNGRIB_NAME}"
}
