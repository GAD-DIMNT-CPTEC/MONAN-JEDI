#!/usr/bin/env python3
"""Configuration regression tests for MONAN-JEDI."""

from __future__ import annotations

import ast
import importlib.util
import os
import shlex
import subprocess
import tempfile
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
READER = ROOT / "scripts" / "lib" / "read_config.py"
CONFIG_SH = ROOT / "scripts" / "lib" / "config.sh"
CONFIGURE_SH = ROOT / "scripts" / "lib" / "configure.sh"
JACI = ROOT / "config" / "jaci.yaml"
TEMPLATE = ROOT / "config" / "template.yaml"

SPEC = importlib.util.spec_from_file_location("read_config", READER)
assert SPEC is not None
assert SPEC.loader is not None
READER_MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(READER_MODULE)


def clean_environment() -> dict[str, str]:
    env = dict(os.environ)
    for field in READER_MODULE.CONFIG_FIELDS:
        for name in field["envs"]:
            env.pop(name, None)
    for name, _default in READER_MODULE.INTERNAL_DEFAULTS:
        env.pop(name, None)
    env["USER"] = "test-user"
    return env


def read_exports(path: Path, extra_env: dict[str, str] | None = None) -> dict[str, str]:
    env = clean_environment()
    if extra_env:
        env.update(extra_env)
    completed = subprocess.run(
        ["python3", str(READER), str(path)],
        cwd=ROOT,
        check=True,
        text=True,
        capture_output=True,
        env=env,
    )
    values: dict[str, str] = {}
    for line in completed.stdout.splitlines():
        prefix, assignment = line.split(" ", 1)
        assert prefix == "export"
        name, raw_value = assignment.split("=", 1)
        parts = shlex.split(raw_value)
        values[name] = parts[0] if parts else ""
    return values


def load_yaml(path: Path) -> dict:
    with path.open(encoding="utf-8") as stream:
        value = yaml.safe_load(stream)
    assert isinstance(value, dict)
    return value


