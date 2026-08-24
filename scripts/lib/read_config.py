#!/usr/bin/env python3
"""Read a MONAN-JEDI YAML configuration and emit shell export commands.

Purpose
-------
This helper is the YAML boundary used by ``scripts/lib/config.sh``. Its output
is intended to be evaluated by the caller:

    eval "$(python3 scripts/lib/read_config.py config.yaml)"

Configuration model
-------------------
The YAML root must be a mapping. Supported sections are ``project``, ``stack``,
``build``, ``install``, ``model``, ``data``, ``obs2ioda``, ``wps``,
``compilers``, ``mpi``, ``ctest`` and ``pbs``. The top-level ``site`` key is
descriptive metadata and is intentionally not exported.

Environment precedence
----------------------
For each supported variable, values are resolved in this order:

1. Existing environment variable, including an explicitly empty value.
2. Value declared in the YAML configuration.
3. Built-in default.
4. Empty string when no configured value or default exists.

Value conversion
----------------
YAML booleans become shell-friendly values (``true`` -> ``1`` and ``false`` ->
``0``). Environment-variable references inside YAML strings are expanded using
the current process environment. Lists and mappings are rejected because the
shell export contract accepts scalar values only. Values are safely quoted with
``shlex.quote`` before emission, preserving spaces and shell metacharacters.

Division of responsibility
--------------------------
This module maps individual YAML values and owns context-free defaults.
``config.sh`` derives values that depend on multiple settings, such as work,
log and installation paths. The canonical user-facing configuration reference
is ``docs/YAML_CONFIGURATION.md``.

Compatibility
-------------
This script must remain compatible with Python 3.6 because JACI compute nodes
may execute it before the spack-stack environment is loaded. Use types from
``typing`` and avoid syntax introduced by newer Python releases.

Output and errors
-----------------
Standard output contains only safely quoted ``export NAME=value`` commands.
Diagnostics are written to standard error. A processing failure returns status
1; invalid command-line usage is handled by argparse with status 2.
"""

import argparse
import os
import shlex
import sys
from collections.abc import Mapping as MappingABC
from pathlib import Path
from typing import Any, Dict, List, Mapping, Optional, TextIO

try:
    import yaml
except ImportError:
    sys.stderr.write(
        "Error: PyYAML is required.\n"
        "Activate the MONAN-JEDI Python environment or install PyYAML.\n"
    )
    sys.exit(1)


# Type used to represent the loaded YAML configuration.
Config = Mapping[str, Any]


# Maps environment-variable names to dotted YAML paths. For example,
# "build.jobs" represents configuration["build"]["jobs"]. Keep this table
# synchronized with config/template.yaml and docs/YAML_CONFIGURATION.md.
VARIABLE_MAPPING = {
    # Project
    "PROJECT_ROOT": "project.root",

    # spack-stack
    "STACK_OWNER": "stack.owner",
    "STACK_INSTANCE": "stack.instance",
    "STACK_WORK_ROOT": "stack.work_root",
    "STACK_ROOT": "stack.root",
    "STACK_ENV_NAME": "stack.env_name",
    "STACK_MODULE_ROOT": "stack.module_root",
    "STACK_SITE_SETUP": "stack.site_setup",
    "STACK_ENV_MODULE": "stack.env_module",

    # MONAN-JEDI build
    "MONAN_JEDI_RUN_ID": "build.id",
    "MONAN_JEDI_BUILD_DIR": "build.dir",
    "MONAN_JEDI_BUILD_JOBS": "build.jobs",

    # MONAN-JEDI installation
    "MONAN_JEDI_INSTALL_ROOT": "install.root",
    "MONAN_JEDI_INSTALL_BIN_DIR": "install.bin_dir",

    # Compilers
    "MONAN_JEDI_CC": "compilers.cc",
    "MONAN_JEDI_CXX": "compilers.cxx",
    "MONAN_JEDI_FC": "compilers.fc",
    "MONAN_JEDI_F77": "compilers.f77",
    "MONAN_JEDI_F90": "compilers.f90",

    # MPI compiler wrappers
    "MONAN_JEDI_MPICC": "mpi.mpicc",
    "MONAN_JEDI_MPICXX": "mpi.mpicxx",
    "MONAN_JEDI_MPIFC": "mpi.mpifc",
    "MONAN_JEDI_MPIF77": "mpi.mpif77",
    "MONAN_JEDI_MPIF90": "mpi.mpif90",

    # Model configuration
    "MONAN_JEDI_MODEL_DOUBLE_PRECISION": "model.double_precision",

    # Runtime and coefficient data
    "MONAN_JEDI_DATA_ROOT": "data.root",
    "MONAN_JEDI_DATA_LOCAL_ROOT": "data.local_root",
    "MONAN_JEDI_DATA_DOWNLOAD_MISSING": "data.download_missing",
    "MONAN_JEDI_CRTM_COEFFS_URL": "data.crtm_coeffs_url",
    "MONAN_JEDI_CRTM_COEFFS_TGZ": "data.crtm_coeffs_tgz",

    # obs2ioda
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

    # WPS
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

    # CTest
    "MONAN_JEDI_CTEST_REGEX": "ctest.login_regex",
    "MONAN_JEDI_CTEST_PBS_REGEX": "ctest.pbs_regex",
    "MONAN_JEDI_CTEST_EXCLUDE_REGEX": "ctest.exclude_regex",
    "MONAN_JEDI_CTEST_JOBS": "ctest.jobs",
    "ALLOW_LOGIN_NODE_MPI_TESTS": "ctest.allow_login_node_mpi_tests",

    # PBS
    "MONAN_JEDI_PBS_QUEUE": "pbs.queue",
    "MONAN_JEDI_PBS_NCPUS": "pbs.ncpus",
    "MONAN_JEDI_PBS_WALLTIME": "pbs.walltime",
    "MONAN_JEDI_SUBMIT_JOB": "pbs.submit_job",
}


