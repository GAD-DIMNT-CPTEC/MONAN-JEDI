#!/usr/bin/env bash
# Validate the installed MONAN-JEDI runtime contract.
#
# Purpose:
#   Check the public installation consumed by mpaswf, MPAS-BMatrix and other
#   workflows after the configured spack-stack environment has been loaded.
#   This is intentionally broader than an executable smoke test: it validates
#   layout, runtime support files, shared-library resolution and project-group
#   accessibility.

monan_jedi_install_feature_enabled() {
  case "${1:-0}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

monan_jedi_install_record_pass() {
  MONAN_JEDI_INSTALL_CHECKS=$((MONAN_JEDI_INSTALL_CHECKS + 1))
  MONAN_JEDI_INSTALL_PASSES=$((MONAN_JEDI_INSTALL_PASSES + 1))
  printf '[PASS] %s\n' "$1"
}

monan_jedi_install_record_fail() {
  MONAN_JEDI_INSTALL_CHECKS=$((MONAN_JEDI_INSTALL_CHECKS + 1))
  MONAN_JEDI_INSTALL_FAILURES=$((MONAN_JEDI_INSTALL_FAILURES + 1))
  printf '[FAIL] %s\n' "$1"
}

monan_jedi_install_check_directory() {
  local label="$1"
  local path="$2"

  if [[ -d "${path}" ]]; then
    monan_jedi_install_record_pass "${label}: ${path}"
  else
    monan_jedi_install_record_fail "${label}: missing directory ${path}"
  fi
}

monan_jedi_install_check_file() {
  local label="$1"
  local path="$2"

  if [[ -f "${path}" ]]; then
    monan_jedi_install_record_pass "${label}: ${path}"
  else
    monan_jedi_install_record_fail "${label}: missing file ${path}"
  fi
}

monan_jedi_install_check_dynamic_dependencies() {
  local label="$1"
  local path="$2"
  local output=""
  local status=0

  if output="$(ldd "${path}" 2>&1)"; then
    status=0
  else
    status=$?
  fi

  if grep -Fq 'not found' <<< "${output}"; then
    monan_jedi_install_record_fail "${label}: unresolved shared libraries"
    printf '%s\n' "${output}" | grep -F 'not found' || true
    return 0
  fi

  if [[ "${status}" -ne 0 ]]; then
    case "${output}" in
      *"not a dynamic executable"*|*"statically linked"*)
        monan_jedi_install_record_pass "${label}: no unresolved shared libraries (static/non-dynamic)"
        ;;
      *)
        monan_jedi_install_record_fail "${label}: ldd failed with status ${status}"
        printf '%s\n' "${output}"
        ;;
    esac
    return 0
  fi

  monan_jedi_install_record_pass "${label}: all shared libraries resolved"
}

monan_jedi_install_check_executable() {
  local name="$1"
  local path="${MONAN_JEDI_INSTALL_BIN_DIR}/${name}"

  if [[ ! -x "${path}" ]]; then
    monan_jedi_install_record_fail "executable ${name}: missing or not executable at ${path}"
    return 0
  fi

  monan_jedi_install_record_pass "executable ${name}: ${path}"
  monan_jedi_install_check_dynamic_dependencies "executable ${name}" "${path}"
}

