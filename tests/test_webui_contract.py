import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
MODULE_ID = "redmagicdualspace"


class WebUiContractTests(unittest.TestCase):
    def test_module_id_matches_shell_install_path(self):
        prop = ROOT / "module.prop"
        values = {}
        for line in prop.read_text().splitlines():
            if "=" in line and not line.lstrip().startswith("#"):
                key, value = line.split("=", 1)
                values[key.strip()] = value.strip()
        self.assertEqual(values.get("id"), MODULE_ID)
        self.assertIn(f"/data/adb/modules/{MODULE_ID}/scripts/dualspace.sh", (ROOT / "webroot" / "app.js").read_text())

    def test_webui_has_kernel_su_entrypoint_and_fixed_actions(self):
        index = (ROOT / "webroot" / "index.html").read_text()
        app = (ROOT / "webroot" / "app.js").read_text()
        self.assertIn("id=\"app\"", index)
        self.assertIn("app.js", index)
        self.assertIn("import { exec } from 'kernelsu'", app)
        for action in ("status", "create", "switch-owner", "switch-space"):
            self.assertIn(action, app)
        self.assertIn("new Set", app)
        self.assertIn("await exec(", app)
        self.assertIn("confirm(", app)

    def test_webui_does_not_expose_arbitrary_shell_or_delete_actions(self):
        app = (ROOT / "webroot" / "app.js").read_text().lower()
        index = (ROOT / "webroot" / "index.html").read_text().lower()
        self.assertNotIn("remove-user", app)
        self.assertNotIn("delete-user", app)
        self.assertNotIn("command-input", index)
        self.assertNotIn("contenteditable", index)
        self.assertIn("textcontent", app)


if __name__ == "__main__":
    unittest.main()
