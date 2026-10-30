import os
import pathlib
import shutil
import stat
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "dualspace.sh"
FAKES = ROOT / "tests" / "fakes"


class DualSpaceControllerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.tmp = pathlib.Path(self.temp.name)
        self.state = self.tmp / "state"
        self.fake_bin = self.tmp / "bin"
        self.fake_bin.mkdir()
        for fake in FAKES.iterdir():
            if fake.is_file():
                target = self.fake_bin / fake.name
                shutil.copyfile(fake, target)
                target.chmod(0o755)
        self.log = self.tmp / "am.log"
        self.create_log = self.tmp / "create.log"
        self.env = os.environ.copy()
        self.env.update({
            "PATH": str(self.fake_bin) + os.pathsep + self.env.get("PATH", ""),
            "RMDSS_STATE_DIR": str(self.state),
            "FAKE_CURRENT_USER": "0",
            "FAKE_USERS": "UserInfo{0:Owner:13}",
            "FAKE_AM_LOG": str(self.log),
            "FAKE_CREATE_LOG": str(self.create_log),
            "FAKE_CREATED_USERS_FILE": str(self.tmp / "created-users.txt"),
            "FAKE_CREATE_OUTPUT": "Success: created user id 10",
        })

    def tearDown(self):
        self.temp.cleanup()

    def run_controller(self, action):
        return subprocess.run(
            ["sh", str(SCRIPT), action],
            text=True,
            capture_output=True,
            env=self.env,
            check=False,
        )

    def test_create_managed_user_saves_numeric_id(self):
        result = self.run_controller("create")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.state / "user_id").read_text().strip(), "10")
        self.assertEqual(stat.S_IMODE(self.state.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE((self.state / "user_id").stat().st_mode), 0o600)
        self.assertIn("10", result.stdout)
        self.assertEqual(
            self.create_log.read_text().strip(),
            "create-user --user-type android.os.usertype.full.SECONDARY RedMagic DualSpace",
        )

    def test_create_rejects_missing_user_id_in_command_output(self):
        self.env["FAKE_CREATE_OUTPUT"] = "Success but no user identifier"
        result = self.run_controller("create")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("valid user ID", result.stderr)
        self.assertFalse((self.state / "user_id").exists())

    def test_controller_rejects_extra_arguments(self):
        result = subprocess.run(
            ["sh", str(SCRIPT), "status", "unexpected"],
            text=True,
            capture_output=True,
            env=self.env,
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no extra arguments", result.stderr)

    def test_create_reuses_existing_exact_name_user(self):
        self.env["FAKE_USERS"] = (
            "UserInfo{0:Owner:13}\nUserInfo{12:RedMagic DualSpace:10}"
        )
        result = self.run_controller("create")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.state / "user_id").read_text().strip(), "12")
        self.assertFalse(self.create_log.exists(), "must not create a duplicate user")

    def test_create_is_rejected_outside_owner_user(self):
        self.env["FAKE_CURRENT_USER"] = "12"
        result = self.run_controller("create")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("owner", result.stderr.lower())
        self.assertFalse(self.create_log.exists())

    def test_switch_space_recovers_stale_saved_id_by_exact_name(self):
        self.state.mkdir(parents=True)
        (self.state / "user_id").write_text("11\n")
        self.env["FAKE_USERS"] = (
            "UserInfo{0:Owner:13}\n"
            "UserInfo{11:Other User:10}\n"
            "UserInfo{12:RedMagic DualSpace:10}"
        )
        result = self.run_controller("switch-space")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.state / "user_id").read_text().strip(), "12")
        self.assertEqual(self.log.read_text().strip(), "switch-user 12")

    def test_switch_space_rejects_when_managed_user_is_missing(self):
        self.state.mkdir(parents=True)
        (self.state / "user_id").write_text("12\n")
        result = self.run_controller("switch-space")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not found", result.stderr.lower())
        self.assertFalse(self.log.exists())

    def test_switch_space_verifies_id_against_exact_live_user_name(self):
        self.state.mkdir(parents=True)
        (self.state / "user_id").write_text("12\n")
        self.env["FAKE_USERS"] = (
            "UserInfo{0:Owner:13}\nUserInfo{12:RedMagic DualSpace:10}"
        )
        result = self.run_controller("switch-space")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text().strip(), "switch-user 12")

    def test_switch_owner_targets_user_zero(self):
        result = self.run_controller("switch-owner")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text().strip(), "switch-user 0")

    def test_status_reports_device_and_user_context(self):
        result = self.run_controller("status")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("REDMAGIC 10 Pro", result.stdout)
        self.assertIn("Android 16", result.stdout)
        self.assertIn("Current user: 0", result.stdout)
        self.assertIn("UserInfo{0:Owner:13}", result.stdout)


if __name__ == "__main__":
    unittest.main()