# Context-free values used when a variable is absent from the environment and
# YAML. Variables not listed here default to an empty string. Defaults derived
# from other settings remain in scripts/lib/config.sh.
DEFAULTS = {
    # spack-stack
    "STACK_OWNER": os.environ.get("USER", "unknown"),
    "STACK_SITE_SETUP": "configs/sites/tier2/jaci/setup.sh",

    # Build
    "MONAN_JEDI_BUILD_JOBS": "8",

    # Compilers
    "MONAN_JEDI_CC": "cc",
    "MONAN_JEDI_CXX": "CC",
    "MONAN_JEDI_FC": "ftn",
    "MONAN_JEDI_F77": "ftn",
    "MONAN_JEDI_F90": "ftn",

    # MPI compiler wrappers
    "MONAN_JEDI_MPICC": "cc",
    "MONAN_JEDI_MPICXX": "CC",
    "MONAN_JEDI_MPIFC": "ftn",
    "MONAN_JEDI_MPIF77": "ftn",
    "MONAN_JEDI_MPIF90": "ftn",

    # Model
    "MONAN_JEDI_MODEL_DOUBLE_PRECISION": "ON",

    # Data
    "MONAN_JEDI_DATA_DOWNLOAD_MISSING": "1",
    "MONAN_JEDI_CRTM_COEFFS_URL": "https://bin.ssec.wisc.edu/pub/s4/CRTM/fix_REL-3.1.2.0.tgz",

    # obs2ioda
    "MONAN_JEDI_OBS2IODA_ENABLED": "0",
    "MONAN_JEDI_OBS2IODA_REPO": "https://github.com/NCAR/obs2ioda.git",
    "MONAN_JEDI_OBS2IODA_REF": "main",
    "MONAN_JEDI_OBS2IODA_EXECUTABLE_NAME": "obs2ioda_v3",
    "MONAN_JEDI_OBS2IODA_BUILD_TYPE": "Release",
    "MONAN_JEDI_OBS2IODA_BUILD_GOES_ABI_CONVERTER": "OFF",

    # WPS
    "MONAN_JEDI_WPS_ENABLED": "0",
    "MONAN_JEDI_WPS_REPO": "https://github.com/wrf-model/WPS.git",
    "MONAN_JEDI_WPS_REF": "335c76a111f84503e8b963abaf273ea8053645bb",
    "MONAN_JEDI_WPS_VERSION": "4.6.0",
    "MONAN_JEDI_WPS_BUILD_TYPE": "Release",
    "MONAN_JEDI_WPS_UNGRIB_NAME": "ungrib.exe",
    "MONAN_JEDI_WPS_LINK_GRIB_NAME": "link_grib.csh",
    "MONAN_JEDI_WPS_DEFAULT_VTABLE": "Vtable.GFS",

    # CTest
    "MONAN_JEDI_CTEST_JOBS": "1",

    # PBS
    "MONAN_JEDI_PBS_QUEUE": "pesqmini",
    "MONAN_JEDI_PBS_NCPUS": "64",
    "MONAN_JEDI_PBS_WALLTIME": "03:00:00",
    "MONAN_JEDI_SUBMIT_JOB": "1",
}

