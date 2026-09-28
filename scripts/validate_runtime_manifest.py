#!/usr/bin/env python3
"""Validate the installed MONAN-JEDI ecosystem runtime contract v2."""

from __future__ import annotations

import argparse
import json
from pathlib import Path, PurePosixPath


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


def _require_string(mapping: dict[str, object], key: str) -> str:
    value = mapping.get(key)
    if not isinstance(value, str) or not value:
        raise ValueError(f"{key} must be a non-empty string")
    return value


def _resolve_module_root(stack_root: Path, raw: str) -> Path:
    candidate = Path(raw).expanduser()
    return candidate if candidate.is_absolute() else stack_root / candidate


def validate(payload: dict[str, object], install_root: Path) -> None:
    if payload.get("schema_version") != 2:
        raise ValueError("schema_version must be 2")
    if payload.get("ecosystem_contract_version") != 2:
        raise ValueError("ecosystem_contract_version must be 2")
    if payload.get("contract") != "monan-jedi-runtime-v2":
        raise ValueError("unsupported runtime contract identifier")
    if payload.get("public_anchors") != ["MONAN_JEDI_INSTALL_ROOT", "STACK_ROOT"]:
        raise ValueError(
            "public_anchors must contain only MONAN_JEDI_INSTALL_ROOT and STACK_ROOT"
        )
    if "install_root" in payload or "public_contract" in payload:
        raise ValueError("runtime contract must not publish legacy absolute-root fields")

    layout = payload.get("layout")
    if not isinstance(layout, dict):
        raise ValueError("layout must be an object")
    for key, expected in EXPECTED_LAYOUT.items():
        if layout.get(key) != expected:
            raise ValueError(
                f"layout.{key} mismatch: {layout.get(key)!r} != {expected!r}"
            )

    stack = payload.get("stack")
    if not isinstance(stack, dict):
        raise ValueError("stack must be an object")
    _require_string(stack, "env_name")
    _require_string(stack, "env_module")
    site_setup = _require_string(stack, "site_setup")
    module_root = _require_string(stack, "module_root")
    if "module_root_template" in stack:
        raise ValueError("module_root_template is not part of contract v2")

    if Path(site_setup).is_absolute():
        raise ValueError("stack.site_setup must be relative to STACK_ROOT")
    if ".." in PurePosixPath(site_setup).parts:
        raise ValueError("stack.site_setup must not escape STACK_ROOT")

    # module_root may be relative to STACK_ROOT or absolute when a legitimate
    # site override places the module tree elsewhere. Its syntax must be a
    # concrete path, never a format template.
    if "{" in module_root or "}" in module_root:
        raise ValueError("stack.module_root must be a concrete path")

    capabilities = payload.get("capabilities")
    if not isinstance(capabilities, dict):
        raise ValueError("capabilities must be an object")
    for key in ("mpas", "mpas_jedi", "wps", "obs2ioda"):
        if not isinstance(capabilities.get(key), bool):
            raise ValueError(f"capabilities.{key} must be boolean")

    executables = payload.get("canonical_executables")
    if not isinstance(executables, list) or not all(
        isinstance(name, str) and name for name in executables
    ):
        raise ValueError("canonical_executables must be a list of non-empty strings")
    for name in executables:
        path = install_root / "bin" / name
        if not path.exists():
            raise ValueError(f"canonical executable is missing: {path}")

    support = payload.get("runtime_support")
    if not isinstance(support, list) or not all(
        isinstance(item, str) and item for item in support
    ):
        raise ValueError("runtime_support must be a list of non-empty strings")
    for relative in support:
        if "ufo/testinput_tier_1" in relative:
            raise ValueError("scientific observations must not be runtime_support")
        path = install_root / relative
        if not path.is_file():
            raise ValueError(f"runtime support is missing: {path}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--install-root", required=True)
    args = parser.parse_args()

    manifest = Path(args.manifest)
    install_root = Path(args.install_root)
    payload = json.loads(manifest.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("runtime contract root must be a JSON object")
    validate(payload, install_root)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
