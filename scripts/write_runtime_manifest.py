#!/usr/bin/env python3
"""Write the MONAN-JEDI ecosystem runtime contract v2.

The manifest is the machine-readable source of truth shared by MONAN-JEDI,
mpaswf, monan-jedi-workflow and MPAS-BMatrix.  It is relocatable: paths are
relative to MONAN_JEDI_INSTALL_ROOT and the selected STACK_ROOT is never stored
inside the document.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path


def _bool(value: str) -> bool:
    return value.strip().lower() in {"1", "true", "yes", "on"}


def build_contract(args: argparse.Namespace) -> dict[str, object]:
    install_root = Path(args.install_root)

    mpas_names = ["mpas_init_atmosphere", "mpas_atmosphere"]
    mpas_jedi_names = [
        "mpasjedi_variational.x",
        "mpasjedi_error_covariance_toolbox.x",
        "mpasjedi_process_perts.x",
        "mpasjedi_unbalance_ensemble.x",
    ]
    mpas_available = all((install_root / "bin" / name).is_file() for name in mpas_names)
    mpas_jedi_available = all(
        (install_root / "bin" / name).is_file() for name in mpas_jedi_names
    )
    wps_available = (
        (install_root / "bin" / "ungrib.exe").is_file()
        and (install_root / "bin" / "link_grib.csh").is_file()
        and (install_root / "share" / "wps" / "Variable_Tables").is_dir()
    )
    obs2ioda_available = (install_root / "bin" / "obs2ioda_v3").is_file()

    known_executables = [*mpas_names, *mpas_jedi_names]
    if wps_available:
        known_executables.extend(["ungrib.exe", "link_grib.csh"])
    if obs2ioda_available:
        known_executables.append("obs2ioda_v3")

    runtime_support = [
        "share/monan-jedi/mpas-jedi/namelists/geovars.yaml",
        "share/monan-jedi/mpas-jedi/namelists/keptvars.yaml",
        "share/monan-jedi/mpas-jedi/namelists/stream_list.atmosphere.background",
        "share/monan-jedi/mpas-jedi/namelists/stream_list.atmosphere.analysis",
        "share/monan-jedi/mpas-jedi/namelists/stream_list.atmosphere.control",
        "share/monan-jedi/mpas-jedi/namelists/stream_list.atmosphere.ensemble",
        "share/monan-jedi/mpas-jedi/testinput/obsop_name_map.yaml",
    ]

    return {
        "schema_version": 2,
        "ecosystem_contract_version": 2,
        "contract": "monan-jedi-runtime-v2",
        "public_anchors": ["MONAN_JEDI_INSTALL_ROOT", "STACK_ROOT"],
        "layout": {
            "bin": "bin",
            "lib": "lib",
            "include": "include",
            "share": "share",
            "mpas_atmosphere_share": "share/MPAS/core_atmosphere",
            "wps_variable_tables": "share/wps/Variable_Tables",
            "mpas_jedi_namelists": "share/monan-jedi/mpas-jedi/namelists",
            "mpas_jedi_testinput": "share/monan-jedi/mpas-jedi/testinput",
        },
        "runtime_support": runtime_support,
        "stack": {
            "env_name": args.stack_env_name,
            "env_module": args.stack_env_module,
            "site_setup": args.stack_site_setup,
            "module_root_template": "envs/{env_name}/modules",
        },
        "capabilities": {
            "mpas": mpas_available,
            "mpas_jedi": mpas_jedi_available,
            "wps": wps_available,
            "obs2ioda": obs2ioda_available,
        },
        "canonical_executables": sorted(
            name
            for name in known_executables
            if (install_root / "bin" / name).is_file()
        ),
        "producer": {
            "build_id": args.build_id,
            "config": args.config,
            "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
            "requested_wps": _bool(args.wps_enabled),
            "requested_obs2ioda": _bool(args.obs2ioda_enabled),
            "wps_ref": args.wps_ref,
            "obs2ioda_ref": args.obs2ioda_ref,
        },
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    parser.add_argument("--install-root", required=True)
    parser.add_argument("--stack-env-name", required=True)
    parser.add_argument("--stack-env-module", required=True)
    parser.add_argument("--stack-site-setup", required=True)
    parser.add_argument("--build-id", required=True)
    parser.add_argument("--config", default="")
    parser.add_argument("--wps-enabled", default="0")
    parser.add_argument("--obs2ioda-enabled", default="0")
    parser.add_argument("--wps-ref", default="")
    parser.add_argument("--obs2ioda-ref", default="")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(build_contract(args), indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
