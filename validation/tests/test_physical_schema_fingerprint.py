"""Offline fingerprint guarantees: stable hash, missing metadata and drift."""
from __future__ import annotations

import contextlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
SPEC = importlib.util.spec_from_file_location(
    "physical_schema_fingerprint", SCRIPTS / "physical_schema_fingerprint.py"
)
assert SPEC and SPEC.loader
F = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(F)


def example():
    return {
        "format": F.FORMAT,
        "environment": {"mariadb_version": "10.6.synthetic", "schema_collation": "unicode"},
        "sections": {
            "tables": [{"table": "a", "engine": "InnoDB"}],
            "columns": [{"table": "a", "position": 1, "column": "id",
                         "type": "int(11)", "nullable": "NO", "default": None}],
            "indexes": [{"table": "a", "index": "PRIMARY", "sequence": 1,
                         "column": "id", "non_unique": 0}],
            "foreign_keys": [],
            "checks": [{"table": "a", "constraint": "ck_positive", "expression": "id > 0"}],
        },
    }


class FingerprintTests(unittest.TestCase):
    def test_environment_version_not_hashed(self):
        baseline = example()
        observed = example()
        observed["environment"]["mariadb_version"] = "10.6.some-other-patch"
        self.assertEqual(F.fingerprint(baseline), F.fingerprint(observed))
        self.assertEqual(F.diffs(baseline, observed), [])

    def test_reordered_sections_and_rows_have_identical_hash(self):
        a = example()
        a["sections"]["columns"].append({
            "table": "a", "position": 2, "column": "value", "type": "text",
        })
        b = json.loads(json.dumps(a))
        b["sections"]["columns"].reverse()
        self.assertEqual(F.fingerprint(a), F.fingerprint(b))

    def test_reports_column_index_and_check_drift(self):
        a, b = example(), example()
        b["sections"]["columns"][0]["type"] = "bigint(20)"
        b["sections"]["indexes"][0]["non_unique"] = 1
        b["sections"]["checks"][0]["expression"] = "id >= 0"
        self.assertEqual(len(F.diffs(a,b)), 3)
        self.assertNotEqual(F.fingerprint(a), F.fingerprint(b))

    def test_missing_column_and_extra_index_detected(self):
        a, b = example(), example()
        b["sections"]["columns"].append({"table":"a","position":2,"column":"extra"})
        b["sections"]["indexes"].clear()
        self.assertTrue(any("unexpected" in row for row in F.diffs(a,b)))
        self.assertTrue(any("missing" in row for row in F.diffs(a,b)))

    def test_rejects_incomplete_empty_and_duplicate_metadata(self):
        a = example()
        del a["sections"]["checks"]
        with self.assertRaises(F.FingerprintError):
            F.normalize(a)
        a = example()
        a["sections"]["tables"] = []
        with self.assertRaises(F.FingerprintError):
            F.fingerprint(a)
        a = example()
        a["sections"]["columns"].append(dict(a["sections"]["columns"][0]))
        with self.assertRaises(F.FingerprintError):
            F.normalize(a)

    def test_cli_comparison_is_strict_and_does_not_print_data(self):
        with tempfile.TemporaryDirectory() as dir:
            first, second = Path(dir) / "expected.json", Path(dir) / "observed.json"
            first.write_text(json.dumps(example()), encoding="utf-8")
            second.write_text(json.dumps(example()), encoding="utf-8")
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                self.assertEqual(F.compare_files(first, second), 0)
            self.assertIn("Structural differences: 0", out.getvalue())
            changed = example()
            changed["sections"]["columns"][0]["type"] = "varchar(255)"
            second.write_text(json.dumps(changed), encoding="utf-8")
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                self.assertEqual(F.compare_files(first, second), 1)
            self.assertIn("changed a/id", out.getvalue())
            self.assertNotIn("varchar(255)", out.getvalue())


if __name__ == "__main__":
    unittest.main()
