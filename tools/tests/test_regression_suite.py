"""Verify that regression coverage does not exclude earlier project stages."""

from pathlib import Path
import unittest

import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import run_tests


class RegressionSuiteTests(unittest.TestCase):
    def test_legacy_and_new_test_scripts_are_discovered(self):
        root = Path(__file__).resolve().parents[2]
        found = {item.name for item in run_tests.discover(root, "")}
        required = {
            "test_battle_state.gd",
            "test_battle_combat_items.gd",
            "test_monster_encounter_party.gd",
            "test_reachability.gd",
            "test_traps.gd",
            "test_regression_phase_lifecycle.gd",
            "test_regression_seed_determinism.gd",
            "test_regression_group_combat.gd",
        }
        self.assertTrue(required <= found, f"Missing regression scripts: {sorted(required - found)}")

    def test_filter_discovers_every_new_regression(self):
        root = Path(__file__).resolve().parents[2]
        found = run_tests.discover(root, "regression_")
        self.assertGreaterEqual(len(found), 3)
        self.assertEqual(found, sorted(found))


if __name__ == "__main__":
    unittest.main()
