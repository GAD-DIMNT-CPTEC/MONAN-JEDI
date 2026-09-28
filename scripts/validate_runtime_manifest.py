#!/usr/bin/env python3
"""Validate a MONAN-JEDI ecosystem runtime contract v2."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


EXPECTED_LAYOUT = {
    "bin": "bin",
    "lib": "lib",
    "include": "include",
    "share": "share",
    "mpas_atmosphere_share": "share/MPAS/core_atmosphere",
    "wps_variable_tables": "share/wps/Variable_Tables",
    "mpas_jedi_namelists": "share/monan-jedi/mpas-jedi/namelists",
    "mpas_jedi_testinput": "share/monan-jedi/mpas-jedi/testinput",
}


def validate(manifest: Path, install_root: Path) -> None:
    payload = json.loads(manifest.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("runtime contract root must be a JSON object")
    if payload.get("schema_version") != 2:
        raise ValueError("schema_version must be 2")
    if payload.get("ecosystem_contract_version") != 2:
        raise ValueError("ecosystem_contract_version must be 2")
    if payload.get("contract") != "monan-jedi-runtime-v2":
        raise ValueError("unsupported runtime contract identifier")
    if payload.get("public_anchors") != ["MONAN_JEDI_INSTALL_ROOT", "STACK_ROOT"]:
        raise ValueError("unexpected public_anchors")
    if "install_root" in payload or "public_contract" in payload:
        raise ValueError("runtime contract must be relocatable")

    layout = payload.get("layout")
    if not isinstance(layout, dict):
        raise ValueError("layout must be an object")
    for key, expected in EXPECTED_LAYOUT.items():
        if layout.get(key) != expected:
            raise ValueError(
                f"layout.{key} mismatch: {layout.get(key)!r} != {expected!r}"
            )
    if any("ufo" in str(value).lower() for value in layout.values()):
        raise ValueError("scientific observations must not be in public layout")

    stack = payload.get("stack")
    if not isinstance(stack, dict):
        raise ValueError("stack must be an object")
    for key in ("env_name", "env_module", "site_setup", "module_root_template"):
        value = stack.get(key)
        if not isinstance(value, str) or not value:
            raise ValueError(f"stack.{key} must be a non-empty string")
    if Path(stack["site_setup"]).is_absolute():
        raise ValueError("stack.site_setup must be relative to STACK_ROOT")
    if Path(stack["module_root_template"]).is_absolute():
        raise ValueError("stack.module_root_template must be relative to STACK_ROOT")
    if "{env_name}" not in stack["module_root_template"]:
        raise ValueError("stack.module_root_template must contain {env_name}")

    capabilities = payload.get("capabilities")
    if not isinstance(capabilities, dict):
        raise ValueError("capabilities must be an object")
    for key in ("mpas", "mpas_jedi", "wps", "obs2ioda"):
        if not isinstance(capabilities.get(key), bool):
            raise ValueError(f"capabilities.{key} must be boolean")

    executables = payload.get("canonical_executables")
    if not isinstance(executables, list) or not all(
        isinstance(item, str) and item for item in executables
    ):
        raise ValueError("canonical_executables must be a list of non-empty strings")
    for name in executables:
        path = install_root / "bin" / name
        if not path.exists():
            raise ValueError(f"manifest executable is missing: {path}")

    support = payload.get("required_runtime_support")
    if not isinstance(support, list) or not all(
        isinstance(item, str) and item for item in support
    ):
        raise ValueError("required_runtime_support must be a list of non-empty strings")
    if any("ufo/testinput_tier_1" in item for item in support):
        raise ValueError("scientific observations must not be required runtime support")
    for relative in support:
        path = install_root / relative
        if not path.is_file():
            raise ValueError(f"required runtime support is missing: {path}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--install-root", required=True)
    args = parser.parse_args()
    validate(Path(args.manifest), Path(args.install_root))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
