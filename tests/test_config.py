#!/usr/bin/env python3
"""Configuration regression tests for MONAN-JEDI auxiliary tools."""

from __future__ import annotations

import ast
import importlib.util
import io
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

READER_SPEC = importlib.util.spec_from_file_location("read_config", READER)
assert READER_SPEC is not None
assert READER_SPEC.loader is not None
READER_MODULE = importlib.util.module_from_spec(READER_SPEC)
READER_SPEC.loader.exec_module(READER_MODULE)


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
    def test_reader_documents_its_internal_contract(self) -> None:
        source = READER.read_text(encoding="utf-8")
        module_doc = ast.get_docstring(ast.parse(source))
        self.assertIsNotNone(module_doc)

        for section in (
            "Purpose",
            "Configuration model",
            "Value conversion",
            "Environment precedence",
            "Division of responsibility",
            "Compatibility",
            "Output and errors",
        ):
            self.assertIn(section, module_doc)

    def test_reader_syntax_is_python_36_compatible(self) -> None:
        source = READER.read_text(encoding="utf-8")
        ast.parse(source, filename=str(READER), feature_version=(3, 6))

    def test_nested_lookup_uses_default_for_missing_null_or_invalid_path(
        self,
    ) -> None:
        data = {
            "build": {"jobs": 8, "empty": None},
            "model": "not-a-mapping",
        }
        self.assertEqual(
            READER_MODULE.get_nested_value(data, "build.jobs", "fallback"),
            8,
        )
        self.assertEqual(
            READER_MODULE.get_nested_value(data, "build.missing", "fallback"),
            "fallback",
        )
        self.assertEqual(
            READER_MODULE.get_nested_value(data, "build.empty", "fallback"),
            "fallback",
        )
        self.assertEqual(
            READER_MODULE.get_nested_value(
                data,
                "model.double_precision",
                "fallback",
            ),
            "fallback",
        )

    def test_scalar_normalization_and_environment_expansion(self) -> None:
        previous = os.environ.get("MONAN_JEDI_TEST_ROOT")
        os.environ["MONAN_JEDI_TEST_ROOT"] = "/tmp/test root"
        try:
            self.assertEqual(READER_MODULE.normalize_value(True), "1")
            self.assertEqual(READER_MODULE.normalize_value(False), "0")
            self.assertEqual(READER_MODULE.normalize_value(64), "64")
            self.assertEqual(
                READER_MODULE.normalize_value(
                    "${MONAN_JEDI_TEST_ROOT}/bundle"
                ),
                "/tmp/test root/bundle",
            )
        finally:
            if previous is None:
                os.environ.pop("MONAN_JEDI_TEST_ROOT", None)
            else:
                os.environ["MONAN_JEDI_TEST_ROOT"] = previous

    def test_non_scalar_values_are_rejected(self) -> None:
        for value in (["invalid"], {"invalid": "mapping"}):
            with self.subTest(value=value):
                with self.assertRaisesRegex(
                    ValueError,
                    "lists and mappings cannot be exported",
                ):
                    READER_MODULE.normalize_value(value)

    def test_empty_environment_override_is_preserved(self) -> None:
        name = "MONAN_JEDI_TEST_EMPTY_OVERRIDE"
        previous = os.environ.get(name)
        os.environ[name] = ""
        try:
            self.assertEqual(READER_MODULE.resolve_value(name, "yaml"), "")
        finally:
            if previous is None:
                os.environ.pop(name, None)
            else:
                os.environ[name] = previous

    def test_export_is_shell_quoted_and_round_trips(self) -> None:
        stream = io.StringIO()
        value = "path with spaces; $(do-not-run)"
        READER_MODULE.write_export(stream, "MONAN_JEDI_TEST_VALUE", value)
        line = stream.getvalue().strip()
        prefix, assignment = line.split(" ", 1)
        name, raw_value = assignment.split("=", 1)
        self.assertEqual(prefix, "export")
        self.assertEqual(name, "MONAN_JEDI_TEST_VALUE")
        self.assertEqual(shlex.split(raw_value), [value])

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
        self.assertEqual(values["MONAN_JEDI_PBS_QUEUE"], "pesqmidi")
        self.assertEqual(values["MONAN_JEDI_PBS_WALLTIME"], "02:00:00")

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
