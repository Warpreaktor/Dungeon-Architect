"""Tests for the test runner without requiring Godot."""

from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import run_tests


class RunnerTests(unittest.TestCase):
    def test_discovery_sorted_and_filtered(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "tests").mkdir()
            for name in ("test_z.gd", "test_a.gd", "helper.gd"):
                (root / "tests" / name).touch()
            self.assertEqual([p.name for p in run_tests.discover(root, "")],
                             ["test_a.gd", "test_z.gd"])
            self.assertEqual([p.name for p in run_tests.discover(root, "_Z")], ["test_z.gd"])

    def test_failure_is_detected_even_with_zero_exit_code(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "tests" / "test_a.gd"
            path.parent.mkdir()
            path.touch()
            with patch("run_tests.subprocess.run") as execute:
                execute.return_value.returncode = 0
                execute.return_value.stdout = "SCRIPT ERROR: Assertion failed.\n"
                execute.return_value.stderr = ""
                self.assertEqual(run_tests.run_test("godot", root, path, 1)[0], "FAIL")

    def test_group_manifest_matches_existing_tests(self):
        root = Path(__file__).resolve().parents[2]
        configured = run_tests.group_regression_tests(root)
        discovered = {item.name for item in run_tests.discover(root, "")}
        self.assertEqual(len(configured), 19)
        self.assertTrue(configured <= discovered, sorted(configured - discovered))

    def test_timeout_is_reported(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "tests" / "test_a.gd"
            path.parent.mkdir()
            path.touch()
            with patch("run_tests.subprocess.run", side_effect=run_tests.subprocess.TimeoutExpired("godot", 1)):
                self.assertEqual(run_tests.run_test("godot", root, path, 1)[0], "TIMEOUT")


if __name__ == "__main__":
    unittest.main()
