#!/usr/bin/env python3
"""Regression tests for configuration documentation."""

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
READER = ROOT / "scripts" / "lib" / "read_config.py"
REFERENCE = ROOT / "docs" / "configuration-reference.md"
CONFIG_README = ROOT / "config" / "README.md"
TEMPLATE = ROOT / "config" / "template.yaml"

SPEC = importlib.util.spec_from_file_location("read_config", READER)
assert SPEC is not None
assert SPEC.loader is not None
READER_MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(READER_MODULE)


class ConfigurationDocumentationTests(unittest.TestCase):
    def test_every_public_key_is_documented(self) -> None:
        text = REFERENCE.read_text(encoding="utf-8")
        for path in READER_MODULE.supported_yaml_paths():
            self.assertIn(
                "`{0}`".format(path),
                text,
                msg="public configuration key is undocumented: {0}".format(path),
            )

    def test_contract_explains_product_vs_application_configuration(self) -> None:
        text = CONFIG_README.read_text(encoding="utf-8")
        for marker in (
            "MONAN-JEDI build/install site configuration",
            "JEDI experiment/application inputs",
            "Unknown keys are errors",
            "Do not create a second `configs/` directory",
        ):
            self.assertIn(marker, text)

    def test_template_points_to_canonical_reference(self) -> None:
        text = TEMPLATE.read_text(encoding="utf-8")
        self.assertIn("docs/configuration-reference.md", text)


if __name__ == "__main__":
    unittest.main()
