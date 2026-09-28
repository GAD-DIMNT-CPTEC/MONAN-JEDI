#!/usr/bin/env python3
"""Cross-repository conformance checks for the MONAN-JEDI ecosystem standard."""

from __future__ import annotations

import argparse
from pathlib import Path


class ContractViolation(RuntimeError):
    pass


def text(path: Path) -> str:
    if not path.is_file():
        raise ContractViolation(f"required maintained file is missing: {path}")
    return path.read_text(encoding="utf-8")


def require_contains(path: Path, *needles: str) -> None:
    content = text(path)
    for needle in needles:
        if needle not in content:
            raise ContractViolation(f"{path}: missing required contract marker {needle!r}")


def forbid(path: Path, *needles: str) -> None:
    content = text(path)
    for needle in needles:
        if needle in content:
            raise ContractViolation(f"{path}: forbidden legacy/runtime duplication {needle!r}")


def check_mpaswf(root: Path) -> None:
    config = root / "configs/jaci-x1.10242.yaml"
    require_contains(
        config,
        "monan_jedi_install_root: ${MONAN_JEDI_INSTALL_ROOT}",
        "stack_root: ${STACK_ROOT}",
    )
    forbid(
        config,
        "jedi-mpas-env/",
        "/opt/cray/pals/",
        "/p/projetos/monan_das/joao.gerd",
        "module_root_template",
    )
    require_contains(
        root / "mpaswf/software.py",
        "ecosystem_contract_version",
        "stack.module_root",
    )


def check_workflow(root: Path) -> None:
    maintained = [
        root / "configs/sites/jaci/site.yaml.example",
        root / "configs/experiments/3dfgat_mpastatic_x1.10242_2018041500/experiment.yaml",
        root / "configs/experiments/3dfgat_mpastatic_x1.10242_2018041500/runtime.yaml",
        root / "configs/experiments/3dfgat_mpastatic_x1.10242_2018041500/pbs.yaml",
        root / "examples/simpleworkflow/cycled_da/jedi.yaml.example",
        root / "examples/simpleworkflow/cycled_da/jedi-baseline-bmatrix.yaml.example",
        root / "examples/simpleworkflow/cycled_da/mpas.yaml.example",
        root / "examples/simpleworkflow/cycled_da/mpas-cycling-jaci.yaml.example",
    ]
    for path in maintained:
        forbid(
            path,
            "/opt/cray/pals/1.6/bin/mpiexec",
            "/p/projetos/monan_das/joao.gerd",
            "mpas-bmatrix-global/scripts/load_jaci_env.sh",
            "MPAS-BMatrix/scripts/load_jaci_env.sh",
            "module_root_template",
        )
    require_contains(
        root / "monan_jedi_workflow/site.py",
        "ecosystem_contract_version",
        'settings["module_root"]',
    )


def check_bmatrix(root: Path) -> None:
    config = root / "configs/jaci.yaml"
    require_contains(
        config,
        "STACK_ROOT: ${STACK_ROOT}",
    )
    forbid(
        config,
        "jedi-mpas-env/",
        "/opt/cray/pe/craype/",
        "/p/projetos/monan_das/joao.gerd",
        "module_root_template",
    )
    require_contains(
        root / "src/bmatrix/config.py",
        "ecosystem_contract_version",
        "stack.module_root",
    )
    forbid(
        root / "src/bmatrix/scheduler.py",
        "module_root_template",
        "/opt/cray/pals/",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mpaswf", type=Path, required=True)
    parser.add_argument("--workflow", type=Path, required=True)
    parser.add_argument("--bmatrix", type=Path, required=True)
    args = parser.parse_args()

    check_mpaswf(args.mpaswf)
    check_workflow(args.workflow)
    check_bmatrix(args.bmatrix)
    print("Ecosystem runtime contract conformance: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
