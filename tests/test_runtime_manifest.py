from __future__ import annotations

import argparse
import importlib.util
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "write_runtime_manifest.py"


def _module():
    spec = importlib.util.spec_from_file_location("write_runtime_manifest", SCRIPT)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _args(tmp: Path, *, module_root: str) -> argparse.Namespace:
    install = tmp / "install"
    (install / "bin").mkdir(parents=True)
    return argparse.Namespace(
        output=str(install / "share/monan-jedi/install-manifest.json"),
        install_root=str(install),
        stack_root="/runtime/spack-stack",
        stack_module_root=module_root,
        stack_env_name="jaci-test",
        stack_env_module="test/jedi-mpas-env/2.0.0",
        stack_site_setup="configs/sites/test/setup.sh",
        build_id="test",
        config="config/test.yaml",
        wps_enabled="0",
        obs2ioda_enabled="0",
        wps_ref="",
        obs2ioda_ref="",
    )


class RuntimeManifestTests(unittest.TestCase):
    def test_contract_v2_uses_only_two_public_anchors(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            args = _args(Path(raw), module_root="/runtime/spack-stack/custom/modules")
            contract = _module().build_contract(args)

        self.assertEqual(contract["ecosystem_contract_version"], 2)
        self.assertEqual(contract["contract"], "monan-jedi-runtime-v2")
        self.assertEqual(
            contract["public_anchors"],
            ["MONAN_JEDI_INSTALL_ROOT", "STACK_ROOT"],
        )
        self.assertEqual(contract["stack"]["module_root"], "custom/modules")
        self.assertNotIn("module_root_template", contract["stack"])

    def test_external_module_root_is_preserved_as_absolute(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            args = _args(Path(raw), module_root="/external/modules")
            contract = _module().build_contract(args)

        self.assertEqual(contract["stack"]["module_root"], "/external/modules")


if __name__ == "__main__":
    unittest.main()
