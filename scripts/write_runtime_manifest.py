#!/usr/bin/env python3
"""Write the MONAN-JEDI installed runtime contract.

The JSON keeps the producer historical schema-v1 envelope for one compatibility
window while publishing ecosystem_contract_version 2 as the normative
cross-repository contract. New consumers must read the v2 fields.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path


def _bool(value: str) -> bool:
    return value.strip().lower() in {"1", "true", "yes", "on"}


def build_contract(args: argparse.Namespace) -> dict[str, object]:
    executables = [
        "mpas_init_atmosphere",
        "mpas_atmosphere",
        "mpasjedi_variational.x",
        "mpasjedi_error_covariance_toolbox.x",
        "mpasjedi_process_perts.x",
        "mpasjedi_unbalance_ensemble.x",
    ]
    if _bool(args.wps_enabled):
        executables.extend(["ungrib.exe", "link_grib.csh"])
    if _bool(args.obs2ioda_enabled):
        executables.append("obs2ioda_v3")

    public_layout = {
        "bin": "bin",
        "lib": "lib",
        "include": "include",
        "share": "share",
        "mpas_atmosphere_share": "share/MPAS/core_atmosphere",
        "wps_variable_tables": "share/wps/Variable_Tables",
        "mpas_jedi_namelists": "share/monan-jedi/mpas-jedi/namelists",
        "mpas_jedi_testinput": "share/monan-jedi/mpas-jedi/testinput",
    }

    runtime_support = [
        "share/monan-jedi/mpas-jedi/namelists/geovars.yaml",
        "share/monan-jedi/mpas-jedi/namelists/keptvars.yaml",
        "share/monan-jedi/mpas-jedi/namelists/stream_list.atmosphere.background",
        "share/monan-jedi/mpas-jedi/namelists/stream_list.atmosphere.analysis",
        "share/monan-jedi/mpas-jedi/namelists/stream_list.atmosphere.control",
        "share/monan-jedi/mpas-jedi/namelists/stream_list.atmosphere.ensemble",
        "share/monan-jedi/mpas-jedi/testinput/obsop_name_map.yaml",
    ]

    # Compatibility fixtures required only by the producer legacy validator.
    # They are deliberately absent from the v2 public layout.
    compatibility_observations = [
        "share/monan-jedi/ufo/testinput_tier_1/sondes_obs_2018041500_m.nc4",
        "share/monan-jedi/ufo/testinput_tier_1/gnssro_obs_2018041500_s.nc4",
        "share/monan-jedi/ufo/testinput_tier_1/sfc_obs_2018041500_m.nc4",
    ]

    return {
        # Compatibility envelope consumed by the existing producer validator.
        "schema_version": 1,
        "install_root": args.install_root,
        "public_contract": {
            **public_layout,
            "ufo_testinput_tier_1": "share/monan-jedi/ufo/testinput_tier_1",
        },
        "required_runtime_support": runtime_support + compatibility_observations,

        # Normative ecosystem contract.
        "ecosystem_contract_version": 2,
        "contract": "monan-jedi-runtime-v2",
        "public_anchors": ["MONAN_JEDI_INSTALL_ROOT", "STACK_ROOT"],
        "layout": public_layout,
        "stack": {
            "env_name": args.stack_env_name,
            "env_module": args.stack_env_module,
            "site_setup": args.stack_site_setup,
            "module_root_template": "envs/{env_name}/modules",
        },
        "capabilities": {
            "mpas": True,
            "mpas_jedi": True,
            "wps": _bool(args.wps_enabled),
            "obs2ioda": _bool(args.obs2ioda_enabled),
        },
        "canonical_executables": sorted(executables),
        "producer": {
            "build_id": args.build_id,
            "config": args.config,
            "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
            "obs2ioda_ref": args.obs2ioda_ref,
            "wps_ref": args.wps_ref,
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
