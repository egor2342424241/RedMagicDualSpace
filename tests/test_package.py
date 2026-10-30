import pathlib
import subprocess
import tempfile
import unittest
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]


class PackageTests(unittest.TestCase):
    def test_build_creates_installable_kernel_su_archive(self):
        with tempfile.TemporaryDirectory() as temp:
            output = pathlib.Path(temp) / "module.zip"
            result = subprocess.run(
                ["sh", str(ROOT / "tools" / "build-module.sh"), str(output)],
                cwd=ROOT,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(output.is_file())
            with zipfile.ZipFile(output) as archive:
                names = set(archive.namelist())
                self.assertTrue({
                    "module.prop",
                    "scripts/dualspace.sh",
                    "webroot/index.html",
                    "webroot/app.js",
                    "webroot/kernelsu-api.js",
                    "webroot/style.css",
                }.issubset(names))
                metadata = archive.read("module.prop").decode("utf-8")
                self.assertIn("id=redmagicdualspace", metadata)
                script = archive.getinfo("scripts/dualspace.sh")
                self.assertEqual((script.external_attr >> 16) & 0o777, 0o755)
                self.assertNotIn("service.sh", names)
                self.assertNotIn("uninstall.sh", names)
                app = archive.read("webroot/app.js").decode("utf-8")
                bridge = archive.read("webroot/kernelsu-api.js").decode("utf-8")
                self.assertIn("./kernelsu-api.js", app)
                self.assertIn("window.ksu.exec", bridge)


if __name__ == "__main__":
    unittest.main()
