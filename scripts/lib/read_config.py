#!/usr/bin/env python3
"""Read and validate MONAN-JEDI build/install configuration.

This module is the single source of truth for the public YAML configuration
interface. It defines supported keys, types, defaults, allowed values and the
shell variables exported for the workflow.

The YAML intentionally contains only site/user decisions. Derived filesystem
paths and private implementation details are computed by scripts/lib/config.sh.
Advanced diagnostics may still override those derived shell variables directly.

Precedence for public settings is:

1. non-empty environment variable;
2. YAML value;
3. default declared in CONFIG_FIELDS.

Empty environment variables do not mask YAML/default values. This matches the
shell derivation rules and avoids the historical ambiguity between the Python
loader and config.sh.

The script must remain compatible with Python 3.6 because it can run before the
JACI spack-stack environment is loaded.
"""

import argparse
import os
import re
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


Config = Mapping[str, Any]
_MISSING = object()

OBS2IODA_PIN = "11b9e60522d63bc03b0b104a52f3dd22127fb828"
WPS_PIN = "335c76a111f84503e8b963abaf273ea8053645bb"

# Public YAML interface. Each entry defines one user-facing key. Multiple
# environment names allow one concise YAML value to feed compatibility aliases
# such as FC/F77/F90 without exposing those aliases as duplicate YAML keys.
CONFIG_FIELDS = (
    {"path": "site", "envs": (), "kind": "str", "required": True},
    {"path": "project.root", "envs": ("PROJECT_ROOT",), "kind": "str", "required": True},
    {"path": "stack.owner", "envs": ("STACK_OWNER",), "kind": "str", "default": lambda: os.environ.get("USER", "unknown")},
    {"path": "stack.instance", "envs": ("STACK_INSTANCE",), "kind": "str", "required": True},
    {"path": "stack.env_name", "envs": ("STACK_ENV_NAME",), "kind": "str", "required": True},
    {"path": "stack.site_setup", "envs": ("STACK_SITE_SETUP",), "kind": "str", "default": "configs/sites/tier2/jaci/setup.sh"},
    {"path": "stack.env_module", "envs": ("STACK_ENV_MODULE",), "kind": "str", "required": True},
    {"path": "build.id", "envs": ("MONAN_JEDI_BUILD_ID",), "kind": "str", "required": True},
    {"path": "build.jobs", "envs": ("MONAN_JEDI_BUILD_JOBS",), "kind": "int", "default": 8, "minimum": 1},
    {"path": "model.double_precision", "envs": ("MONAN_JEDI_MODEL_DOUBLE_PRECISION",), "kind": "str", "default": "ON", "choices": ("ON", "OFF")},
    {"path": "data.local_mirror_dir", "envs": ("MONAN_JEDI_DATA_LOCAL_ROOT",), "kind": "str", "default": ""},
    {"path": "data.download_missing", "envs": ("MONAN_JEDI_DATA_DOWNLOAD_MISSING",), "kind": "bool", "default": True},
    {"path": "obs2ioda.enabled", "envs": ("MONAN_JEDI_OBS2IODA_ENABLED",), "kind": "bool", "default": False},
    {"path": "obs2ioda.ref", "envs": ("MONAN_JEDI_OBS2IODA_REF",), "kind": "str", "default": OBS2IODA_PIN, "pattern": r"^[0-9a-f]{40}$"},
    {"path": "obs2ioda.bufr_root", "envs": ("MONAN_JEDI_OBS2IODA_BUFR_ROOT",), "kind": "str", "default": ""},
    {"path": "obs2ioda.bufr_lib", "envs": ("MONAN_JEDI_OBS2IODA_BUFR_LIB",), "kind": "str", "default": ""},
    {"path": "obs2ioda.cmake_prefix_path", "envs": ("MONAN_JEDI_OBS2IODA_CMAKE_PREFIX_PATH",), "kind": "str", "default": ""},
    {"path": "obs2ioda.build_type", "envs": ("MONAN_JEDI_OBS2IODA_BUILD_TYPE",), "kind": "str", "default": "Release", "choices": ("Release", "Debug", "RelWithDebInfo", "MinSizeRel")},
    {"path": "obs2ioda.build_goes_abi_converter", "envs": ("MONAN_JEDI_OBS2IODA_BUILD_GOES_ABI_CONVERTER",), "kind": "str", "default": "OFF", "choices": ("ON", "OFF")},
    {"path": "wps.enabled", "envs": ("MONAN_JEDI_WPS_ENABLED",), "kind": "bool", "default": False},
    {"path": "wps.ref", "envs": ("MONAN_JEDI_WPS_REF",), "kind": "str", "default": WPS_PIN, "pattern": r"^[0-9a-f]{40}$"},
    {"path": "wps.version", "envs": ("MONAN_JEDI_WPS_VERSION",), "kind": "str", "default": "4.6.0"},
    {"path": "wps.jasper_root", "envs": ("MONAN_JEDI_WPS_JASPER_ROOT",), "kind": "str", "default": ""},
    {"path": "wps.png_root", "envs": ("MONAN_JEDI_WPS_PNG_ROOT",), "kind": "str", "default": ""},
    {"path": "wps.zlib_root", "envs": ("MONAN_JEDI_WPS_ZLIB_ROOT",), "kind": "str", "default": ""},
    {"path": "wps.cmake_prefix_path", "envs": ("MONAN_JEDI_WPS_CMAKE_PREFIX_PATH",), "kind": "str", "default": ""},
    {"path": "wps.build_type", "envs": ("MONAN_JEDI_WPS_BUILD_TYPE",), "kind": "str", "default": "Release", "choices": ("Release", "Debug", "RelWithDebInfo", "MinSizeRel")},
    {"path": "wps.default_vtable", "envs": ("MONAN_JEDI_WPS_DEFAULT_VTABLE",), "kind": "str", "default": "Vtable.GFS", "pattern": r"^[A-Za-z0-9._-]+$"},
    {"path": "compilers.cc", "envs": ("MONAN_JEDI_CC",), "kind": "str", "default": "cc"},
    {"path": "compilers.cxx", "envs": ("MONAN_JEDI_CXX",), "kind": "str", "default": "CC"},
    {"path": "compilers.fortran", "envs": ("MONAN_JEDI_FC", "MONAN_JEDI_F77", "MONAN_JEDI_F90"), "kind": "str", "default": "ftn"},
    {"path": "mpi.cc", "envs": ("MONAN_JEDI_MPICC",), "kind": "str", "default": "cc"},
    {"path": "mpi.cxx", "envs": ("MONAN_JEDI_MPICXX",), "kind": "str", "default": "CC"},
    {"path": "mpi.fortran", "envs": ("MONAN_JEDI_MPIFC", "MONAN_JEDI_MPIF77", "MONAN_JEDI_MPIF90"), "kind": "str", "default": "ftn"},
    {"path": "ctest.login_regex", "envs": ("MONAN_JEDI_CTEST_REGEX",), "kind": "str", "default": "^mpasjedi_coding_norms$"},
    {"path": "ctest.pbs_regex", "envs": ("MONAN_JEDI_CTEST_PBS_REGEX",), "kind": "str", "default": ""},
    {"path": "ctest.exclude_regex", "envs": ("MONAN_JEDI_CTEST_EXCLUDE_REGEX",), "kind": "str", "default": ""},
    {"path": "ctest.jobs", "envs": ("MONAN_JEDI_CTEST_JOBS",), "kind": "int", "default": 1, "minimum": 1},
    {"path": "ctest.allow_login_node_mpi_tests", "envs": ("ALLOW_LOGIN_NODE_MPI_TESTS",), "kind": "bool", "default": False},
    {"path": "pbs.queue", "envs": ("MONAN_JEDI_PBS_QUEUE",), "kind": "str", "default": "pesqmidi"},
    {"path": "pbs.ncpus", "envs": ("MONAN_JEDI_PBS_NCPUS",), "kind": "int", "default": 64, "minimum": 1},
    {"path": "pbs.walltime", "envs": ("MONAN_JEDI_PBS_WALLTIME",), "kind": "str", "default": "02:00:00", "pattern": r"^\d{2,3}:[0-5]\d:[0-5]\d$"},
    {"path": "pbs.submit_job", "envs": ("MONAN_JEDI_SUBMIT_JOB",), "kind": "bool", "default": False},
)

