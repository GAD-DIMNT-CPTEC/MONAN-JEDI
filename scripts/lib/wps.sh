#!/usr/bin/env bash
# Build, validate and atomically publish WPS/UNGRIB with the MONAN-JEDI stack.

_wps_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=wps_dependencies.sh
source "${_wps_lib_dir}/wps_dependencies.sh"

monan_jedi_wps_enabled() {
  case "${MONAN_JEDI_WPS_ENABLED:-0}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

monan_jedi_validate_wps_config() {
  [[ -n "${MONAN_JEDI_WPS_REPO:-}" ]] || { log_error "wps.repo is empty."; exit 1; }
  [[ -n "${MONAN_JEDI_WPS_REF:-}" ]] || { log_error "wps.ref is empty."; exit 1; }
  [[ -n "${MONAN_JEDI_WPS_VERSION:-}" ]] || { log_error "wps.version is empty."; exit 1; }

  case "${MONAN_JEDI_WPS_BUILD_TYPE}" in
    Release|Debug|RelWithDebInfo|MinSizeRel) ;;
    *)
      log_error "Unsupported wps.build_type: ${MONAN_JEDI_WPS_BUILD_TYPE}"
      exit 1
      ;;
  esac

  [[ "${MONAN_JEDI_WPS_DEFAULT_VTABLE}" =~ ^[A-Za-z0-9._-]+$ ]] || {
    log_error "wps.default_vtable must be a file name, not a path: ${MONAN_JEDI_WPS_DEFAULT_VTABLE}"
    exit 1
  }
}

monan_jedi_prepare_wps_source() {
  mkdir -p "$(dirname "${MONAN_JEDI_WPS_SOURCE_DIR}")" "${MONAN_JEDI_LOG_ROOT}"

  if [[ -e "${MONAN_JEDI_WPS_SOURCE_DIR}" && ! -d "${MONAN_JEDI_WPS_SOURCE_DIR}/.git" ]]; then
    log_error "WPS source path exists but is not a Git checkout: ${MONAN_JEDI_WPS_SOURCE_DIR}"
    exit 1
  fi

  if [[ ! -d "${MONAN_JEDI_WPS_SOURCE_DIR}/.git" ]]; then
    git clone "${MONAN_JEDI_WPS_REPO}" "${MONAN_JEDI_WPS_SOURCE_DIR}" \
      2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/09_wps_clone.log"
  fi

  git -C "${MONAN_JEDI_WPS_SOURCE_DIR}" remote set-url origin "${MONAN_JEDI_WPS_REPO}"
  git -C "${MONAN_JEDI_WPS_SOURCE_DIR}" fetch --tags --prune origin \
    2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/09_wps_fetch.log"
  git -C "${MONAN_JEDI_WPS_SOURCE_DIR}" checkout --detach "${MONAN_JEDI_WPS_REF}" \
    2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/09_wps_checkout.log"
  git -C "${MONAN_JEDI_WPS_SOURCE_DIR}" reset --hard HEAD \
    2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/09_wps_reset.log"
  git -C "${MONAN_JEDI_WPS_SOURCE_DIR}" clean -fdx \
    2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/09_wps_clean.log"
}

