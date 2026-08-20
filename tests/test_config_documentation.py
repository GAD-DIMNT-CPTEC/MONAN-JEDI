#!/usr/bin/env python3
"""Regression tests for the configuration files' conceptual documentation."""

from __future__ import annotations

import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
CONFIG_DIRECTORY = REPOSITORY_ROOT / "config"


class ConfigurationDocumentationTests(unittest.TestCase):
    """Protect guidance that has historically been lost during refactors."""

    def test_yaml_files_keep_core_guidance(self) -> None:
        required_markers = (
            "PURPOSE",
            "IMPORTANT FILESYSTEM MODEL",
            "not an operational data-assimilation",
            "Do not assume that the stack",
            "MAIN DERIVED PATHS",
            "Keep this value quoted",
            "Pin external component refs",
        )

        for filename in ("jaci.yaml", "template.yaml"):
            with self.subTest(filename=filename):
                text = (CONFIG_DIRECTORY / filename).read_text(encoding="utf-8")
                for marker in required_markers:
                    self.assertIn(
                        marker,
                        text,
                        msg=f"{filename} lost required configuration guidance: {marker}",
                    )

    def test_configuration_contract_is_present(self) -> None:
        contract = (CONFIG_DIRECTORY / "README.md").read_text(encoding="utf-8")
        for marker in (
            "Documentation contract",
            "update `config/jaci.yaml` and `config/template.yaml` together",
            "preserve historical rationale",
            "documentation regression checks",
        ):
            self.assertIn(marker, contract)


if __name__ == "__main__":
    unittest.main()
