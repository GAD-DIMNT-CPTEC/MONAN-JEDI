#!/usr/bin/env bash
# GRIB2 dependency and source-compatibility helpers for the MONAN-JEDI WPS build.

monan_jedi_wps_root_or_spack() {
  local variable="$1"
  local package="$2"
  local label="$3"
  local configured="${!variable:-}"
  local root

  if [[ -n "${configured}" ]]; then
    [[ -d "${configured}" ]] || {
      log_error "Configured ${label} root not found: ${configured}"
      exit 1
    }
    printf '%s\n' "${configured}"
    return 0
  fi

  root="$(spack location -i "${package}" 2>/dev/null || true)"
  if [[ -n "${root}" && -d "${root}" ]]; then
    printf '%s\n' "${root}"
    return 0
  fi

  log_error "Could not locate ${label}; set ${variable} explicitly."
  exit 1
}

monan_jedi_wps_library_dir() {
  local root="$1"
  local pattern="$2"
  local directory
  for directory in "${root}/lib" "${root}/lib64"; do
    [[ -d "${directory}" ]] || continue
    if compgen -G "${directory}/${pattern}" >/dev/null; then
      printf '%s\n' "${directory}"
      return 0
    fi
  done
  log_error "Library ${pattern} not found below ${root}."
  exit 1
}

monan_jedi_wps_link_entries() {
  local source="$1"
  local destination="$2"
  shift 2
  local pattern file
  [[ -d "${source}" ]] || return 0
  for pattern in "$@"; do
    while IFS= read -r -d '' file; do
      ln -sfn "${file}" "${destination}/$(basename "${file}")"
    done < <(find "${source}" -maxdepth 1 \( -type f -o -type l \) -name "${pattern}" -print0)
  done
}

monan_jedi_wps_prepare_netcdf_compat() {
  local netcdf_c="$1"
  local netcdf_fortran="$2"
  local directory file

  export MONAN_JEDI_WPS_NETCDF_COMPAT_DIR="${MONAN_JEDI_WPS_NETCDF_COMPAT_DIR:-${MONAN_JEDI_WORK_ROOT}/wps/netcdf-compat}"
  mkdir -p "${MONAN_JEDI_WPS_NETCDF_COMPAT_DIR}/include" "${MONAN_JEDI_WPS_NETCDF_COMPAT_DIR}/lib"
  find "${MONAN_JEDI_WPS_NETCDF_COMPAT_DIR}/include" -maxdepth 1 -type l -delete
  find "${MONAN_JEDI_WPS_NETCDF_COMPAT_DIR}/lib" -maxdepth 1 -type l -delete

  for directory in "${netcdf_c}/include" "${netcdf_fortran}/include"; do
    [[ -d "${directory}" ]] || continue
    while IFS= read -r -d '' file; do
      ln -sfn "${file}" "${MONAN_JEDI_WPS_NETCDF_COMPAT_DIR}/include/$(basename "${file}")"
    done < <(find "${directory}" -maxdepth 1 \( -type f -o -type l \) -print0)
  done

  for directory in "${netcdf_c}/lib" "${netcdf_c}/lib64" "${netcdf_fortran}/lib" "${netcdf_fortran}/lib64"; do
    monan_jedi_wps_link_entries "${directory}" "${MONAN_JEDI_WPS_NETCDF_COMPAT_DIR}/lib" \
      'libnetcdf*' 'libhdf5*' 'libcurl*' 'libsz*' 'libz*'
  done
}

monan_jedi_wps_patch_jasper() {
  local target="${MONAN_JEDI_WPS_SOURCE_DIR}/ungrib/src/ngl/g2/dec_jpeg2000.c"
  local state
  [[ -f "${target}" ]] || { log_error "WPS JasPer source not found: ${target}"; exit 1; }

  state="$(python3 - "${target}" <<'PY'
import re
import sys
from pathlib import Path
text = Path(sys.argv[1]).read_text(encoding="utf-8")
old = re.compile(r"image\s*=\s*jpc_decode\s*\(\s*jpcstream\s*,\s*opts\s*\)\s*;")
new = re.compile(r"image\s*=\s*jas_image_decode\s*\(\s*jpcstream\s*,\s*jas_image_strtofmt\s*\(\s*\"jpc\"\s*\)\s*,\s*opts\s*\)\s*;")
if len(old.findall(text)) == 1 and not new.findall(text):
    print("patch")
elif not old.findall(text) and len(new.findall(text)) == 1:
    print("done")
else:
    raise SystemExit("Unexpected dec_jpeg2000.c state")
PY
)" || exit 1

  if [[ "${state}" == "patch" ]]; then
    python3 - "${target}" <<'PY'