monan_jedi_wps_find_ungrib() {
  local root="$1"
  local candidate
  for candidate in "${root}/bin/ungrib.exe" "${root}/bin/ungrib"; do
    if [[ -x "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  return 1
}

monan_jedi_wps_prepare_runtime_tree() {
  local stage_dir="$1"
  local ungrib

  ungrib="$(monan_jedi_wps_find_ungrib "${stage_dir}")" || {
    log_error "WPS install did not create ungrib or ungrib.exe below ${stage_dir}/bin."
    exit 1
  }

  if [[ "${ungrib}" != "${stage_dir}/bin/ungrib.exe" ]]; then
    ln -sfn "$(basename "${ungrib}")" "${stage_dir}/bin/ungrib.exe"
  fi

  # The upstream CMake install creates link_grib.csh as a source-tree symlink.
  # Replace it with a regular file so the published release is self-contained.
  install -D -m 755 "${MONAN_JEDI_WPS_SOURCE_DIR}/link_grib.csh" "${stage_dir}/bin/link_grib.csh"

  [[ -d "${MONAN_JEDI_WPS_SOURCE_DIR}/ungrib/Variable_Tables" ]] || {
    log_error "WPS Variable_Tables directory not found in the source checkout."
    exit 1
  }
  mkdir -p "${stage_dir}/share/wps"
  cp -a "${MONAN_JEDI_WPS_SOURCE_DIR}/ungrib/Variable_Tables" "${stage_dir}/share/wps/"
}

monan_jedi_validate_wps_tree() {
  local root="$1"
  local log_file="${2:-${MONAN_JEDI_LOG_ROOT}/09_wps_validate.log}"
  local ungrib="${root}/bin/ungrib.exe"
  local link_grib="${root}/bin/link_grib.csh"
  local vtable="${root}/share/wps/Variable_Tables/${MONAN_JEDI_WPS_DEFAULT_VTABLE}"

  {
    echo "root=${root}"
    echo "ungrib=${ungrib}"
    echo "link_grib=${link_grib}"
    echo "vtable=${vtable}"

    [[ -x "${ungrib}" ]] || { echo "Missing executable: ${ungrib}"; exit 1; }
    [[ -x "${link_grib}" ]] || { echo "Missing helper: ${link_grib}"; exit 1; }
    [[ -f "${vtable}" ]] || { echo "Missing default Vtable: ${vtable}"; exit 1; }

    csh -n "${link_grib}"
    if ldd "${ungrib}" | tee /dev/stderr | grep -q 'not found'; then
      echo "A runtime library is missing for ${ungrib}."
      exit 1
    fi
  } 2>&1 | tee "${log_file}"
}

monan_jedi_write_wps_manifest() {
  local release_root="$1"
  local source_commit="$2"
  local manifest="${release_root}/build-manifest.json"

  python3 - "${manifest}" "${source_commit}" <<'PY'
import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

manifest = Path(sys.argv[1])
patch_dir = Path(os.environ["MONAN_JEDI_WPS_PATCH_DIR"])
patches = []
for path in sorted(patch_dir.glob("*.patch")):
    patches.append({
        "name": path.name,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    })

record = {
    "schema_version": 3,
    "built_at": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
    "build_system": "cmake",
    "source": {
        "repository": os.environ["MONAN_JEDI_WPS_REPO"],
        "requested_ref": os.environ["MONAN_JEDI_WPS_REF"],
        "commit": sys.argv[2],
        "version_label": os.environ["MONAN_JEDI_WPS_VERSION"],
        "patches": patches,
    },
    "dependencies": {
        "jasper_root": os.environ["MONAN_JEDI_WPS_JASPER_RESOLVED_ROOT"],
        "png_root": os.environ["MONAN_JEDI_WPS_PNG_RESOLVED_ROOT"],
        "zlib_root": os.environ["MONAN_JEDI_WPS_ZLIB_RESOLVED_ROOT"],
    },
    "configuration": {
        "build_type": os.environ["MONAN_JEDI_WPS_BUILD_TYPE"],
        "use_wrf": False,
        "use_mpi": False,
        "use_openmp": False,
        "default_vtable": os.environ["MONAN_JEDI_WPS_DEFAULT_VTABLE"],
    },
    "artifacts": {
        "ungrib": "bin/ungrib.exe",
        "link_grib": "bin/link_grib.csh",
        "variable_tables": "share/wps/Variable_Tables",
    },
}
manifest.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
}

monan_jedi_atomic_symlink() {
  local source="$1"
  local target="$2"
  local temporary="${target}.tmp.$$"
  mkdir -p "$(dirname "${target}")"
  rm -f "${temporary}"
  ln -s "${source}" "${temporary}"
  mv -Tf "${temporary}" "${target}"
}

monan_jedi_promote_wps_release() {
  local stage_dir="$1"
  local final_dir="${MONAN_JEDI_WPS_INSTALL_DIR}"
  local previous_dir="${final_dir}.previous"

  rm -rf "${previous_dir}"
  if [[ -e "${final_dir}" ]]; then
    mv "${final_dir}" "${previous_dir}"
  fi

  if ! mv "${stage_dir}" "${final_dir}"; then
    [[ ! -e "${previous_dir}" ]] || mv "${previous_dir}" "${final_dir}"
    log_error "Could not promote the validated WPS release to ${final_dir}."
    exit 1
  fi

  monan_jedi_atomic_symlink \
    "${final_dir}/bin/ungrib.exe" \
    "${MONAN_JEDI_INSTALL_BIN_DIR}/${MONAN_JEDI_WPS_UNGRIB_NAME}"
  monan_jedi_atomic_symlink \
    "${final_dir}/bin/link_grib.csh" \
    "${MONAN_JEDI_INSTALL_BIN_DIR}/${MONAN_JEDI_WPS_LINK_GRIB_NAME}"
  monan_jedi_atomic_symlink \
    "${final_dir}/share/wps/Variable_Tables" \
    "${MONAN_JEDI_INSTALL_ROOT}/share/wps/Variable_Tables"
  monan_jedi_atomic_symlink \
    "${final_dir}/share/wps/Variable_Tables/${MONAN_JEDI_WPS_DEFAULT_VTABLE}" \
    "${MONAN_JEDI_INSTALL_ROOT}/share/wps/Vtable"

  rm -rf "${previous_dir}"
}

monan_jedi_build_wps() {
  monan_jedi_wps_enabled || {
    log_error "WPS is disabled in ${MONAN_JEDI_CONFIG}. Set wps.enabled: true."
    exit 1
  }

  monan_jedi_validate_wps_config
  monan_jedi_load_stack
  local command
  for command in git cmake install spack python3 find sort csh ldd; do
    require_cmd "${command}"
  done

  monan_jedi_prepare_wps_source
  monan_jedi_wps_resolve_dependencies

  local source_commit cmake_prefix_path stage_dir
  source_commit="$(git -C "${MONAN_JEDI_WPS_SOURCE_DIR}" rev-parse HEAD)"
  cmake_prefix_path="$(monan_jedi_wps_cmake_prefix_path)"
  stage_dir="$(dirname "${MONAN_JEDI_WPS_INSTALL_DIR}")/.staging-$(basename "${MONAN_JEDI_WPS_INSTALL_DIR}")-$$"

  rm -rf "${MONAN_JEDI_WPS_BUILD_DIR}" "${stage_dir}"
  mkdir -p "${MONAN_JEDI_WPS_BUILD_DIR}" "${stage_dir}" "${MONAN_JEDI_LOG_ROOT}"

  cd "${MONAN_JEDI_WPS_SOURCE_DIR}"
  monan_jedi_wps_apply_patches

  log_info "Configuring WPS/UNGRIB"
  log_info "  source=${MONAN_JEDI_WPS_SOURCE_DIR}"
  log_info "  commit=${source_commit}"
  log_info "  build=${MONAN_JEDI_WPS_BUILD_DIR}"
  log_info "  stage=${stage_dir}"

  cmake -S "${MONAN_JEDI_WPS_SOURCE_DIR}" -B "${MONAN_JEDI_WPS_BUILD_DIR}" \
    "-DCMAKE_BUILD_TYPE=${MONAN_JEDI_WPS_BUILD_TYPE}" \
    "-DCMAKE_INSTALL_PREFIX=${stage_dir}" \
    "-DCMAKE_INSTALL_BINDIR=bin" \
    "-DCMAKE_INSTALL_LIBDIR=lib" \
    "-DCMAKE_INSTALL_RPATH=\$ORIGIN/../lib" \
    "-DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON" \
    "-DCMAKE_C_COMPILER=${CC}" \
    "-DCMAKE_CXX_COMPILER=${CXX}" \
    "-DCMAKE_Fortran_COMPILER=${FC}" \
    "-DCMAKE_PREFIX_PATH=${cmake_prefix_path}" \
    "-DJasper_ROOT=${MONAN_JEDI_WPS_JASPER_RESOLVED_ROOT}" \
    "-DPNG_ROOT=${MONAN_JEDI_WPS_PNG_RESOLVED_ROOT}" \
    "-DZLIB_ROOT=${MONAN_JEDI_WPS_ZLIB_RESOLVED_ROOT}" \
    "-DUSE_WRF=OFF" \
    "-DUSE_MPI=OFF" \
    "-DUSE_OPENMP=OFF" \
    "-DBUILD_EXTERNALS=OFF" \
    2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/09_wps_cmake.log"

  cmake --build "${MONAN_JEDI_WPS_BUILD_DIR}" \
    --target ungrib g1print g2print \
    --parallel "${MONAN_JEDI_BUILD_JOBS}" \
    2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/09_wps_build.log"

  cmake --install "${MONAN_JEDI_WPS_BUILD_DIR}" \
    2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/09_wps_install.log"

  monan_jedi_wps_prepare_runtime_tree "${stage_dir}"
  monan_jedi_validate_wps_tree "${stage_dir}" "${MONAN_JEDI_LOG_ROOT}/09_wps_validate.log"
  monan_jedi_write_wps_manifest "${stage_dir}" "${source_commit}"
  monan_jedi_promote_wps_release "${stage_dir}"

  log_info "WPS release published=${MONAN_JEDI_WPS_INSTALL_DIR}"
  log_info "ungrib=${MONAN_JEDI_INSTALL_BIN_DIR}/${MONAN_JEDI_WPS_UNGRIB_NAME}"
  log_info "Vtable=${MONAN_JEDI_INSTALL_ROOT}/share/wps/Vtable"
}

monan_jedi_test_wps() {
  monan_jedi_wps_enabled || {
    log_error "WPS is disabled in ${MONAN_JEDI_CONFIG}."
    exit 1
  }
  monan_jedi_load_stack
  require_cmd csh
  require_cmd ldd
  monan_jedi_validate_wps_tree "${MONAN_JEDI_WPS_INSTALL_DIR}" "${MONAN_JEDI_LOG_ROOT}/09_wps_test.log"
  log_info "WPS installation validation passed."
}
