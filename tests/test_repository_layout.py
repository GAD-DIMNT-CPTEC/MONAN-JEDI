#!/usr/bin/env python3
"""Repository layout regression tests."""

from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class RepositoryLayoutTests(unittest.TestCase):
    def test_ambiguous_configs_directory_is_absent(self) -> None:
        self.assertFalse((ROOT / "configs").exists())

    def test_application_example_has_unambiguous_location(self) -> None:
        self.assertTrue((ROOT / "examples" / "unbalance-ensemble" / "config.yaml").is_file())
        self.assertTrue((ROOT / "examples" / "unbalance-ensemble" / "README.md").is_file())

    def test_accidental_empty_root_file_is_absent(self) -> None:
        self.assertFalse((ROOT / "nonexistent").exists())

    def test_old_configuration_reference_is_absent(self) -> None:
        self.assertFalse((ROOT / "docs" / "YAML_CONFIGURATION.md").exists())
        self.assertTrue((ROOT / "docs" / "configuration-reference.md").is_file())


if __name__ == "__main__":
    unittest.main()