monan_jedi_install_check_path_resolves_inside_root() {
  local label="$1"
  local path="$2"
  local resolved=""

  if [[ ! -e "${path}" ]]; then
    monan_jedi_install_record_fail "${label}: missing or broken path ${path}"
    return 0
  fi

  resolved="$(readlink -f "${path}" 2>/dev/null || true)"
  if [[ -z "${resolved}" ]]; then
    monan_jedi_install_record_fail "${label}: could not resolve ${path}"
    return 0
  fi

  case "${resolved}" in
    "${MONAN_JEDI_INSTALL_ROOT}"|"${MONAN_JEDI_INSTALL_ROOT}"/*)
      monan_jedi_install_record_pass "${label}: ${path} -> ${resolved}"
      ;;
    *)
      monan_jedi_install_record_fail "${label}: resolves outside install root: ${resolved}"
      ;;
  esac
}

monan_jedi_install_check_manifest() {
  local manifest="${MONAN_JEDI_INSTALL_ROOT}/share/monan-jedi/install-manifest.json"
  local output=""

  if [[ ! -f "${manifest}" ]]; then
    monan_jedi_install_record_fail "install manifest: missing ${manifest}"
    return 0
  fi

  if output="$(python3 - "${manifest}" "${MONAN_JEDI_INSTALL_ROOT}" <<'PY'
import json
import sys
from pathlib import Path

manifest = Path(sys.argv[1])
root = Path(sys.argv[2]).resolve()
record = json.loads(manifest.read_text(encoding="utf-8"))

if record.get("schema_version") != 1:
    raise SystemExit("schema_version must be 1")

recorded_root = Path(record.get("install_root", "")).resolve()
if recorded_root != root:
    raise SystemExit(
        "manifest install_root mismatch: {0} != {1}".format(recorded_root, root)
    )

expected_contract = {
    "bin": "bin",
    "include": "include",
    "lib": "lib",
    "share": "share",
    "mpas_atmosphere_share": "share/MPAS/core_atmosphere",
    "wps_variable_tables": "share/wps/Variable_Tables",
    "mpas_jedi_namelists": "share/monan-jedi/mpas-jedi/namelists",
}
contract = record.get("public_contract", {})
for key, value in expected_contract.items():
    if contract.get(key) != value:
        raise SystemExit(
            "public_contract.{0} mismatch: {1!r} != {2!r}".format(
                key, contract.get(key), value
            )
        )

for relative in record.get("required_runtime_support", []):
    path = root / relative
    if not path.is_file():
        raise SystemExit("manifest runtime support is missing: {0}".format(path))
PY
)"; then
    monan_jedi_install_record_pass "install manifest: schema and paths are valid"
  else
    monan_jedi_install_record_fail "install manifest: invalid"
    [[ -z "${output}" ]] || printf '%s\n' "${output}"
  fi
}

monan_jedi_install_check_group_access() {
  local root_gid=""
  local first=""

  if [[ ! -d "${MONAN_JEDI_INSTALL_ROOT}" ]]; then
    monan_jedi_install_record_fail "project-group access: install root is missing"
    return 0
  fi

  root_gid="$(stat -c '%g' "${MONAN_JEDI_INSTALL_ROOT}")"

  first="$(find "${MONAN_JEDI_INSTALL_ROOT}" -xdev ! -gid "${root_gid}" -print -quit)"
  if [[ -n "${first}" ]]; then
    monan_jedi_install_record_fail "project-group ownership: entries differ from install-root group"
    find "${MONAN_JEDI_INSTALL_ROOT}" -xdev ! -gid "${root_gid}" -print | sed -n '1,20p'
  else
    monan_jedi_install_record_pass "project-group ownership: all entries match install-root group"
  fi

  first="$(find "${MONAN_JEDI_INSTALL_ROOT}" -xdev -type f ! -perm -0040 -print -quit)"
  if [[ -n "${first}" ]]; then
    monan_jedi_install_record_fail "project-group readability: files without group-read permission"
    find "${MONAN_JEDI_INSTALL_ROOT}" -xdev -type f ! -perm -0040 -printf '%M %u %g %p\n' | sed -n '1,20p'
  else
    monan_jedi_install_record_pass "project-group readability: all files are group-readable"
  fi

  first="$(find "${MONAN_JEDI_INSTALL_ROOT}" -xdev -type d ! -perm -0050 -print -quit)"
  if [[ -n "${first}" ]]; then
    monan_jedi_install_record_fail "project-group directory access: directories without group r-x"
    find "${MONAN_JEDI_INSTALL_ROOT}" -xdev -type d ! -perm -0050 -printf '%M %u %g %p\n' | sed -n '1,20p'
  else
    monan_jedi_install_record_pass "project-group directory access: all directories are group-readable/searchable"
  fi

  first="$(find "${MONAN_JEDI_INSTALL_ROOT}" -xdev -type f -perm -0100 ! -perm -0010 -print -quit)"
  if [[ -n "${first}" ]]; then
    monan_jedi_install_record_fail "project-group executable access: owner-executable files missing group-execute"
    find "${MONAN_JEDI_INSTALL_ROOT}" -xdev -type f -perm -0100 ! -perm -0010 -printf '%M %u %g %p\n' | sed -n '1,20p'
  else
    monan_jedi_install_record_pass "project-group executable access: executable files are group-executable"
  fi
}

monan_jedi_validate_install_tree() {
  local name
  local -a required_executables=(
    "mpas_init_atmosphere"
    "mpas_atmosphere"
    "mpasjedi_variational.x"
    "mpasjedi_error_covariance_toolbox.x"
    "mpasjedi_process_perts.x"
    "mpasjedi_unbalance_ensemble.x"
  )

  MONAN_JEDI_INSTALL_CHECKS=0
  MONAN_JEDI_INSTALL_PASSES=0
  MONAN_JEDI_INSTALL_FAILURES=0

  echo "============================================================"
  echo "MONAN-JEDI installed runtime validation"
  echo "install_root=${MONAN_JEDI_INSTALL_ROOT}"
  echo "config=${MONAN_JEDI_CONFIG:-unknown}"
  echo "============================================================"

  monan_jedi_install_check_directory "public bin" "${MONAN_JEDI_INSTALL_ROOT}/bin"
  monan_jedi_install_check_directory "public lib" "${MONAN_JEDI_INSTALL_ROOT}/lib"
  monan_jedi_install_check_directory "public include" "${MONAN_JEDI_INSTALL_ROOT}/include"
  monan_jedi_install_check_directory "public share" "${MONAN_JEDI_INSTALL_ROOT}/share"

  for name in "${required_executables[@]}"; do
    monan_jedi_install_check_executable "${name}"
  done

  monan_jedi_install_check_file \
    "MPAS atmosphere streams" \
    "${MONAN_JEDI_INSTALL_ROOT}/share/MPAS/core_atmosphere/streams.atmosphere"
  monan_jedi_install_check_file \
    "MPAS atmosphere namelist" \
    "${MONAN_JEDI_INSTALL_ROOT}/share/MPAS/core_atmosphere/namelist.atmosphere"
  monan_jedi_install_check_file \
    "MPAS-JEDI geovars" \
    "${MONAN_JEDI_INSTALL_ROOT}/share/monan-jedi/mpas-jedi/namelists/geovars.yaml"
  monan_jedi_install_check_file \
    "MPAS-JEDI keptvars" \
    "${MONAN_JEDI_INSTALL_ROOT}/share/monan-jedi/mpas-jedi/namelists/keptvars.yaml"

  monan_jedi_install_check_manifest

  if monan_jedi_install_feature_enabled "${MONAN_JEDI_WPS_ENABLED:-0}"; then
    monan_jedi_install_check_executable "${MONAN_JEDI_WPS_UNGRIB_NAME:-ungrib.exe}"
    monan_jedi_install_check_file \
      "WPS link_grib helper" \
      "${MONAN_JEDI_INSTALL_BIN_DIR}/${MONAN_JEDI_WPS_LINK_GRIB_NAME:-link_grib.csh}"
    monan_jedi_install_check_file \
      "WPS default Vtable" \
      "${MONAN_JEDI_INSTALL_ROOT}/share/wps/Variable_Tables/${MONAN_JEDI_WPS_DEFAULT_VTABLE:-Vtable.GFS}"
    monan_jedi_install_check_file \
      "WPS release manifest" \
      "${MONAN_JEDI_WPS_INSTALL_DIR}/build-manifest.json"
    monan_jedi_install_check_path_resolves_inside_root \
      "WPS public ungrib" \
      "${MONAN_JEDI_INSTALL_BIN_DIR}/${MONAN_JEDI_WPS_UNGRIB_NAME:-ungrib.exe}"
    monan_jedi_install_check_path_resolves_inside_root \
      "WPS public Variable_Tables" \
      "${MONAN_JEDI_INSTALL_ROOT}/share/wps/Variable_Tables"
  else
    printf '[SKIP] WPS checks: wps.enabled is false\n'
  fi

  if monan_jedi_install_feature_enabled "${MONAN_JEDI_OBS2IODA_ENABLED:-0}"; then
    monan_jedi_install_check_executable "${MONAN_JEDI_OBS2IODA_EXECUTABLE_NAME:-obs2ioda_v3}"
  else
    printf '[SKIP] obs2ioda checks: obs2ioda.enabled is false\n'
  fi

  monan_jedi_install_check_group_access

  echo "------------------------------------------------------------"
  echo "checks=${MONAN_JEDI_INSTALL_CHECKS}"
  echo "passed=${MONAN_JEDI_INSTALL_PASSES}"
  echo "failed=${MONAN_JEDI_INSTALL_FAILURES}"

  if [[ "${MONAN_JEDI_INSTALL_FAILURES}" -eq 0 ]]; then
    echo "RESULT=PASS"
    echo "MONAN-JEDI installation is ready for downstream runtime use."
    echo "============================================================"
    return 0
  fi

  echo "RESULT=FAIL"
  echo "MONAN-JEDI installation is NOT ready for downstream runtime use."
  echo "============================================================"
  return 1
}

monan_jedi_test_install() {
  local validation_status=0
  local log_file="${MONAN_JEDI_LOG_ROOT}/10_install_test.log"

  monan_jedi_load_stack
  require_cmd find
  require_cmd ldd
  require_cmd python3
  require_cmd readlink
  require_cmd sed
  require_cmd stat

  mkdir -p "${MONAN_JEDI_LOG_ROOT}"

  monan_jedi_validate_install_tree 2>&1 | tee "${log_file}" || validation_status=${PIPESTATUS[0]}

  if [[ "${validation_status}" -eq 0 ]]; then
    log_info "Installed runtime validation passed: ${log_file}"
  else
    log_error "Installed runtime validation failed: ${log_file}"
  fi

  return "${validation_status}"
}
