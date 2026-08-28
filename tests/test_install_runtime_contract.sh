#!/usr/bin/env bash
set -euo pipefail
umask 002

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/install_test.sh
source "${repo_root}/scripts/lib/install_test.sh"

tmp_root="$(mktemp -d)"
trap 'rm -rf "${tmp_root}"' EXIT

export MONAN_JEDI_CONFIG="test-config.yaml"
export MONAN_JEDI_INSTALL_ROOT="${tmp_root}/install"
export MONAN_JEDI_INSTALL_BIN_DIR="${MONAN_JEDI_INSTALL_ROOT}/bin"
export MONAN_JEDI_WPS_ENABLED=1
export MONAN_JEDI_WPS_UNGRIB_NAME="ungrib.exe"
export MONAN_JEDI_WPS_LINK_GRIB_NAME="link_grib.csh"
export MONAN_JEDI_WPS_DEFAULT_VTABLE="Vtable.GFS"
export MONAN_JEDI_WPS_INSTALL_DIR="${MONAN_JEDI_INSTALL_ROOT}/libexec/monan-jedi/wps/WPS-4.6.0"
export MONAN_JEDI_OBS2IODA_ENABLED=1
export MONAN_JEDI_OBS2IODA_EXECUTABLE_NAME="obs2ioda_v3"

mkdir -p \
  "${MONAN_JEDI_INSTALL_BIN_DIR}" \
  "${MONAN_JEDI_INSTALL_ROOT}/lib" \
  "${MONAN_JEDI_INSTALL_ROOT}/include" \
  "${MONAN_JEDI_INSTALL_ROOT}/share/MPAS/core_atmosphere" \
  "${MONAN_JEDI_INSTALL_ROOT}/share/monan-jedi/mpas-jedi/namelists" \
  "${MONAN_JEDI_WPS_INSTALL_DIR}/bin" \
  "${MONAN_JEDI_WPS_INSTALL_DIR}/share/wps/Variable_Tables"

for name in \
  mpas_init_atmosphere \
  mpas_atmosphere \
  mpasjedi_variational.x \
  mpasjedi_error_covariance_toolbox.x \
  mpasjedi_process_perts.x \
  mpasjedi_unbalance_ensemble.x \
  obs2ioda_v3
 do
  printf '#!/usr/bin/env bash\nexit 0\n' > "${MONAN_JEDI_INSTALL_BIN_DIR}/${name}"
  chmod 775 "${MONAN_JEDI_INSTALL_BIN_DIR}/${name}"
done

printf '#!/usr/bin/env bash\nexit 0\n' > "${MONAN_JEDI_WPS_INSTALL_DIR}/bin/ungrib.exe"
chmod 775 "${MONAN_JEDI_WPS_INSTALL_DIR}/bin/ungrib.exe"
printf '#!/usr/bin/env csh\nexit 0\n' > "${MONAN_JEDI_WPS_INSTALL_DIR}/bin/link_grib.csh"
chmod 775 "${MONAN_JEDI_WPS_INSTALL_DIR}/bin/link_grib.csh"
printf 'Vtable fixture\n' > "${MONAN_JEDI_WPS_INSTALL_DIR}/share/wps/Variable_Tables/Vtable.GFS"
printf '{}\n' > "${MONAN_JEDI_WPS_INSTALL_DIR}/build-manifest.json"

mkdir -p "${MONAN_JEDI_INSTALL_ROOT}/share/wps"
ln -s "${MONAN_JEDI_WPS_INSTALL_DIR}/bin/ungrib.exe" "${MONAN_JEDI_INSTALL_BIN_DIR}/ungrib.exe"
ln -s "${MONAN_JEDI_WPS_INSTALL_DIR}/bin/link_grib.csh" "${MONAN_JEDI_INSTALL_BIN_DIR}/link_grib.csh"
ln -s "${MONAN_JEDI_WPS_INSTALL_DIR}/share/wps/Variable_Tables" "${MONAN_JEDI_INSTALL_ROOT}/share/wps/Variable_Tables"
ln -s "${MONAN_JEDI_WPS_INSTALL_DIR}/share/wps/Variable_Tables/Vtable.GFS" "${MONAN_JEDI_INSTALL_ROOT}/share/wps/Vtable"

