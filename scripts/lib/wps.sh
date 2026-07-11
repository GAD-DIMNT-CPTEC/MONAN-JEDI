#!/usr/bin/env bash
# Build WPS/UNGRIB with the MONAN-JEDI stack and publish stable runtime paths.

_wps_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=wps_grib2.sh
source "${_wps_lib_dir}/wps_grib2.sh"

monan_jedi_load_wps_config() {
  local values
  [[ -n "${MONAN_JEDI_CONFIG:-}" && -f "${MONAN_JEDI_CONFIG}" ]] || {
    log_error "MONAN_JEDI_CONFIG is not available for WPS configuration."
    exit 1
  }

  values="$(python3 - "${MONAN_JEDI_CONFIG}" <<'PY'
import os
import shlex
import sys
import yaml

with open(sys.argv[1], encoding="utf-8") as stream:
    config = yaml.safe_load(stream) or {}
wps = config.get("wps", {})
if not isinstance(wps, dict):
    raise SystemExit("wps must be a YAML mapping")

mapping = {
    "MONAN_JEDI_WPS_ENABLED": ("enabled", "0"),
    "MONAN_JEDI_WPS_REPO": ("repo", "https://github.com/wrf-model/WPS.git"),
    "MONAN_JEDI_WPS_REF": ("ref", "335c76a111f84503e8b963abaf273ea8053645bb"),
    "MONAN_JEDI_WPS_VERSION": ("version", "4.6.0"),
    "MONAN_JEDI_WPS_SOURCE_DIR": ("source_dir", ""),
    "MONAN_JEDI_WPS_INSTALL_DIR": ("install_dir", ""),
    "MONAN_JEDI_WPS_NETCDF_COMPAT_DIR": ("netcdf_compat_dir", ""),
    "MONAN_JEDI_WPS_CONFIGURE_OPTION": ("configure_option", ""),
    "MONAN_JEDI_WPS_COMPILE_TARGET": ("compile_target", "ungrib"),
    "MONAN_JEDI_WPS_JASPER_ROOT": ("jasper_root", ""),
    "MONAN_JEDI_WPS_PNG_ROOT": ("png_root", ""),
    "MONAN_JEDI_WPS_ZLIB_ROOT": ("zlib_root", ""),
    "MONAN_JEDI_WPS_UNGRIB_NAME": ("ungrib_name", "ungrib.exe"),
    "MONAN_JEDI_WPS_LINK_GRIB_NAME": ("link_grib_name", "link_grib.csh"),
}
for env_name, (key, default) in mapping.items():
    value = wps.get(key, default)
    if value is None:
        value = default
    if isinstance(value, bool):
        value = "1" if value else "0"
    value = os.path.expandvars(str(value))
    value = os.environ.get(env_name, value)
    print(f"export {env_name}={shlex.quote(value)}")
PY
)" || exit 1

  # shellcheck disable=SC1090
  eval "${values}"
  export MONAN_JEDI_WPS_SOURCE_DIR="${MONAN_JEDI_WPS_SOURCE_DIR:-${MONAN_JEDI_WORK_ROOT}/wps/src}"
  export MONAN_JEDI_WPS_INSTALL_DIR="${MONAN_JEDI_WPS_INSTALL_DIR:-${MONAN_JEDI_INSTALL_ROOT}/wps/WPS-${MONAN_JEDI_WPS_VERSION}}"
  export MONAN_JEDI_WPS_NETCDF_COMPAT_DIR="${MONAN_JEDI_WPS_NETCDF_COMPAT_DIR:-${MONAN_JEDI_WORK_ROOT}/wps/netcdf-compat}"
}

monan_jedi_wps_enabled() {
  case "${MONAN_JEDI_WPS_ENABLED:-0}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
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
  [[ -f "${source}" ]] || { log_error "WPS publication source not found: ${source}"; exit 1; }
  install -D -m 755 "${source}" "${target}"
}