import re
import sys
from pathlib import Path
path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
updated, count = re.subn(
    r"image\s*=\s*jpc_decode\s*\(\s*jpcstream\s*,\s*opts\s*\)\s*;",
    'image=jas_image_decode(jpcstream, jas_image_strtofmt("jpc"), opts);',
    text,
    count=1,
)
if count != 1:
    raise SystemExit("Could not apply WPS JasPer patch")
path.write_text(updated, encoding="utf-8")
PY
    log_info "Applied WPS JasPer compatibility patch."
  fi
}

monan_jedi_wps_patch_configure() {
  python3 - <<'PY'
import os
import re
from pathlib import Path
path = Path("configure.wps")
text = path.read_text(encoding="utf-8")
def assign(name, value, append=True):
    global text
    pattern = rf"^{re.escape(name)}\s*=.*$"
    replacement = f"{name:<16}=       {value}"
    if re.search(pattern, text, flags=re.MULTILINE):
        text = re.sub(pattern, replacement, text, flags=re.MULTILINE)
    elif append:
        text += f"\n{replacement}\n"
for name in ("SFC", "DM_FC", "FC", "LD"):
    assign(name, os.environ["MONAN_JEDI_FC"], append=False)
for name in ("SCC", "SCC_NOMPI", "DM_CC", "CC"):
    assign(name, os.environ["MONAN_JEDI_CC"], append=False)
assign("COMPRESSION_INC", " ".join(f"-I{os.environ[key]}" for key in ("JASPERINC", "PNG_INC", "ZLIB_INC")))
assign("COMPRESSION_LIBS", " ".join((
    f"-L{os.environ['JASPERLIB']}", "-ljasper",
    f"-L{os.environ['PNG_LIB']}", "-lpng",
    f"-L{os.environ['ZLIB_LIB']}", "-lz",
)))
path.write_text(text, encoding="utf-8")
PY
}

monan_jedi_wps_prepare_grib2_environment() {
  local netcdf_c netcdf_fortran jasper_root png_root zlib_root
  netcdf_c="$(nc-config --prefix)"
  netcdf_fortran="$(nf-config --prefix)"
  [[ -d "${netcdf_c}" && -d "${netcdf_fortran}" ]] || {
    log_error "nc-config or nf-config returned an invalid prefix."
    exit 1
  }

  jasper_root="$(monan_jedi_wps_root_or_spack MONAN_JEDI_WPS_JASPER_ROOT jasper JasPer)"
  png_root="$(monan_jedi_wps_root_or_spack MONAN_JEDI_WPS_PNG_ROOT libpng libpng)"
  zlib_root="$(monan_jedi_wps_root_or_spack MONAN_JEDI_WPS_ZLIB_ROOT zlib zlib)"

  monan_jedi_wps_prepare_netcdf_compat "${netcdf_c}" "${netcdf_fortran}"
  export NETCDF="${MONAN_JEDI_WPS_NETCDF_COMPAT_DIR}"
  export NETCDFF="${netcdf_fortran}"
  export JASPERINC="${jasper_root}/include"
  export JASPERLIB="$(monan_jedi_wps_library_dir "${jasper_root}" 'libjasper.so*')"
  export PNG_INC="${png_root}/include"
  export PNG_LIB="$(monan_jedi_wps_library_dir "${png_root}" 'libpng*.so*')"
  export ZLIB_INC="${zlib_root}/include"
  export ZLIB_LIB="$(monan_jedi_wps_library_dir "${zlib_root}" 'libz.so*')"

  for directory in "${JASPERINC}" "${JASPERLIB}" "${PNG_INC}" "${PNG_LIB}" "${ZLIB_INC}" "${ZLIB_LIB}"; do
    [[ -d "${directory}" ]] || { log_error "Missing GRIB2 directory: ${directory}"; exit 1; }
  done

  export MONAN_JEDI_WPS_NETCDF_C_ROOT="${netcdf_c}"
  export MONAN_JEDI_WPS_NETCDF_FORTRAN_ROOT="${netcdf_fortran}"
  export MONAN_JEDI_WPS_JASPER_RESOLVED_ROOT="${jasper_root}"
  export MONAN_JEDI_WPS_PNG_RESOLVED_ROOT="${png_root}"
  export MONAN_JEDI_WPS_ZLIB_RESOLVED_ROOT="${zlib_root}"
}
