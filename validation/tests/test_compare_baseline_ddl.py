"""Unit tests of full table DDL normalization without production dump access."""
from __future__ import annotations

import contextlib
import importlib.util
import io
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
SPEC = importlib.util.spec_from_file_location("compare_baseline_ddl", SCRIPTS / "compare_baseline_ddl.py")
assert SPEC and SPEC.loader
MOD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MOD)


class BaselineComparisonTests(unittest.TestCase):
    def _compare(self, source: str, baseline: str) -> tuple[int, str]:
        with tempfile.TemporaryDirectory() as td:
            a, b = Path(td)/"source.sql", Path(td)/"baseline.sql"
            a.write_text(source,encoding="utf-8")
            b.write_text(baseline,encoding="utf-8")
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                code = MOD.compare(a,b)
            return code,output.getvalue()

    def test_ignores_table_order_and_auto_increment_counters(self):
        first = (
            "CREATE TABLE IF NOT EXISTS \x60b\x60 (\n  \x60id\x60 int NOT NULL\n) "
            "ENGINE=InnoDB AUTO_INCREMENT=501 DEFAULT CHARSET=utf8mb4;\n"
            "CREATE TABLE IF NOT EXISTS \x60a\x60 (\n  \x60id\x60 int NOT NULL\n) "
            "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;\n"
        )
        second = (
            "CREATE TABLE \x60a\x60 (\n  \x60id\x60 int NOT NULL\n) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;\n"
            "CREATE TABLE \x60b\x60 (\n  \x60id\x60 int NOT NULL\n) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;\n"
        )
        result, output = self._compare(first,second)
        self.assertEqual(result,0,output)
        self.assertIn("MATCH:",output)

    def test_flags_column_type_difference(self):
        first = "CREATE TABLE \x60item\x60 (\n  \x60id\x60 int NOT NULL\n) ENGINE=InnoDB;\n"
        second = first.replace(" int NOT NULL"," bigint NOT NULL")
        result,output = self._compare(first,second)
        self.assertEqual(result,1)
        self.assertIn("item",output)

    def test_flags_missing_table(self):
        first = "CREATE TABLE \x60item\x60 (\n  \x60id\x60 int NOT NULL\n) ENGINE=InnoDB;\n"
        result, output = self._compare(first,"CREATE TABLE \x60other\x60 (\n  \x60id\x60 int NOT NULL\n) ENGINE=InnoDB;\n")
        self.assertEqual(result,1)
        self.assertIn("Missing from baseline: 1",output)

    def test_rejects_duplicate_table(self):
        sql = "CREATE TABLE \x60a\x60 (\n  \x60id\x60 int\n) ENGINE=InnoDB;\n"
        with self.assertRaises(ValueError):
            MOD.structural_statements(sql*2)


if __name__ == "__main__":
    unittest.main()
