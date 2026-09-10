"""Exercise trial cleanup with fake desktop commands, never the live session."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

MOCK = r'''
import os
from pathlib import Path
import sys
import time
root = Path(os.environ["QS_TEST_ROOT"])
name = Path(sys.argv[0]).name
args = sys.argv[1:]
scenario = os.environ["QS_TEST_SCENARIO"]
with (root / "calls").open("a") as output:
    output.write(name + " " + " ".join(args) + "\n")
if name == "systemctl":
    if "is-active" in args and scenario == "inactive":
        sys.exit(3)
elif name == "hyprctl":
    if scenario == "bind-failure" and "ipc" in args[-1]:
        sys.exit(1)
elif name == "qs":
    if "ipc" in args:
        sys.exit(0 if (root / "started").exists() else 1)
    if scenario == "start-failure":
        sys.exit(42)
    (root / "started").touch()
    time.sleep(0.6)
'''


class SessionTest(unittest.TestCase):
    def run_trial(self, scenario):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for command in ("systemctl", "hyprctl", "qs"):
                file = root / command
                file.write_text(f"#!{sys.executable}\n{MOCK}")
                file.chmod(0o755)
            env = dict(os.environ, QS_TEST_ROOT=directory, QS_TEST_SCENARIO=scenario,
                       XDG_RUNTIME_DIR=directory, HYPRLAND_INSTANCE_SIGNATURE="test-only",
                       PATH=directory + os.pathsep + os.environ["PATH"])
            result = subprocess.run(["bash", str(Path(__file__).with_name("session.sh"))],
                                    env=env, capture_output=True, text=True, timeout=10)
            return result, (root / "calls").read_text()

    def test_normal_exit_restores_both_services_and_launcher(self):
        result, calls = self.run_trial("normal")
        self.assertEqual(result.returncode, 0, result.stderr)
        for unit in ("waybar.service", "mako.service"):
            self.assertIn(f"systemctl --user stop {unit}", calls)
            self.assertIn(f"systemctl --user start {unit}", calls)
        self.assertIn('hl.dsp.exec_cmd("wofi --show drun")', calls)

    def test_failed_start_restores_services_without_rebinding(self):
        result, calls = self.run_trial("start-failure")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("systemctl --user start mako.service", calls)
        self.assertNotIn("hl.unbind", calls)

    def test_failed_bind_also_restores_original_launcher(self):
        result, calls = self.run_trial("bind-failure")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('hl.dsp.exec_cmd("wofi --show drun")', calls)
        self.assertIn("systemctl --user start waybar.service", calls)

    def test_inactive_services_stay_inactive(self):
        result, calls = self.run_trial("inactive")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("systemctl --user start", calls)
        self.assertNotIn("systemctl --user stop", calls)


if __name__ == "__main__":
    unittest.main()
