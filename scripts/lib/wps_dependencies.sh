#!/usr/bin/env bash
# Dependency discovery and source patch helpers for the WPS auxiliary build.

monan_jedi_wps_dependency_header() {
  local root="$1"
  local package="$2"
  local header=""

  case "${package}" in
    jasper)
      header="${root}/include/jasper/jasper.h"
      [[ -f "${header}" ]] && printf '%s\n' "${header}"
      ;;
    libpng)
      if [[ -f "${root}/include/png.h" ]]; then
        printf '%s\n' "${root}/include/png.h"
      elif [[ -d "${root}/include" ]]; then
        find "${root}/include" -maxdepth 2 -type f -name 'png.h' -print -quit 2>/dev/null
      fi
      ;;
    zlib)
      header="${root}/include/zlib.h"
      [[ -f "${header}" ]] && printf '%s\n' "${header}"
      ;;
    *)
      return 1
      ;;
  esac
}

monan_jedi_wps_dependency_library() {
  local root="$1"
  local package="$2"
  local pattern=""
  local lib_dir=""
  local match=""

  case "${package}" in
    jasper) pattern='libjasper.*' ;;
    libpng) pattern='libpng*' ;;
    zlib) pattern='libz.*' ;;
    *) return 1 ;;
  esac

  for lib_dir in "${root}/lib" "${root}/lib64"; do
    [[ -d "${lib_dir}" ]] || continue
    match="$(find "${lib_dir}" -maxdepth 1 \( -type f -o -type l \) -name "${pattern}" -print -quit 2>/dev/null || true)"
    if [[ -n "${match}" ]]; then
      printf '%s\n' "${match}"
      return 0
    fi
  done

  return 1
}

monan_jedi_wps_valid_dependency_root() {
  local root="$1"
  local package="$2"

  [[ -n "${root}" && -d "${root}" ]] || return 1
  [[ -n "$(monan_jedi_wps_dependency_header "${root}" "${package}" || true)" ]] || return 1
  [[ -n "$(monan_jedi_wps_dependency_library "${root}" "${package}" || true)" ]] || return 1
}

monan_jedi_wps_spack_executable() {
  local candidate=""

  if command -v spack >/dev/null 2>&1; then
    command -v spack
    return 0
  fi

  for candidate in \
    "${STACK_ROOT:-}/spack/bin/spack" \
    "${STACK_WORK_ROOT:-}/spack-stack/spack/bin/spack"
  do
    [[ -n "${candidate}" && -x "${candidate}" ]] || continue
    printf '%s\n' "${candidate}"
    return 0
  done

  return 1
}

monan_jedi_wps_location_from_spack() {
  local package="$1"
  local spack_executable=""
  local root=""

  spack_executable="$(monan_jedi_wps_spack_executable || true)"
  [[ -n "${spack_executable}" ]] || return 1

  root="$("${spack_executable}" location -i "${package}" 2>/dev/null || true)"
  [[ -n "${root}" && -d "${root}" ]] || return 1
  printf '%s\n' "${root}"
}

monan_jedi_wps_loaded_prefixes() {
  local package="$1"
  local raw_prefixes="${CMAKE_PREFIX_PATH:-}"
  local prefix=""
  local executable=""
  local pkg_name=""
  local -a prefixes=()

  raw_prefixes="${raw_prefixes//;/:}"
  IFS=':' read -r -a prefixes <<< "${raw_prefixes}"
  for prefix in "${prefixes[@]}"; do
    [[ -n "${prefix}" ]] && printf '%s\n' "${prefix}"
  done

  case "${package}" in
    jasper)
      executable="$(command -v jasper 2>/dev/null || true)"
      [[ -n "${executable}" ]] && dirname "$(dirname "${executable}")"
      ;;
    libpng)
      if command -v libpng-config >/dev/null 2>&1; then
        libpng-config --prefix 2>/dev/null || true
      fi
      ;;
  esac

  if command -v pkg-config >/dev/null 2>&1; then
    case "${package}" in
      jasper) pkg_name='jasper' ;;
      libpng) pkg_name='libpng' ;;
      zlib) pkg_name='zlib' ;;
    esac
    [[ -z "${pkg_name}" ]] || pkg-config --variable=prefix "${pkg_name}" 2>/dev/null || true
  fi
}

monan_jedi_wps_location_from_loaded_environment() {
  local package="$1"
  local candidate=""

  while IFS= read -r candidate; do
    [[ -n "${candidate}" ]] || continue
    if monan_jedi_wps_valid_dependency_root "${candidate}" "${package}"; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done < <(monan_jedi_wps_loaded_prefixes "${package}")

  return 1
}

