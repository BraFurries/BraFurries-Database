"""Synthetic-only tests for the offline schema inventory comparison."""
from __future__ import annotations

import contextlib
import importlib.util
import io
import sys
import tempfile
import unittest
from pathlib import Path

import yaml


SCRIPTS_DIR = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))
SPEC = importlib.util.spec_from_file_location(
    "reconcile_schema_inventory", SCRIPTS_DIR / "reconcile_schema_inventory.py"
)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class SchemaInventoryTests(unittest.TestCase):
    def _check(self, sql: str, names: list[str], count: int | None = None) -> tuple[int, str]:
        with tempfile.TemporaryDirectory() as td:
            sql_path = Path(td) / "sample.sql"
            manifest_path = Path(td) / "manifest.yaml"
            sql_path.write_text(sql, encoding="utf-8")
            manifest_path.write_text(
                yaml.safe_dump({
                    "tables": [{"table": name} for name in names],
                    "table_count_expected": len(names) if count is None else count,
                }),
                encoding="utf-8",
            )
            capture = io.StringIO()
            with contextlib.redirect_stdout(capture), contextlib.redirect_stderr(capture):
                status = MODULE.reconcile(sql_path, manifest_path)
            return status, capture.getvalue()

    def test_exact_set_independent_of_export_order(self) -> None:
        status, output = self._check(
            "CREATE TABLE IF NOT EXISTS `two` (id INT);\n"
            "CREATE TABLE `one` (id INT);\n",
            ["one", "two"],
        )
        self.assertEqual(status, 0)
        self.assertIn("All exported table names match", output)

    def test_reports_both_missing_sides(self) -> None:
        status, output = self._check(
            "CREATE TABLE `new` (id INT);",
            ["old"],
        )
        self.assertEqual(status, 1)
        self.assertIn("+ new", output)
        self.assertIn("- old", output)

    def test_rejects_duplicate_table_definitions(self) -> None:
        status, output = self._check(
            "CREATE TABLE `same` (id INT);\nCREATE TABLE `same` (id INT);",
            ["same"],
        )
        self.assertEqual(status, 1)
        self.assertIn("Duplicate CREATE TABLE names", output)

    def test_rejects_no_definitions(self) -> None:
        status, output = self._check("-- not a structure dump", [])
        self.assertEqual(status, 2)
        self.assertIn("No CREATE TABLE", output)

    def test_rejects_stale_manifest_count(self) -> None:
        status, output = self._check(
            "CREATE TABLE `ok` (id INT);",
            ["ok"],
            count=3,
        )
        self.assertEqual(status, 1)
        self.assertIn("Manifest expected count", output)


if __name__ == "__main__":
    unittest.main()
