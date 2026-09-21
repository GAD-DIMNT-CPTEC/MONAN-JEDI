#!/usr/bin/env python3
"""Regression tests for configuration documentation."""

from __future__ import annotations

import importlib.util
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
READER = ROOT / "scripts" / "lib" / "read_config.py"
CHECKER = ROOT / "scripts" / "check_config_documentation.py"
REFERENCE = ROOT / "docs" / "configuration-reference.md"
CONFIG_README = ROOT / "config" / "README.md"
TEMPLATE = ROOT / "config" / "template.yaml"
JACI = ROOT / "config" / "jaci.yaml"
CONTRIBUTING = ROOT / "CONTRIBUTING.md"
AGENTS = ROOT / "AGENTS.md"

SPEC = importlib.util.spec_from_file_location("read_config", READER)
assert SPEC is not None
assert SPEC.loader is not None
READER_MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(READER_MODULE)


class ConfigurationDocumentationTests(unittest.TestCase):
    def test_documentation_contract_checker_passes(self) -> None:
        completed = subprocess.run(
            ["python3", str(CHECKER)],
            cwd=ROOT,
            text=True,
            capture_output=True,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)

    def test_every_public_key_has_detailed_reference_heading(self) -> None:
        text = REFERENCE.read_text(encoding="utf-8")
        for path in READER_MODULE.supported_yaml_paths():
            self.assertIn(
                "### `{0}`".format(path),
                text,
                msg="public configuration key lacks detailed reference: {0}".format(path),
            )

    def test_configuration_files_keep_explanatory_header_contract(self) -> None:
        for path in (JACI, TEMPLATE):
            text = path.read_text(encoding="utf-8")
            for marker in (
                "PURPOSE",
                "IMPORTANT FILESYSTEM MODEL",
                "MAIN DERIVED PATHS",
                "GENERAL RULES",
            ):
                self.assertIn(marker, text, msg="{0} lost {1}".format(path, marker))

    def test_contract_explains_product_vs_application_configuration(self) -> None:
        text = CONFIG_README.read_text(encoding="utf-8")
        for marker in (
            "operator-facing documentation",
            "documentation contract",
            "JEDI experiment",
            "Do not create a second `configs/` directory",
        ):
            self.assertIn(marker, text)

    def test_human_and_ai_contributor_policies_exist(self) -> None:
        contributing = CONTRIBUTING.read_text(encoding="utf-8")
        agents = AGENTS.read_text(encoding="utf-8")
        self.assertIn("scripts/check_config_documentation.py", contributing)
        self.assertIn("Configuration documentation is mandatory", agents)
        self.assertIn("never replace the self-documenting YAML", agents)

    def test_template_points_to_canonical_reference(self) -> None:
        text = TEMPLATE.read_text(encoding="utf-8")
        self.assertIn("docs/configuration-reference.md", text)


if __name__ == "__main__":
    unittest.main()
