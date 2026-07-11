#!/usr/bin/env bash
# Dependency discovery and source patch helpers for the WPS auxiliary build.

monan_jedi_wps_root_or_spack() {
  local variable="$1"
  local package="$2"
  local label="$3"
  local configured="${!variable:-}"
  local root=""

  if [[ -n "${configured}" ]]; then
    [[ -d "${configured}" ]] || {
      log_error "Configured ${label} root not found: ${configured}"
      exit 1
    }
    printf '%s\n' "${configured}"
    return 0
  fi

  root="$(spack location -i "${package}" 2>/dev/null || true)"
  [[ -n "${root}" && -d "${root}" ]] || {
    log_error "Could not locate ${label}; set ${variable} in the YAML configuration."
    exit 1
  }
  printf '%s\n' "${root}"
}

monan_jedi_wps_resolve_dependencies() {
  export MONAN_JEDI_WPS_JASPER_RESOLVED_ROOT="$(monan_jedi_wps_root_or_spack MONAN_JEDI_WPS_JASPER_ROOT jasper JasPer)"
  export MONAN_JEDI_WPS_PNG_RESOLVED_ROOT="$(monan_jedi_wps_root_or_spack MONAN_JEDI_WPS_PNG_ROOT libpng libpng)"
  export MONAN_JEDI_WPS_ZLIB_RESOLVED_ROOT="$(monan_jedi_wps_root_or_spack MONAN_JEDI_WPS_ZLIB_ROOT zlib zlib)"

  local root
  for root in \
    "${MONAN_JEDI_WPS_JASPER_RESOLVED_ROOT}" \
    "${MONAN_JEDI_WPS_PNG_RESOLVED_ROOT}" \
    "${MONAN_JEDI_WPS_ZLIB_RESOLVED_ROOT}"
  do
    [[ -d "${root}/include" ]] || {
      log_error "Dependency include directory not found: ${root}/include"
      exit 1
    }
    [[ -d "${root}/lib" || -d "${root}/lib64" ]] || {
      log_error "Dependency library directory not found below: ${root}"
      exit 1
    }
  done
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
