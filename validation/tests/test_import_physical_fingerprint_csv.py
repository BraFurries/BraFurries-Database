"""Offline HeidiSQL CSV importer: integrity, delimiters and baseline counts."""
from __future__ import annotations

import csv
import importlib.util
import json
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))
SPEC = importlib.util.spec_from_file_location(
    "import_physical_fingerprint_csv",
    SCRIPTS / "import_physical_fingerprint_csv.py",
)
assert SPEC and SPEC.loader
MOD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MOD)


def synthetic_rows():
    return [
        ("tables", {"table": "sample", "engine": "InnoDB"}),
        ("columns", {"table": "sample", "column": "id", "position": 1, "type": "int"}),
        ("indexes", {"table": "sample", "index": "PRIMARY", "sequence": 1}),
        ("foreign_keys", {"table": "sample", "constraint": "fk_other", "position": 1}),
        ("checks", {"table": "sample", "constraint": "ck_positive", "expression": "id > 0"}),
        ("environment", {"mariadb_version": "10.6.22-MariaDB",
                         "schema_collation": "utf8mb4_general_ci",
                         "server_collation": "utf8mb4_general_ci"}),
    ]


def write_csv(path, rows, delimiter=",", *, bom=False):
    with path.open("w", encoding="utf-8-sig" if bom else "utf-8", newline="") as fd:
        writer = csv.writer(fd, delimiter=delimiter)
        writer.writerow(["section", "metadata"])
        for section, obj in rows:
            writer.writerow([section, json.dumps(obj, ensure_ascii=False)])


class HeidiSqlFingerprintImportTests(unittest.TestCase):
    def test_csv_comma_semicolon_tab_and_bom(self):
        for delimiter in (",", ";", "\t"):
            with self.subTest(delimiter=repr(delimiter)):
                with TemporaryDirectory() as folder:
                    path = Path(folder) / "metadata.csv"
                    write_csv(path, synthetic_rows(), delimiter, bom=True)
                    doc = MOD.load_csv(path, verify_baseline=False)
                    self.assertEqual(doc["sections"]["tables"][0]["table"], "sample")
                    self.assertEqual(doc["environment"]["mariadb_version"], "10.6.22-MariaDB")

    def test_rejects_partial_csv_unknown_sections_and_duplicate_environment(self):
        with TemporaryDirectory() as folder:
            path = Path(folder) / "metadata.csv"
            for rows in (
                synthetic_rows()[:1],
                synthetic_rows() + [synthetic_rows()[-1]],
                synthetic_rows() + [("unknown", {"table": "x"})],
            ):
                write_csv(path, rows)
                with self.assertRaises(MOD.FingerprintError):
                    MOD.load_csv(path, verify_baseline=False)

    def test_rejects_invalid_payloads_and_duplicate_keys(self):
        with TemporaryDirectory() as folder:
            path = Path(folder) / "metadata.csv"
            write_csv(path, synthetic_rows() + [synthetic_rows()[0]])
            with self.assertRaises(MOD.FingerprintError):
                MOD.load_csv(path, verify_baseline=False)
            path.write_text('section,metadata\ntables,broken_json\n', encoding="utf-8")
            with self.assertRaises(MOD.FingerprintError):
                MOD.load_csv(path, verify_baseline=False)

    def test_baseline_mode_requires_107_946_127_52(self):
        with TemporaryDirectory() as folder:
            path = Path(folder) / "metadata.csv"
            write_csv(path, synthetic_rows())
            with self.assertRaises(MOD.FingerprintError):
                MOD.load_csv(path)

            rows = []
            rows.extend(("tables", {"table": f"t{i:03}", "engine": "InnoDB"})
                        for i in range(107))
            rows.extend(("columns", {"table": f"t{i%107:03}",
                                      "column": f"c{i}", "position": i//107+1})
                        for i in range(946))
            rows.extend(("indexes", {"table": f"t{i:03}",
                                      "index": "PRIMARY", "sequence": 1})
                        for i in range(107))
            rows.extend(("foreign_keys", {"table": f"t{i:03}",
                                           "constraint": f"fk{i}", "position": 1})
                        for i in range(127))
            rows.extend(("checks", {"table": f"t{i:03}",
                                     "constraint": f"ck{i}", "expression": "1 > 0"})
                        for i in range(52))
            rows.append(synthetic_rows()[-1])
            write_csv(path, rows)
            observed = MOD.load_csv(path)
            self.assertEqual(len(observed["sections"]["columns"]), 946)

            # Even one dropped row must prevent a superficially successful comparison.
            write_csv(path, rows[:-2] + rows[-1:])
            with self.assertRaises(MOD.FingerprintError):
                MOD.load_csv(path)

    def test_readonly_sql_uses_metadata_sources_and_no_table_writes(self):
        guide = (SCRIPTS.parents[1] / "docs" / "runbooks"
                 / "heidisql-readonly-fingerprint-export.md"
                 ).read_text(encoding="utf-8")
        sql = guide.split("```sql\\n", 1)[1].split("\\n```", 1)[0]
        executable = "\n".join(line for line in sql.splitlines()
                               if not line.strip().startswith("--")).upper()
        self.assertIn("INFORMATION_SCHEMA.TABLES", executable)
        self.assertIn("INFORMATION_SCHEMA.CHECK_CONSTRAINTS", executable)
        self.assertNotIn("FROM `USERS`", executable)
        for action in ("INSERT INTO ", "UPDATE `", "DELETE FROM ", "ALTER TABLE ",
                       "DROP TABLE ", "CREATE TABLE "):
            self.assertNotIn(action, executable)

    def test_cli_refuses_output_inside_repository(self):
        with TemporaryDirectory() as folder:
            inp = Path(folder) / "source.csv"
            write_csv(inp, synthetic_rows())
            with patch.object(sys, "argv", ["fingerprint-import", str(inp),
                                             str(SCRIPTS.parent / "do-not-create.json")]):
                self.assertEqual(MOD.main(), 2)


if __name__ == "__main__":
    unittest.main()