# Fixed implementation defaults. They remain overridable through non-empty
# environment variables, but they are deliberately not part of the YAML API.
INTERNAL_DEFAULTS = (
    ("MONAN_JEDI_CRTM_COEFFS_URL", "https://bin.ssec.wisc.edu/pub/s4/CRTM/fix_REL-3.1.2.0.tgz"),
    ("MONAN_JEDI_OBS2IODA_REPO", "https://github.com/NCAR/obs2ioda.git"),
    ("MONAN_JEDI_OBS2IODA_EXECUTABLE_NAME", "obs2ioda_v3"),
    ("MONAN_JEDI_WPS_REPO", "https://github.com/wrf-model/WPS.git"),
    ("MONAN_JEDI_WPS_UNGRIB_NAME", "ungrib.exe"),
    ("MONAN_JEDI_WPS_LINK_GRIB_NAME", "link_grib.csh"),
)


def parse_arguments(argv=None):
    parser = argparse.ArgumentParser(
        description="Read and validate a MONAN-JEDI YAML configuration."
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="validate the configuration without emitting shell exports",
    )
    parser.add_argument("configuration", type=Path, metavar="CONFIG")
    return parser.parse_args(argv)


def read_yaml(path):
    with path.open("r", encoding="utf-8") as stream:
        loaded = yaml.safe_load(stream)
    if loaded is None:
        return {}
    if not isinstance(loaded, dict):
        raise ValueError("the configuration root must be a YAML mapping")
    return loaded


