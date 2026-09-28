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


def _args(tmp: Path) -> argparse.Namespace:
    install = tmp / "install"
    (install / "bin").mkdir(parents=True)
    return argparse.Namespace(
        output=str(install / "share/monan-jedi/install-manifest.json"),
        install_root=str(install),
        stack_env_name="jaci-test",
        stack_env_module="test/jedi-mpas-env/2.0.0",
        stack_site_setup="configs/sites/test/setup.sh",
        build_id="test",
        config="config/test.yaml",
        wps_ref="",
        obs2ioda_ref="",
    )


class RuntimeManifestTests(unittest.TestCase):
    def test_contract_is_relocatable_and_has_two_public_anchors(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            contract = _module().build_contract(_args(Path(raw)))

        self.assertEqual(contract["schema_version"], 2)
        self.assertEqual(contract["ecosystem_contract_version"], 2)
        self.assertEqual(contract["contract"], "monan-jedi-runtime-v2")
        self.assertEqual(
            contract["public_anchors"],
            ["MONAN_JEDI_INSTALL_ROOT", "STACK_ROOT"],
        )
        self.assertEqual(
            contract["stack"]["module_root_template"],
            "envs/{env_name}/modules",
        )
        self.assertNotIn("install_root", contract)
        self.assertNotIn("public_contract", contract)
        self.assertNotIn("ufo_testinput_tier_1", contract["layout"])
        self.assertFalse(
            any(
                "ufo/testinput_tier_1" in path
                for path in contract["required_runtime_support"]
            )
        )

    def test_capabilities_follow_published_files(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            tmp = Path(raw)
            args = _args(tmp)
            install = Path(args.install_root)
            for name in (
                "mpas_init_atmosphere",
                "mpas_atmosphere",
                "mpasjedi_variational.x",
                "mpasjedi_error_covariance_toolbox.x",
                "mpasjedi_process_perts.x",
                "mpasjedi_unbalance_ensemble.x",
                "ungrib.exe",
                "link_grib.csh",
                "obs2ioda_v3",
            ):
                (install / "bin" / name).write_text("", encoding="utf-8")
            (install / "share" / "wps" / "Variable_Tables").mkdir(parents=True)

            contract = _module().build_contract(args)

        self.assertTrue(contract["capabilities"]["mpas"])
        self.assertTrue(contract["capabilities"]["mpas_jedi"])
        self.assertTrue(contract["capabilities"]["wps"])
        self.assertTrue(contract["capabilities"]["obs2ioda"])
        self.assertIn("ungrib.exe", contract["canonical_executables"])
        self.assertIn("obs2ioda_v3", contract["canonical_executables"])


if __name__ == "__main__":
    unittest.main()