printf 'streams fixture\n' > "${MONAN_JEDI_INSTALL_ROOT}/share/MPAS/core_atmosphere/streams.atmosphere"
printf 'namelist fixture\n' > "${MONAN_JEDI_INSTALL_ROOT}/share/MPAS/core_atmosphere/namelist.atmosphere"
printf 'geovars fixture\n' > "${MONAN_JEDI_INSTALL_ROOT}/share/monan-jedi/mpas-jedi/namelists/geovars.yaml"
printf 'keptvars fixture\n' > "${MONAN_JEDI_INSTALL_ROOT}/share/monan-jedi/mpas-jedi/namelists/keptvars.yaml"

python3 - "${MONAN_JEDI_INSTALL_ROOT}/share/monan-jedi/install-manifest.json" "${MONAN_JEDI_INSTALL_ROOT}" <<'PY'
import json
import sys
from pathlib import Path

manifest = Path(sys.argv[1])
root = Path(sys.argv[2])
manifest.write_text(
    json.dumps(
        {
            "schema_version": 1,
            "install_root": str(root),
            "public_contract": {
                "bin": "bin",
                "include": "include",
                "lib": "lib",
                "share": "share",
                "mpas_atmosphere_share": "share/MPAS/core_atmosphere",
                "wps_variable_tables": "share/wps/Variable_Tables",
                "mpas_jedi_namelists": "share/monan-jedi/mpas-jedi/namelists",
            },
            "required_runtime_support": [
                "share/monan-jedi/mpas-jedi/namelists/geovars.yaml",
                "share/monan-jedi/mpas-jedi/namelists/keptvars.yaml",
            ],
        },
        indent=2,
        sort_keys=True,
    )
    + "\n",
    encoding="utf-8",
)
PY

fake_bin="${tmp_root}/fake-bin"
mkdir -p "${fake_bin}"
cat > "${fake_bin}/ldd" <<'EOF_LDD'
#!/usr/bin/env bash
if [[ "${FAKE_LDD_MISSING:-0}" == "1" ]]; then
  echo 'libfabric.so.1 => not found'
else
  echo 'libfixture.so => /tmp/libfixture.so (0x00000000)'
fi
EOF_LDD
chmod 775 "${fake_bin}/ldd"
export PATH="${fake_bin}:${PATH}"

positive_log="${tmp_root}/positive.log"
monan_jedi_validate_install_tree > "${positive_log}"
grep -Fq 'RESULT=PASS' "${positive_log}"
grep -Fq 'project-group readability: all files are group-readable' "${positive_log}"

vtable="${MONAN_JEDI_WPS_INSTALL_DIR}/share/wps/Variable_Tables/Vtable.GFS"
chmod 600 "${vtable}"
permission_log="${tmp_root}/permission.log"
if monan_jedi_validate_install_tree > "${permission_log}" 2>&1; then
  echo "Expected group-permission validation to fail" >&2
  exit 1
fi
grep -Fq 'project-group readability: files without group-read permission' "${permission_log}"
grep -Fq 'RESULT=FAIL' "${permission_log}"
chmod 664 "${vtable}"

export FAKE_LDD_MISSING=1
link_log="${tmp_root}/link.log"
if monan_jedi_validate_install_tree > "${link_log}" 2>&1; then
  echo "Expected unresolved-library validation to fail" >&2
  exit 1
fi
grep -Fq 'unresolved shared libraries' "${link_log}"
grep -Fq 'libfabric.so.1 => not found' "${link_log}"
unset FAKE_LDD_MISSING

grep -Fq 'test-install' "${repo_root}/scripts/monan-jedi.sh"

echo "Installed runtime contract tests passed"
