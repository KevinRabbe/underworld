#!/usr/bin/env python3

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

import validate_project_status as validator


class ProjectStatusValidatorTests(unittest.TestCase):
    def _write_fixture(self, root: Path) -> dict:
        manifest = {
            "schema_revision": 1,
            "accepted_main": "a" * 40,
            "last_synced_at": "2026-09-17",
            "project_mode": "CORE_PLAYABLE_INTEGRATION",
            "playable_state": "NOT_YET",
            "current_gate": {"issue": 539, "state": "REVIEW_WIP_1", "summary": "gate"},
            "next_transition": "next",
            "world_model": {
                "domains": ["OVERWORLD", "UNDERWORLD"],
                "underworld_topology": "CONTINUOUS_BIOME_WORLD",
                "exploration_scale_direction": {
                    "overworld_percent": 40,
                    "underworld_percent": 60,
                    "metric": "DIRECTIONAL_EXPLORATION_ALLOCATION_NOT_RADIUS",
                },
            },
            "authorities": {"board": 33},
            "milestones": [
                {
                    "id": "CORE_PLAYABLE",
                    "state": "NOT_ACHIEVED",
                    "authority_issue": 752,
                    "summary": "not yet",
                }
            ],
            "topology_gates": [
                {"issue": 872, "name": "a", "state": "PLANNED"},
                {"issue": 873, "name": "b", "state": "PLANNED"},
                {"issue": 875, "name": "c", "state": "PLANNED"},
                {"issue": 876, "name": "d", "state": "PLANNED"},
                {"issue": 877, "name": "e", "state": "PLANNED"},
                {"issue": 878, "name": "f", "state": "PLANNED"},
            ],
            "scale_program": {"issue": 874, "state": "PLANNED"},
            "status_policy": {
                "numeric_progress": "ONLY_FROM_EXPLICIT_FINITE_GATE_SET",
                "live_authority": "issues",
            },
        }

        project_dir = root / "docs/00_project"
        project_dir.mkdir(parents=True)
        (root / "tools/ci").mkdir(parents=True)
        (project_dir / "project_status.json").write_text(json.dumps(manifest), encoding="utf-8")

        markers = "\n".join(
            [
                "<!-- PROJECT_STATUS_PLAYABLE_STATE: NOT_YET -->",
                f"<!-- PROJECT_STATUS_ACCEPTED_MAIN: {'a' * 40} -->",
                "<!-- PROJECT_STATUS_WORLD_MODEL: OVERWORLD+UNDERWORLD_CONTINUOUS_BIOMES -->",
            ]
        )
        (project_dir / "PROJECT_STATUS.md").write_text(markers + "\n", encoding="utf-8")
        (root / "README.md").write_text(
            markers + "\nSee docs/00_project/PROJECT_STATUS.md\n",
            encoding="utf-8",
        )
        return manifest

    def test_valid_snapshot_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self._write_fixture(root)
            self.assertEqual([], validator.validate(root))

    def test_stale_readme_marker_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self._write_fixture(root)
            readme = root / "README.md"
            readme.write_text(readme.read_text(encoding="utf-8").replace("NOT_YET", "CORE_PLAYABLE"), encoding="utf-8")
            errors = validator.validate(root)
            self.assertTrue(any("README.md missing or stale marker" in error for error in errors), errors)

    def test_invalid_sha_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            manifest = self._write_fixture(root)
            manifest["accepted_main"] = "short"
            (root / "docs/00_project/project_status.json").write_text(json.dumps(manifest), encoding="utf-8")
            errors = validator.validate(root)
            self.assertTrue(any("accepted_main" in error for error in errors), errors)

    def test_hidden_third_domain_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            manifest = self._write_fixture(root)
            manifest["world_model"]["domains"].append("UNDERWORLD_LAYER_2")
            (root / "docs/00_project/project_status.json").write_text(json.dumps(manifest), encoding="utf-8")
            errors = validator.validate(root)
            self.assertTrue(any("exactly [OVERWORLD, UNDERWORLD]" in error for error in errors), errors)

    def test_arbitrary_progress_policy_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            manifest = self._write_fixture(root)
            manifest["status_policy"]["numeric_progress"] = "SUBJECTIVE_PERCENT"
            (root / "docs/00_project/project_status.json").write_text(json.dumps(manifest), encoding="utf-8")
            errors = validator.validate(root)
            self.assertTrue(any("arbitrary percentages" in error for error in errors), errors)


if __name__ == "__main__":
    unittest.main()