def parse_arguments(
    argv: Optional[List[str]] = None,
) -> argparse.Namespace:
    """Parse command-line arguments.

    Args:
        argv: Optional argument list. When omitted, argparse uses ``sys.argv``.

    Returns:
        Parsed command-line arguments.
    """
    parser = argparse.ArgumentParser(
        description=(
            "Read a MONAN-JEDI YAML configuration and emit shell exports."
        ),
        epilog='Example: eval "$(python3 read_config.py config.yaml)"',
    )
    parser.add_argument(
        "configuration",
        type=Path,
        metavar="CONFIG",
        help="path to the MONAN-JEDI YAML configuration file",
    )
    return parser.parse_args(argv)


def read_yaml(path: Path) -> Dict[str, Any]:
    """Load and validate a YAML configuration file.

    Empty YAML documents are interpreted as empty mappings.

    Raises:
        OSError: If the file cannot be opened or read.
        yaml.YAMLError: If the file does not contain valid YAML.
        ValueError: If the YAML document root is not a mapping.
    """
    with path.open("r", encoding="utf-8") as stream:
        loaded = yaml.safe_load(stream)

    if loaded is None:
        return {}
    if not isinstance(loaded, dict):
        raise ValueError("the configuration root must be a YAML mapping")
    return loaded


def get_nested_value(
    data: Config,
    dotted_path: str,
    default: Any = "",
) -> Any:
    """Retrieve a nested value through a dotted path.

    ``build.jobs``, for example, accesses ``data["build"]["jobs"]``. The
    supplied default is returned when a component is absent, an intermediate
    value is not a mapping, or the final YAML value is null.
    """
    current = data
    for key in dotted_path.split("."):
        if not isinstance(current, MappingABC) or key not in current:
            return default
        current = current[key]

    return default if current is None else current


def normalize_value(value: Any) -> str:
    """Convert one YAML/default scalar into a shell-compatible string.

    Boolean values become ``1`` or ``0`` and environment references in scalar
    strings are expanded. Lists and mappings are rejected instead of being
    silently serialized as Python representations.
    """
    if value is None:
        return ""
    if isinstance(value, bool):
        return "1" if value else "0"
    if isinstance(value, (list, MappingABC)):
        raise ValueError(
            "lists and mappings cannot be exported as shell variables"
        )
    return os.path.expandvars(str(value))


def resolve_value(env_name: str, yaml_value: Any) -> str:
    """Resolve one value, preserving an existing environment override.

    Membership is tested explicitly so an exported empty value still overrides
    YAML and defaults.
    """
    if env_name in os.environ:
        return os.environ[env_name]
    return normalize_value(yaml_value)


def write_export(stream: TextIO, name: str, value: str) -> None:
    """Write one safely quoted POSIX-shell export command."""
    stream.write("export {0}={1}\n".format(name, shlex.quote(value)))


def emit_configuration(
    data: Config,
    stream: TextIO = sys.stdout,
) -> None:
    """Resolve and emit the complete supported environment-variable contract.

    Raises:
        ValueError: If a configured value is not a supported shell scalar.
    """
    for env_name, yaml_path in VARIABLE_MAPPING.items():
        yaml_value = get_nested_value(
            data=data,
            dotted_path=yaml_path,
            default=DEFAULTS.get(env_name, ""),
        )
        resolved_value = resolve_value(
            env_name=env_name,
            yaml_value=yaml_value,
        )
        write_export(
            stream=stream,
            name=env_name,
            value=resolved_value,
        )


def main(argv: Optional[List[str]] = None) -> int:
    """Run the command-line application.

    Returns:
        Zero on success or one when configuration processing fails. Argparse
        terminates with status two for invalid command-line usage.
    """
    args = parse_arguments(argv)

    try:
        data = read_yaml(args.configuration)
        emit_configuration(data)
    except BrokenPipeError:
        # Consumers such as ``head`` may close the output pipe early.
        return 0
    except (OSError, ValueError, yaml.YAMLError) as exc:
        sys.stderr.write(
            "Error: could not process configuration {0}: {1}\n".format(
                args.configuration,
                exc,
            )
        )
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
