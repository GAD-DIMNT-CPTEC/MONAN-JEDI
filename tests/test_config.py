#!/usr/bin/env python3
"""Configuration regression tests for MONAN-JEDI auxiliary tools."""

from __future__ import annotations

import os
import shlex
import subprocess
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
READER = ROOT / "scripts" / "lib" / "read_config.py"
JACI = ROOT / "config" / "jaci.yaml"
TEMPLATE = ROOT / "config" / "template.yaml"


def read_exports(path: Path) -> dict[str, str]:
    completed = subprocess.run(
        ["python3", str(READER), str(path)],
        cwd=ROOT,
        check=True,
        text=True,
        capture_output=True,
        env={**os.environ, "USER": "test-user"},
    )
    values: dict[str, str] = {}
    for line in completed.stdout.splitlines():
        prefix, assignment = line.split(" ", 1)
        assert prefix == "export"
        name, raw_value = assignment.split("=", 1)
        parts = shlex.split(raw_value)
        values[name] = parts[0] if parts else ""
    return values


class ConfigurationTests(unittest.TestCase):
    def test_yaml_documents_are_mappings(self) -> None:
        for path in (JACI, TEMPLATE):
            with path.open(encoding="utf-8") as stream:
                self.assertIsInstance(yaml.safe_load(stream), dict)

    def test_jaci_enables_integrated_auxiliary_tools(self) -> None:
        values = read_exports(JACI)
        self.assertEqual(values["MONAN_JEDI_OBS2IODA_ENABLED"], "1")
        self.assertEqual(values["MONAN_JEDI_WPS_ENABLED"], "1")
        self.assertEqual(values["MONAN_JEDI_WPS_VERSION"], "4.6.0")
        self.assertEqual(values["MONAN_JEDI_WPS_DEFAULT_VTABLE"], "Vtable.GFS")
        self.assertNotIn("MONAN_JEDI_WPS_CONFIGURE_OPTION", values)

    def test_template_disables_optional_auxiliary_tools(self) -> None:
        values = read_exports(TEMPLATE)
        self.assertEqual(values["MONAN_JEDI_OBS2IODA_ENABLED"], "0")
        self.assertEqual(values["MONAN_JEDI_WPS_ENABLED"], "0")

    def test_environment_override_wins(self) -> None:
        env = {**os.environ, "MONAN_JEDI_WPS_BUILD_TYPE": "Debug"}
        completed = subprocess.run(
            ["python3", str(READER), str(JACI)],
            cwd=ROOT,
            check=True,
            text=True,
            capture_output=True,
            env=env,
        )
        self.assertIn("export MONAN_JEDI_WPS_BUILD_TYPE=Debug", completed.stdout)


if __name__ == "__main__":
    unittest.main()