class ConfigurationTests(unittest.TestCase):
    def test_reader_syntax_is_python_36_compatible(self) -> None:
        source = READER.read_text(encoding="utf-8")
        ast.parse(source, filename=str(READER), feature_version=(3, 6))

    def test_both_repository_configs_pass_strict_validation(self) -> None:
        for path in (JACI, TEMPLATE):
            completed = subprocess.run(
                ["python3", str(READER), "--check", str(path)],
                cwd=ROOT,
                text=True,
                capture_output=True,
                env=clean_environment(),
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)

    def test_unknown_key_is_rejected(self) -> None:
        data = load_yaml(JACI)
        data["pbs"]["wall_time"] = data["pbs"]["walltime"]
        with self.assertRaisesRegex(ValueError, "unknown configuration key: pbs.wall_time"):
            READER_MODULE.validate_configuration(data)

    def test_invalid_type_is_rejected(self) -> None:
        data = load_yaml(JACI)
        data["pbs"]["ncpus"] = "sixty-four"
        with self.assertRaisesRegex(ValueError, "pbs.ncpus must be an integer"):
            READER_MODULE.validate_configuration(data)

    def test_invalid_enum_is_rejected(self) -> None:
        data = load_yaml(JACI)
        data["model"]["double_precision"] = "YES"
        with self.assertRaisesRegex(ValueError, "model.double_precision must be one of"):
            READER_MODULE.validate_configuration(data)

    def test_public_yaml_exposes_legitimate_path_and_source_overrides(self) -> None:
        expected = {
            "project.work_root",
            "project.log_root",
            "stack.work_root",
            "stack.root",
            "stack.module_root",
            "build.dir",
            "install.root",
            "install.bin_dir",
            "data.root",
            "data.crtm_coeffs_url",
            "data.crtm_coeffs_tgz",
            "obs2ioda.repo",
            "obs2ioda.source_dir",
            "obs2ioda.build_dir",
            "obs2ioda.install_dir",
            "obs2ioda.executable_name",
            "wps.repo",
            "wps.source_dir",
            "wps.build_dir",
            "wps.releases_dir",
            "wps.install_dir",
            "wps.patch_dir",
            "wps.ungrib_name",
            "wps.link_grib_name",
        }
        self.assertTrue(expected.issubset(set(READER_MODULE.supported_yaml_paths())))

    def test_jaci_relies_on_defaults_for_optional_paths_and_sources(self) -> None:
        data = load_yaml(JACI)
        self.assertNotIn("install", data)
        self.assertNotIn("work_root", data["project"])
        self.assertNotIn("root", data["stack"])
        self.assertNotIn("repo", data["obs2ioda"])
        self.assertNotIn("repo", data["wps"])

        values = read_exports(JACI)
        self.assertEqual(values["MONAN_JEDI_INSTALL_ROOT"], "")
        self.assertEqual(values["MONAN_JEDI_DATA_ROOT"], "")
        self.assertEqual(values["MONAN_JEDI_OBS2IODA_SOURCE_DIR"], "")
        self.assertEqual(values["MONAN_JEDI_WPS_SOURCE_DIR"], "")
        self.assertEqual(values["MONAN_JEDI_OBS2IODA_REPO"], "https://github.com/NCAR/obs2ioda.git")
        self.assertEqual(values["MONAN_JEDI_WPS_REPO"], "https://github.com/wrf-model/WPS.git")

    def test_template_user_overrides_are_exported(self) -> None:
        data = load_yaml(TEMPLATE)
        data["install"]["root"] = "/custom/install"
        data["data"]["crtm_coeffs_url"] = "https://mirror.example/crtm.tgz"
        data["obs2ioda"]["repo"] = "https://example.org/obs2ioda.git"
        data["wps"]["source_dir"] = "/custom/wps/src"

        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".yaml", encoding="utf-8", delete=False
        ) as stream:
            yaml.safe_dump(data, stream, sort_keys=False)
            temp_path = Path(stream.name)

        try:
            values = read_exports(temp_path)
        finally:
            temp_path.unlink()

        self.assertEqual(values["MONAN_JEDI_INSTALL_ROOT"], "/custom/install")
        self.assertEqual(
            values["MONAN_JEDI_CRTM_COEFFS_URL"],
            "https://mirror.example/crtm.tgz",
        )
        self.assertEqual(
            values["MONAN_JEDI_OBS2IODA_REPO"],
            "https://example.org/obs2ioda.git",
        )
        self.assertEqual(values["MONAN_JEDI_WPS_SOURCE_DIR"], "/custom/wps/src")

    def test_fortran_config_fans_out_to_compatibility_aliases(self) -> None:
        values = read_exports(JACI)
        for name in ("MONAN_JEDI_FC", "MONAN_JEDI_F77", "MONAN_JEDI_F90"):
            self.assertEqual(values[name], "ftn")
        for name in ("MONAN_JEDI_MPIFC", "MONAN_JEDI_MPIF77", "MONAN_JEDI_MPIF90"):
            self.assertEqual(values[name], "ftn")

    def test_non_empty_environment_override_wins(self) -> None:
        values = read_exports(JACI, {"MONAN_JEDI_WPS_BUILD_TYPE": "Debug"})
        self.assertEqual(values["MONAN_JEDI_WPS_BUILD_TYPE"], "Debug")

    def test_empty_environment_override_does_not_mask_yaml(self) -> None:
        values = read_exports(JACI, {"MONAN_JEDI_BUILD_JOBS": ""})
        self.assertEqual(values["MONAN_JEDI_BUILD_JOBS"], "64")

    def test_external_refs_are_full_commit_shas(self) -> None:
        values = read_exports(JACI)
        for name in ("MONAN_JEDI_OBS2IODA_REF", "MONAN_JEDI_WPS_REF"):
            self.assertRegex(values[name], r"^[0-9a-f]{40}$")
            self.assertNotEqual(values[name], "main")

    def test_jaci_enables_integrated_auxiliary_tools(self) -> None:
        values = read_exports(JACI)
        self.assertEqual(values["MONAN_JEDI_OBS2IODA_ENABLED"], "1")
        self.assertEqual(values["MONAN_JEDI_WPS_ENABLED"], "1")
        self.assertEqual(values["MONAN_JEDI_PBS_QUEUE"], "pesqmidi")
        self.assertEqual(values["MONAN_JEDI_PBS_WALLTIME"], "02:00:00")

    def test_template_disables_optional_auxiliary_tools_and_submission(self) -> None:
        values = read_exports(TEMPLATE)
        self.assertEqual(values["MONAN_JEDI_OBS2IODA_ENABLED"], "0")
        self.assertEqual(values["MONAN_JEDI_WPS_ENABLED"], "0")
        self.assertEqual(values["MONAN_JEDI_SUBMIT_JOB"], "0")

    def test_config_sh_derives_private_paths_from_build_id(self) -> None:
        source = CONFIG_SH.read_text(encoding="utf-8")
        self.assertIn("MONAN_JEDI_BUILD_ID", source)
        self.assertNotIn("MONAN_JEDI_RUN_ID", source)
        self.assertIn('${PROJECT_ROOT}/work/${MONAN_JEDI_BUILD_ID}', source)
        self.assertIn('${PROJECT_ROOT}/build/${MONAN_JEDI_BUILD_ID}', source)

    def test_configure_does_not_publish_build_outputs_directly(self) -> None:
        source = CONFIGURE_SH.read_text(encoding="utf-8")
        self.assertNotIn("-DCMAKE_RUNTIME_OUTPUT_DIRECTORY=${MONAN_JEDI_INSTALL_BIN_DIR}", source)


if __name__ == "__main__":
    unittest.main()