def get_nested_value(data, dotted_path, default=_MISSING):
    current = data
    for key in dotted_path.split("."):
        if not isinstance(current, MappingABC) or key not in current:
            return default
        current = current[key]
    return current


def supported_yaml_paths():
    return tuple(field["path"] for field in CONFIG_FIELDS)


def _allowed_prefixes():
    prefixes = set()
    for path in supported_yaml_paths():
        parts = path.split(".")
        for index in range(1, len(parts)):
            prefixes.add(".".join(parts[:index]))
    return prefixes


def validate_unknown_keys(data):
    allowed = set(supported_yaml_paths())
    prefixes = _allowed_prefixes()

    def visit(value, prefix=""):
        if not isinstance(value, MappingABC):
            return
        for key, child in value.items():
            path = "{0}.{1}".format(prefix, key) if prefix else str(key)
            if path not in allowed and path not in prefixes:
                raise ValueError("unknown configuration key: {0}".format(path))
            if isinstance(child, MappingABC):
                visit(child, path)

    visit(data)


def _default_value(field):
    default = field.get("default", _MISSING)
    if callable(default):
        return default()
    return default


def _normalize_bool(value, path):
    if isinstance(value, bool):
        return "1" if value else "0"
    if isinstance(value, str):
        lowered = value.strip().lower()
        if lowered in ("1", "true", "yes", "on"):
            return "1"
        if lowered in ("0", "false", "no", "off"):
            return "0"
    raise ValueError("{0} must be a boolean".format(path))


def normalize_field_value(field, value):
    path = field["path"]
    kind = field["kind"]

    if value is None:
        value = _MISSING

    if value is _MISSING:
        value = _default_value(field)

    if value is _MISSING:
        if field.get("required"):
            raise ValueError("required configuration key is missing: {0}".format(path))
        value = ""

    if kind == "bool":
        normalized = _normalize_bool(value, path)
    elif kind == "int":
        if isinstance(value, bool):
            raise ValueError("{0} must be an integer".format(path))
        try:
            integer = int(value)
        except (TypeError, ValueError):
            raise ValueError("{0} must be an integer".format(path))
        minimum = field.get("minimum")
        if minimum is not None and integer < minimum:
            raise ValueError("{0} must be >= {1}".format(path, minimum))
        normalized = str(integer)
    elif kind == "str":
        if not isinstance(value, str):
            raise ValueError("{0} must be a string".format(path))
        normalized = os.path.expandvars(value)
    else:
        raise ValueError("internal error: unsupported type for {0}".format(path))

    if field.get("required") and normalized == "":
        raise ValueError("required configuration key is empty: {0}".format(path))

    choices = field.get("choices")
    if choices and normalized not in choices:
        raise ValueError(
            "{0} must be one of: {1}".format(path, ", ".join(choices))
        )

    pattern = field.get("pattern")
    if pattern and normalized and re.match(pattern, normalized) is None:
        raise ValueError(
            "{0} has invalid format: {1}".format(path, normalized)
        )

    return normalized


def write_export(stream, name, value):
    stream.write("export {0}={1}\n".format(name, shlex.quote(value)))


def emit_configuration(data, stream=sys.stdout):
    validate_unknown_keys(data)

    for field in CONFIG_FIELDS:
        yaml_value = get_nested_value(data, field["path"], _MISSING)
        baseline = normalize_field_value(field, yaml_value)

        for env_name in field["envs"]:
            env_value = os.environ.get(env_name, "")
            resolved = normalize_field_value(field, env_value) if env_value else baseline
            write_export(stream, env_name, resolved)

    for env_name, default in INTERNAL_DEFAULTS:
        value = os.environ.get(env_name, "") or default
        write_export(stream, env_name, os.path.expandvars(value))


def validate_configuration(data):
    sink = _NullWriter()
    emit_configuration(data, stream=sink)


class _NullWriter(object):
    def write(self, value):
        return len(value)


def main(argv=None):
    args = parse_arguments(argv)
    try:
        data = read_yaml(args.configuration)
        if args.check:
            validate_configuration(data)
        else:
            emit_configuration(data)
    except BrokenPipeError:
        return 0
    except (OSError, ValueError, yaml.YAMLError) as exc:
        sys.stderr.write(
            "Error: could not process configuration {0}: {1}\n".format(
                args.configuration, exc
            )
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
