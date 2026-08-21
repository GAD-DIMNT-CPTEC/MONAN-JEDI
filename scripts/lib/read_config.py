#!/usr/bin/env python3
"""Read MONAN-JEDI YAML configuration and emit shell exports."""

import os
import shlex
import sys
from pathlib import Path
from typing import Any, Dict

try:
    import yaml
except ImportError:
    sys.stderr.write("PyYAML is required.\n")
    sys.exit(1)


def read_yaml(path: str) -> Dict[str, Any]:
    with Path(path).open("r", encoding="utf-8") as stream:
        loaded = yaml.safe_load(stream)
    if loaded is None:
        return {}
    if not isinstance(loaded, dict):
        raise ValueError("The configuration root must be a YAML mapping")
    return loaded


def get_value(data: Dict[str, Any], path: str, default: str = "") -> str:
    current: Any = data
    for key in path.split("."):
        if not isinstance(current, dict) or key not in current:
            return default
        current = current[key]

    if current is None:
        return default
    if isinstance(current, bool):
        return "1" if current else "0"
    return os.path.expandvars(str(current))


def emit(name: str, value: str) -> None:
    resolved = os.environ.get(name, value)
    sys.stdout.write(f"export {name}={shlex.quote(resolved)}\n")


def main() -> int:
    if len(sys.argv) != 2:
        sys.stderr.write("Usage: read_config.py <config.yaml>\n")
        return 2

    try:
        data = read_yaml(sys.argv[1])
    except (OSError, ValueError, yaml.YAMLError) as exc:
        sys.stderr.write(f"Could not read configuration: {exc}\n")
        return 1

    mapping = {
        "PROJECT_ROOT": "project.root",
        "STACK_OWNER": "stack.owner",
        "STACK_INSTANCE": "stack.instance",
        "STACK_WORK_ROOT": "stack.work_root",
        "STACK_ROOT": "stack.root",
        "STACK_ENV_NAME": "stack.env_name",
        "STACK_MODULE_ROOT": "stack.module_root",
        "STACK_SITE_SETUP": "stack.site_setup",
        "STACK_ENV_MODULE": "stack.env_module",
        "MONAN_JEDI_RUN_ID": "build.id",
        "MONAN_JEDI_BUILD_DIR": "build.dir",
        "MONAN_JEDI_BUILD_JOBS": "build.jobs",
        "MONAN_JEDI_INSTALL_ROOT": "install.root",
        "MONAN_JEDI_INSTALL_BIN_DIR": "install.bin_dir",
        "MONAN_JEDI_CC": "compilers.cc",
        "MONAN_JEDI_CXX": "compilers.cxx",
        "MONAN_JEDI_FC": "compilers.fc",
        "MONAN_JEDI_F77": "compilers.f77",
        "MONAN_JEDI_F90": "compilers.f90",
        "MONAN_JEDI_MPICC": "mpi.mpicc",
        "MONAN_JEDI_MPICXX": "mpi.mpicxx",
        "MONAN_JEDI_MPIFC": "mpi.mpifc",
        "MONAN_JEDI_MPIF77": "mpi.mpif77",
        "MONAN_JEDI_MPIF90": "mpi.mpif90",
        "MONAN_JEDI_MODEL_DOUBLE_PRECISION": "model.double_precision",
        "MONAN_JEDI_DATA_ROOT": "data.root",
        "MONAN_JEDI_DATA_LOCAL_ROOT": "data.local_root",
        "MONAN_JEDI_DATA_DOWNLOAD_MISSING": "data.download_missing",
        "MONAN_JEDI_CRTM_COEFFS_URL": "data.crtm_coeffs_url",
        "MONAN_JEDI_CRTM_COEFFS_TGZ": "data.crtm_coeffs_tgz",
        "MONAN_JEDI_OBS2IODA_ENABLED": "obs2ioda.enabled",
        "MONAN_JEDI_OBS2IODA_REPO": "obs2ioda.repo",
        "MONAN_JEDI_OBS2IODA_REF": "obs2ioda.ref",
        "MONAN_JEDI_OBS2IODA_SOURCE_DIR": "obs2ioda.source_dir",
        "MONAN_JEDI_OBS2IODA_BUILD_DIR": "obs2ioda.build_dir",
        "MONAN_JEDI_OBS2IODA_INSTALL_DIR": "obs2ioda.install_dir",
        "MONAN_JEDI_OBS2IODA_EXECUTABLE_NAME": "obs2ioda.executable_name",
        "MONAN_JEDI_OBS2IODA_BUFR_ROOT": "obs2ioda.bufr_root",
        "MONAN_JEDI_OBS2IODA_BUFR_LIB": "obs2ioda.bufr_lib",
        "MONAN_JEDI_OBS2IODA_CMAKE_PREFIX_PATH": "obs2ioda.cmake_prefix_path",
        "MONAN_JEDI_OBS2IODA_BUILD_TYPE": "obs2ioda.build_type",
        "MONAN_JEDI_OBS2IODA_BUILD_GOES_ABI_CONVERTER": "obs2ioda.build_goes_abi_converter",
        "MONAN_JEDI_WPS_ENABLED": "wps.enabled",
        "MONAN_JEDI_WPS_REPO": "wps.repo",
        "MONAN_JEDI_WPS_REF": "wps.ref",
        "MONAN_JEDI_WPS_VERSION": "wps.version",
        "MONAN_JEDI_WPS_SOURCE_DIR": "wps.source_dir",
        "MONAN_JEDI_WPS_BUILD_DIR": "wps.build_dir",
        "MONAN_JEDI_WPS_RELEASES_DIR": "wps.releases_dir",
        "MONAN_JEDI_WPS_INSTALL_DIR": "wps.install_dir",
        "MONAN_JEDI_WPS_PATCH_DIR": "wps.patch_dir",
        "MONAN_JEDI_WPS_JASPER_ROOT": "wps.jasper_root",
        "MONAN_JEDI_WPS_PNG_ROOT": "wps.png_root",
        "MONAN_JEDI_WPS_ZLIB_ROOT": "wps.zlib_root",
        "MONAN_JEDI_WPS_CMAKE_PREFIX_PATH": "wps.cmake_prefix_path",
        "MONAN_JEDI_WPS_BUILD_TYPE": "wps.build_type",
        "MONAN_JEDI_WPS_UNGRIB_NAME": "wps.ungrib_name",
        "MONAN_JEDI_WPS_LINK_GRIB_NAME": "wps.link_grib_name",
        "MONAN_JEDI_WPS_DEFAULT_VTABLE": "wps.default_vtable",
        "MONAN_JEDI_CTEST_REGEX": "ctest.login_regex",
        "MONAN_JEDI_CTEST_PBS_REGEX": "ctest.pbs_regex",
        "MONAN_JEDI_CTEST_EXCLUDE_REGEX": "ctest.exclude_regex",
        "MONAN_JEDI_CTEST_JOBS": "ctest.jobs",
        "ALLOW_LOGIN_NODE_MPI_TESTS": "ctest.allow_login_node_mpi_tests",
        "MONAN_JEDI_PBS_QUEUE": "pbs.queue",
        "MONAN_JEDI_PBS_NCPUS": "pbs.ncpus",
        "MONAN_JEDI_PBS_WALLTIME": "pbs.walltime",
        "MONAN_JEDI_SUBMIT_JOB": "pbs.submit_job",
    }

    defaults = {
        "STACK_OWNER": os.environ.get("USER", "unknown"),
        "STACK_SITE_SETUP": "configs/sites/tier2/jaci/setup.sh",
        "MONAN_JEDI_BUILD_JOBS": "8",
        "MONAN_JEDI_CC": "cc",
        "MONAN_JEDI_CXX": "CC",
        "MONAN_JEDI_FC": "ftn",
        "MONAN_JEDI_F77": "ftn",
        "MONAN_JEDI_F90": "ftn",
        "MONAN_JEDI_MPICC": "cc",
        "MONAN_JEDI_MPICXX": "CC",
        "MONAN_JEDI_MPIFC": "ftn",
        "MONAN_JEDI_MPIF77": "ftn",
        "MONAN_JEDI_MPIF90": "ftn",
        "MONAN_JEDI_MODEL_DOUBLE_PRECISION": "ON",
        "MONAN_JEDI_DATA_DOWNLOAD_MISSING": "1",
        "MONAN_JEDI_CRTM_COEFFS_URL": "https://bin.ssec.wisc.edu/pub/s4/CRTM/fix_REL-3.1.2.0.tgz",
        "MONAN_JEDI_OBS2IODA_ENABLED": "0",
        "MONAN_JEDI_OBS2IODA_REPO": "https://github.com/NCAR/obs2ioda.git",
        "MONAN_JEDI_OBS2IODA_REF": "main",
        "MONAN_JEDI_OBS2IODA_EXECUTABLE_NAME": "obs2ioda_v3",
        "MONAN_JEDI_OBS2IODA_BUILD_TYPE": "Release",
        "MONAN_JEDI_OBS2IODA_BUILD_GOES_ABI_CONVERTER": "OFF",
        "MONAN_JEDI_WPS_ENABLED": "0",
        "MONAN_JEDI_WPS_REPO": "https://github.com/wrf-model/WPS.git",
        "MONAN_JEDI_WPS_REF": "335c76a111f84503e8b963abaf273ea8053645bb",
        "MONAN_JEDI_WPS_VERSION": "4.6.0",
        "MONAN_JEDI_WPS_BUILD_TYPE": "Release",
        "MONAN_JEDI_WPS_UNGRIB_NAME": "ungrib.exe",
        "MONAN_JEDI_WPS_LINK_GRIB_NAME": "link_grib.csh",
        "MONAN_JEDI_WPS_DEFAULT_VTABLE": "Vtable.GFS",
        "MONAN_JEDI_CTEST_JOBS": "1",
        "MONAN_JEDI_PBS_QUEUE": "pesqmini",
        "MONAN_JEDI_PBS_NCPUS": "64",
        "MONAN_JEDI_PBS_WALLTIME": "00:30:00",
        "MONAN_JEDI_SUBMIT_JOB": "1",
    }

    for env_name, yaml_path in mapping.items():
        emit(env_name, get_value(data, yaml_path, defaults.get(env_name, "")))

    return 0


if __name__ == "__main__":
    sys.exit(main())