monan_jedi_wps_location_from_install_tree() {
  local package="$1"
  local install_root=""
  local header=""
  local candidate=""
  local -a install_roots=(
    "${STACK_ROOT:-}/../install"
    "${STACK_WORK_ROOT:-}/install"
    "${STACK_ROOT:-}/install"
    "/p/projetos/monan_das/${STACK_OWNER:-}/env/spack-stack/${STACK_INSTANCE:-}/install"
  )

  for install_root in "${install_roots[@]}"; do
    [[ -n "${install_root}" && -d "${install_root}" ]] || continue

    case "${package}" in
      jasper)
        header="$(find "${install_root}" -type f -path '*/include/jasper/jasper.h' -print -quit 2>/dev/null || true)"
        ;;
      libpng)
        header="$(find "${install_root}" -type f \( -path '*/include/png.h' -o -path '*/include/libpng*/png.h' \) -print -quit 2>/dev/null || true)"
        ;;
      zlib)
        header="$(find "${install_root}" -type f -path '*/include/zlib.h' -print -quit 2>/dev/null || true)"
        ;;
      *)
        return 1
        ;;
    esac

    [[ -n "${header}" ]] || continue
    candidate="${header%%/include/*}"
    if monan_jedi_wps_valid_dependency_root "${candidate}" "${package}"; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  return 1
}

monan_jedi_wps_root_or_discover() {
  local variable="$1"
  local package="$2"
  local label="$3"
  local configured="${!variable:-}"
  local root=""

  if [[ -n "${configured}" ]]; then
    if ! monan_jedi_wps_valid_dependency_root "${configured}" "${package}"; then
      log_error "Configured ${label} root is incomplete or invalid: ${configured}"
      exit 1
    fi
    printf '%s\n' "${configured}"
    return 0
  fi

  root="$(monan_jedi_wps_location_from_loaded_environment "${package}" || true)"
  if [[ -n "${root}" ]]; then
    printf '%s\n' "${root}"
    return 0
  fi

  root="$(monan_jedi_wps_location_from_spack "${package}" || true)"
  if [[ -n "${root}" ]] && monan_jedi_wps_valid_dependency_root "${root}" "${package}"; then
    printf '%s\n' "${root}"
    return 0
  fi

  root="$(monan_jedi_wps_location_from_install_tree "${package}" || true)"
  if [[ -n "${root}" ]]; then
    printf '%s\n' "${root}"
    return 0
  fi

  log_error "Could not locate ${label}. Set ${variable} in the YAML configuration or verify the loaded stack installation."
  exit 1
}

monan_jedi_wps_resolve_dependencies() {
  export MONAN_JEDI_WPS_JASPER_RESOLVED_ROOT="$(monan_jedi_wps_root_or_discover MONAN_JEDI_WPS_JASPER_ROOT jasper JasPer)"
  export MONAN_JEDI_WPS_PNG_RESOLVED_ROOT="$(monan_jedi_wps_root_or_discover MONAN_JEDI_WPS_PNG_ROOT libpng libpng)"
  export MONAN_JEDI_WPS_ZLIB_RESOLVED_ROOT="$(monan_jedi_wps_root_or_discover MONAN_JEDI_WPS_ZLIB_ROOT zlib zlib)"

  log_info "Resolved WPS dependencies"
  log_info "  JasPer=${MONAN_JEDI_WPS_JASPER_RESOLVED_ROOT}"
  log_info "  libpng=${MONAN_JEDI_WPS_PNG_RESOLVED_ROOT}"
  log_info "  zlib=${MONAN_JEDI_WPS_ZLIB_RESOLVED_ROOT}"
}

monan_jedi_wps_cmake_prefix_path() {
  local prefixes=(
    "${MONAN_JEDI_WPS_JASPER_RESOLVED_ROOT}"
    "${MONAN_JEDI_WPS_PNG_RESOLVED_ROOT}"
    "${MONAN_JEDI_WPS_ZLIB_RESOLVED_ROOT}"
  )
  [[ -z "${MONAN_JEDI_WPS_CMAKE_PREFIX_PATH:-}" ]] || prefixes+=("${MONAN_JEDI_WPS_CMAKE_PREFIX_PATH}")
  [[ -z "${CMAKE_PREFIX_PATH:-}" ]] || prefixes+=("${CMAKE_PREFIX_PATH}")

  local joined=""
  local prefix
  for prefix in "${prefixes[@]}"; do
    [[ -n "${prefix}" ]] || continue
    joined="${joined:+${joined};}${prefix}"
  done
  printf '%s\n' "${joined}"
}

monan_jedi_wps_apply_patch() {
  local patch_file="$1"
  [[ -f "${patch_file}" ]] || {
    log_error "WPS patch not found: ${patch_file}"
    exit 1
  }

  if git apply --check "${patch_file}"; then
    git apply "${patch_file}"
    log_info "Applied WPS patch: $(basename "${patch_file}")"
  elif git apply --reverse --check "${patch_file}"; then
    log_info "WPS patch already applied: $(basename "${patch_file}")"
  else
    log_error "WPS patch does not apply cleanly: ${patch_file}"
    exit 1
  fi
}

monan_jedi_wps_apply_patches() {
  [[ -d "${MONAN_JEDI_WPS_PATCH_DIR}" ]] || {
    log_error "WPS patch directory not found: ${MONAN_JEDI_WPS_PATCH_DIR}"
    exit 1
  }

  local patch_file
  local found=0
  while IFS= read -r -d '' patch_file; do
    found=1
    monan_jedi_wps_apply_patch "${patch_file}"
  done < <(find "${MONAN_JEDI_WPS_PATCH_DIR}" -maxdepth 1 -type f -name '*.patch' -print0 | sort -z)

  [[ ${found} -eq 1 ]] || log_warn "No WPS patches were found in ${MONAN_JEDI_WPS_PATCH_DIR}."
}
