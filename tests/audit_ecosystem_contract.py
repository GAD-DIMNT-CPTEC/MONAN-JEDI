#!/usr/bin/env python3
"""Cross-repository regression audit for the MONAN-JEDI ecosystem.

This test intentionally checks architectural invariants that cannot be proven by
one repository in isolation.  It operates on four checkouts supplied by the
GitHub Actions workflow and has no JACI/PBS dependency.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import sys


PUBLIC_ANCHORS = ("MONAN_JEDI_INSTALL_ROOT", "STACK_ROOT")
FORBIDDEN_CONSUMER_TOKENS = (
    "MONAN_JEDI_SOURCE_DIR",
    "MONAN_JEDI_BUILD_DIR",
    "MONAN_JEDI_RUN_ID",
)
FORBIDDEN_MAINTAINED_TOKENS = (
    "/p/projetos/monan_das/joao.gerd",
    "/opt/cray/pals/1.6/bin/mpiexec",
    "/opt/cray/pe/craype/",
    "cray-mpich/8.1.31/none/none/jedi-mpas-env/1.0.0",
    "jaci-mpas-jedi-gcc12-craympich",
    "mpas-bmatrix-global/scripts/load_jaci_env.sh",
)
TEXT_SUFFIXES = {".py", ".sh", ".yaml", ".yml", ".toml"}


def fail(message: str, failures: list[str]) -> None:
    failures.append(message)


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def iter_text_files(root: Path, relative_roots: tuple[str, ...]):
    for relative in relative_roots:
        base = root / relative
        if not base.exists():
            continue
        if base.is_file():
            yield base
            continue
        for path in base.rglob("*"):
            if not path.is_file() or path.suffix not in TEXT_SUFFIXES:
                continue
            parts = set(path.relative_to(root).parts)
            # Frozen provenance/reference files are deliberately not executable
            # configuration and may retain historical absolute paths.
            if "reference" in parts or path.name.startswith("reference-"):
                continue
            yield path


def assert_contains(path: Path, tokens: tuple[str, ...], failures: list[str]) -> None:
    text = read(path)
    for token in tokens:
        if token not in text:
            fail(f"{path}: required token missing: {token}", failures)


def assert_absent(
    root: Path,
    relative_roots: tuple[str, ...],
    tokens: tuple[str, ...],
    failures: list[str],
) -> None:
    for path in iter_text_files(root, relative_roots):
        text = read(path)
        for token in tokens:
            if token in text:
                fail(f"{path}: forbidden maintained-config token: {token}", failures)


def audit_producer(root: Path, failures: list[str]) -> None:
    standard = root / "docs/ecosystem-configuration-contract.md"
    writer = root / "scripts/write_runtime_manifest.py"
    build = root / "scripts/lib/build.sh"
    install_test = root / "scripts/lib/install_test.sh"

    assert_contains(
        standard,
        (
            "MONAN_JEDI_INSTALL_ROOT",
            "STACK_ROOT",
            "schema_version: 2",
            "ecosystem_contract_version: 2",
        ),
        failures,
    )
    assert_contains(
        writer,
        (
            '"schema_version": 2',
            '"ecosystem_contract_version": 2',
            '"contract": "monan-jedi-runtime-v2"',
            '"public_anchors": ["MONAN_JEDI_INSTALL_ROOT", "STACK_ROOT"]',
            '"runtime_support": runtime_support',
        ),
        failures,
    )
    assert_contains(
        install_test,
        (
            'record.get("schema_version") != 2',
            'record.get("ecosystem_contract_version") != 2',
            'record.get("public_anchors") != ["MONAN_JEDI_INSTALL_ROOT", "STACK_ROOT"]',
        ),
        failures,
    )

    producer_publication = read(build)
    for dated_observation in (
        "sondes_obs_2018041500_m.nc4",
        "gnssro_obs_2018041500_s.nc4",
        "sfc_obs_2018041500_m.nc4",
    ):
        if dated_observation in producer_publication:
            fail(
                f"{build}: date-specific observation leaked into runtime publication: "
                f"{dated_observation}",
                failures,
            )


def audit_mpaswf(root: Path, failures: list[str]) -> None:
    parser = root / "mpaswf/software.py"
    pbs = root / "mpaswf/pbs.py"
    config = root / "configs/jaci-x1.10242.yaml"

    assert_contains(
        parser,
        (
            'payload.get("schema_version") != 2',
            'payload.get("ecosystem_contract_version") != 2',
            'payload.get("public_anchors") != ["MONAN_JEDI_INSTALL_ROOT", "STACK_ROOT"]',
        ),
        failures,
    )
    assert_contains(
        pbs,
        (
            "runtime_contract(config)",
            "set +u",
            "contract.stack_site_setup",
            "contract.stack_env_module",
        ),
        failures,
    )
    assert_contains(
        config,
        (
            "monan_jedi_install_root: ${MONAN_JEDI_INSTALL_ROOT}",
            "stack_root: ${STACK_ROOT}",
        ),
        failures,
    )
    assert_absent(
        root,
        ("mpaswf", "configs"),
        FORBIDDEN_CONSUMER_TOKENS + FORBIDDEN_MAINTAINED_TOKENS,
        failures,
    )


def audit_bmatrix(root: Path, failures: list[str]) -> None:
    parser = root / "src/bmatrix/config.py"
    scheduler = root / "src/bmatrix/scheduler.py"
    loader = root / "scripts/load_jaci_env.sh"
    jaci = root / "configs/jaci.yaml"

    assert_contains(
        parser,
        (
            'payload.get("schema_version") != 2',
            'payload.get("ecosystem_contract_version") != 2',
            'payload.get("public_anchors") != ["MONAN_JEDI_INSTALL_ROOT", "STACK_ROOT"]',
        ),
        failures,
    )
    assert_contains(
        loader,
        (
            'payload.get("schema_version") != 2',
            'payload.get("ecosystem_contract_version") != 2',
            "STACK_ENV_NAME",
            "STACK_ENV_MODULE",
            "STACK_SITE_SETUP",
        ),
        failures,
    )
    assert_contains(scheduler, ("runtime_contract(config)", "def mpi_command("), failures)
    assert_contains(
        jaci,
        (
            "STACK_ROOT: ${STACK_ROOT}",
            'FI_CXI_RX_MATCH_MODE: "hybrid"',
            'launcher: ["mpiexec", "-n", "{mpi_ranks}"]',
        ),
        failures,
    )
    scheduler_text = read(scheduler)
    for token in ("FI_CXI_RX_MATCH_MODE", "GFORTRAN_CONVERT_UNIT"):
        if token in scheduler_text:
            fail(f"{scheduler}: site policy hard-coded in scheduler: {token}", failures)
    assert_absent(
        root,
        ("src/bmatrix", "configs", "scripts"),
        FORBIDDEN_CONSUMER_TOKENS + FORBIDDEN_MAINTAINED_TOKENS,
        failures,
    )


def audit_workflow(root: Path, failures: list[str]) -> None:
    site = root / "monan_jedi_workflow/site.py"
    stage = root / "monan_jedi_workflow/stage_config.py"
    runtime = (
        root
        / "configs/experiments/3dfgat_mpastatic_x1.10242_2018041500/runtime.yaml"
    )
    experiment = (
        root
        / "configs/experiments/3dfgat_mpastatic_x1.10242_2018041500/experiment.yaml"
    )

    assert_contains(
        site,
        (
            'payload.get("schema_version") != 2',
            'payload.get("ecosystem_contract_version") != 2',
            'payload.get("public_anchors") != ["MONAN_JEDI_INSTALL_ROOT", "STACK_ROOT"]',
        ),
        failures,
    )
    assert_contains(stage, ("runtime_contract_context(install_root, stack_root)",), failures)

    runtime_text = read(runtime)
    if "share/monan-jedi/ufo/" in runtime_text:
        fail(f"{runtime}: scientific observations resolved from install root", failures)
    if "source: ufo/testinput_tier_1" not in runtime_text:
        fail(f"{runtime}: baseline observations are not owned by data_root", failures)

    experiment_text = read(experiment)
    if "/p/projetos/monan_das/joao.gerd" in experiment_text:
        fail(f"{experiment}: personal operational path", failures)

    assert_absent(
        root,
        (
            "monan_jedi_workflow",
            "configs/sites",
            "configs/experiments",
            "examples",
        ),
        FORBIDDEN_CONSUMER_TOKENS + FORBIDDEN_MAINTAINED_TOKENS,
        failures,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--monan-jedi", type=Path, required=True)
    parser.add_argument("--mpaswf", type=Path, required=True)
    parser.add_argument("--workflow", type=Path, required=True)
    parser.add_argument("--bmatrix", type=Path, required=True)
    args = parser.parse_args()

    failures: list[str] = []
    audit_producer(args.monan_jedi, failures)
    audit_mpaswf(args.mpaswf, failures)
    audit_workflow(args.workflow, failures)
    audit_bmatrix(args.bmatrix, failures)

    if failures:
        print("ECOSYSTEM CONTRACT AUDIT: FAIL", file=sys.stderr)
        for item in failures:
            print(f" - {item}", file=sys.stderr)
        return 1

    print("ECOSYSTEM CONTRACT AUDIT: PASS")
    print("public anchors: " + ", ".join(PUBLIC_ANCHORS))
    print("runtime contract: schema_version=2, ecosystem_contract_version=2")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