monan_jedi_write_wps_manifest() {
  local commit="$1"
  local manifest="${MONAN_JEDI_WPS_INSTALL_DIR}/build-manifest.json"
  python3 - "${manifest}" "${commit}" <<'PY'
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

path = Path(sys.argv[1])
record = {
    "schema_version": 2,
    "built_at": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
    "source_repo": os.environ["MONAN_JEDI_WPS_REPO"],
    "source_ref": os.environ["MONAN_JEDI_WPS_REF"],
    "source_commit": sys.argv[2],
    "version_label": os.environ["MONAN_JEDI_WPS_VERSION"],
    "configure_option": os.environ["MONAN_JEDI_WPS_CONFIGURE_OPTION"],
    "compile_target": os.environ["MONAN_JEDI_WPS_COMPILE_TARGET"],
    "netcdf_c_root": os.environ["MONAN_JEDI_WPS_NETCDF_C_ROOT"],
    "netcdf_fortran_root": os.environ["MONAN_JEDI_WPS_NETCDF_FORTRAN_ROOT"],
    "netcdf_compat_root": os.environ["MONAN_JEDI_WPS_NETCDF_COMPAT_DIR"],
    "jasper_root": os.environ["MONAN_JEDI_WPS_JASPER_RESOLVED_ROOT"],
    "png_root": os.environ["MONAN_JEDI_WPS_PNG_RESOLVED_ROOT"],
    "zlib_root": os.environ["MONAN_JEDI_WPS_ZLIB_RESOLVED_ROOT"],
    "jasper_patch": "jas_image_decode",
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
  monan_jedi_load_wps_config
  monan_jedi_wps_enabled || { log_error "WPS is disabled. Set wps.enabled: true."; exit 1; }
  [[ "${MONAN_JEDI_WPS_CONFIGURE_OPTION:-}" =~ ^[0-9]+$ ]] || {
    log_error "wps.configure_option must be the numeric serial GRIB2 menu choice from ./configure."
    exit 1
  }

  monan_jedi_load_stack
  require_cmd git install nc-config nf-config spack python3 find
  mkdir -p "${MONAN_JEDI_LOG_ROOT}" "${MONAN_JEDI_WPS_INSTALL_DIR}" "${MONAN_JEDI_INSTALL_BIN_DIR}"
  monan_jedi_prepare_wps_source

  cd "${MONAN_JEDI_WPS_SOURCE_DIR}"
  ./clean -a >/dev/null 2>&1 || true
  rm -f configure.wps configure.wps.original ungrib.exe ungrib/src/ungrib.exe
  monan_jedi_wps_patch_jasper
  monan_jedi_wps_prepare_grib2_environment
  local source_commit
  source_commit="$(git rev-parse HEAD)"

  log_info "Configuring WPS ref=${MONAN_JEDI_WPS_REF} commit=${source_commit}"
  log_info "NETCDF=${NETCDF}; NETCDFF=${NETCDFF}; JASPERINC=${JASPERINC}"
  printf '%s\n' "${MONAN_JEDI_WPS_CONFIGURE_OPTION}" \
    | ./configure --nowrf 2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/09_wps_configure.log"
  [[ -f configure.wps ]] || { log_error "WPS configure did not create configure.wps."; exit 1; }
  cp configure.wps configure.wps.original
  monan_jedi_wps_patch_configure
  grep -nE '^(SFC|SCC|SCC_NOMPI|DM_FC|DM_CC|CC|FC|LD|COMPRESSION_INC|COMPRESSION_LIBS|NETCDF)[[:space:]]*=' configure.wps \
    | tee "${MONAN_JEDI_LOG_ROOT}/09_wps_configure_values.log" || true

  ./compile "${MONAN_JEDI_WPS_COMPILE_TARGET}" \
    2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/09_wps_compile.log"
  [[ -x ungrib.exe ]] || { log_error "WPS did not create ungrib.exe."; exit 1; }

  local published_ungrib published_link published_vtable
  published_ungrib="${MONAN_JEDI_WPS_INSTALL_DIR}/ungrib.exe"
  published_link="${MONAN_JEDI_WPS_INSTALL_DIR}/link_grib.csh"
  published_vtable="${MONAN_JEDI_WPS_INSTALL_DIR}/ungrib/Variable_Tables/Vtable.GFS"
  monan_jedi_publish_wps_file ungrib.exe "${published_ungrib}"
  monan_jedi_publish_wps_file link_grib.csh "${published_link}"
  [[ -f ungrib/Variable_Tables/Vtable.GFS ]] || { log_error "WPS Vtable.GFS not found."; exit 1; }
  install -D -m 644 ungrib/Variable_Tables/Vtable.GFS "${published_vtable}"
  ln -sfn "${published_ungrib}" "${MONAN_JEDI_INSTALL_BIN_DIR}/${MONAN_JEDI_WPS_UNGRIB_NAME}"
  ln -sfn "${published_link}" "${MONAN_JEDI_INSTALL_BIN_DIR}/${MONAN_JEDI_WPS_LINK_GRIB_NAME}"

  if ldd "${published_ungrib}" 2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/09_wps_ungrib_ldd.log" | grep -q 'not found'; then
    log_error "Missing runtime library for ${published_ungrib}"
    exit 1
  fi
  monan_jedi_write_wps_manifest "${source_commit}"
  log_info "WPS published=${MONAN_JEDI_WPS_INSTALL_DIR}"
  log_info "ungrib=${MONAN_JEDI_INSTALL_BIN_DIR}/${MONAN_JEDI_WPS_UNGRIB_NAME}"
}
