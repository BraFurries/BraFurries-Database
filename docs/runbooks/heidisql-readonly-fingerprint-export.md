# Read-only HeidiSQL export for the pre-recruitment 107-table schema

This optional operator workflow reduces the approved *six metadata queries*
to **one result grid** plus an offline CSV-to-JSON conversion. Neither the SQL
nor the importer changes the database. The importer **never connects** to any
database. The exact single-query SQL is embedded below as a documented, read-only query. No executable migration SQL is added.

## Before running

1. Verify the selected database in HeidiSQL with
   `SELECT DATABASE() AS selected_schema, VERSION() AS version;` and compare
   the observed target with the independently approved environment identity.
2. Use a restricted, read-only account with metadata visibility over **all**
   107 application tables; a user lacking permissions can export an incomplete
   snapshot that happens to contain some expected names.
3. Do not store real connection details, credentials, backups or outputs in
   Git, pull requests, shared CI, issues or chat attachments. The provided
   dump is *structure-only*, not a recovery-tested backup.
4. **Do not run Flyway baseline/migrate/repair/clean or production DDL.**
   This workflow does not authorize production schema changes.

## Export one HeidiSQL result

Open a HeidiSQL query tab connected to the **approved** schema. Copy and execute the following single SELECT (this is not a migration):

```sql
-- BraFurries Database: read-only physical fingerprint export for HeidiSQL.
-- Open a connection to the intended schema first, verify SELECT DATABASE()
-- returns the expected schema, and export this SINGLE result grid to CSV.
-- CSV must include column headers, have two columns: section, metadata;
-- save it privately, outside Git, without user data or passwords.
-- READ-ONLY: accesses information_schema and server metadata ONLY.
-- Never run against an ambiguous default schema. Do NOT use production
-- connection info or credentials in repository files or GitHub Actions.
--
-- Note: each row is individually JSON-encoded (no JSON_ARRAYAGG), avoiding
-- group_concat_max_len truncation. No data rows or application tables queried.

SELECT 'tables' AS `section`,
  JSON_OBJECT('table',TABLE_NAME,'engine',ENGINE,
    'table_collation',TABLE_COLLATION,'row_format',ROW_FORMAT) AS `metadata`
FROM information_schema.TABLES
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_TYPE='BASE TABLE'
  AND TABLE_NAME<>'flyway_schema_history'
UNION ALL
SELECT 'columns',
  JSON_OBJECT('table',TABLE_NAME,'column',COLUMN_NAME,
    'position',ORDINAL_POSITION,'type',COLUMN_TYPE,
    'nullable',IS_NULLABLE,'default',COLUMN_DEFAULT,'extra',EXTRA,
    'expression',GENERATION_EXPRESSION,
    'charset',CHARACTER_SET_NAME,'collation',COLLATION_NAME)
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME<>'flyway_schema_history'
UNION ALL
SELECT 'indexes',
  JSON_OBJECT('table',TABLE_NAME,'index',INDEX_NAME,'sequence',SEQ_IN_INDEX,
    'column',COLUMN_NAME,'non_unique',NON_UNIQUE,'sub_part',SUB_PART,
    'index_type',INDEX_TYPE,'collation',COLLATION)
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME<>'flyway_schema_history'
UNION ALL
SELECT 'foreign_keys',
  JSON_OBJECT('table',k.TABLE_NAME,'constraint',k.CONSTRAINT_NAME,
    'position',k.ORDINAL_POSITION,'column',k.COLUMN_NAME,
    'referenced_table',k.REFERENCED_TABLE_NAME,
    'referenced_column',k.REFERENCED_COLUMN_NAME,
    'on_delete',r.DELETE_RULE,'on_update',r.UPDATE_RULE)
FROM information_schema.KEY_COLUMN_USAGE k
JOIN information_schema.REFERENTIAL_CONSTRAINTS r
  ON r.CONSTRAINT_SCHEMA=k.CONSTRAINT_SCHEMA
 AND r.CONSTRAINT_NAME=k.CONSTRAINT_NAME
 AND r.TABLE_NAME=k.TABLE_NAME
WHERE k.TABLE_SCHEMA=DATABASE()
  AND k.TABLE_NAME<>'flyway_schema_history'
  AND k.REFERENCED_TABLE_NAME IS NOT NULL
UNION ALL
SELECT 'checks',
  JSON_OBJECT('table',TABLE_NAME,'constraint',CONSTRAINT_NAME,
    'expression',CHECK_CLAUSE)
FROM information_schema.CHECK_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA=DATABASE()
  AND TABLE_NAME<>'flyway_schema_history'
UNION ALL
SELECT 'environment',
  JSON_OBJECT('mariadb_version',VERSION(),
    'schema_collation',
      (SELECT DEFAULT_COLLATION_NAME FROM information_schema.SCHEMATA
        WHERE SCHEMA_NAME=DATABASE()),
    'server_collation',@@collation_server);
```


It returns two columns, `section` and `metadata`, with one JSON object per
physical schema record. It does not aggregate records or query application
tables; export the entire result grid, **not just the selected rows**.

Export results as a UTF-8 CSV with **column headers enabled**, delimiter
comma, semicolon or tab, and standard double-quote CSV escaping. Save to
a private workstation folder, for example
`C:\\BraFurries-Auditoria\\metadata.csv`. Avoid worksheet formats that truncate
cell contents. The CSV must contain all `tables`, `columns`, `indexes`,
`foreign_keys`, `checks` rows and one `environment` row.

The query does not output database passwords, application data rows or the
database name, but object names and CHECK expressions are private metadata.

## Convert CSV, offline (Python 3.12)

From the Database repo root with the feature branch checked out:

```powershell
py -3 validation/scripts/import_physical_fingerprint_csv.py `
  "C:\BraFurries-Auditoria\metadata.csv" `
  "C:\BraFurries-Auditoria\observed.json"
```

The importer rejects duplicates, broken JSON, incomplete sections, the wrong
MariaDB major/minor family, non-baseline counts, and output paths within
the repository. For this specific pre-recruitment baseline it requires
**107 tables, 946 columns, 127 distinct foreign-key constraints and 52 CHECKs**.
Do **not** suppress these validations to get a passing result.

## Expected reference and offline comparison

Use the `capture-disposable` command from the fixed pre-recruitment
baseline capture implementation in Database PR #26 (Flyway targeted to
`20261020.001`). **Never** use it against a real database, and never repoint
its hard-coded disposable Compose connection.

```powershell
py -3 validation/scripts/physical_schema_fingerprint.py capture-disposable `
  "C:\BraFurries-Auditoria\expected.json"

py -3 validation/scripts/physical_schema_fingerprint.py compare `
  "C:\BraFurries-Auditoria\expected.json" `
  "C:\BraFurries-Auditoria\observed.json"
```

Exit 0 and `Structural differences: 0` is a necessary structural gate.
Exit 1 means drift; exit 2 means invalid/incomplete input. Any nonzero exit
**blocks** the baseline and recruitment migrations until investigated.

This does not prove that the backup restores, guarantee permissions or
application compatibility, or substitute for an approved maintenance plan.
The backup **restoration test** remains a hard production schema-release gate.

## Current rollout relationship

- DB PR #26: fixes reference capture to stop at the 107-table baseline.
- This PR: offers a HeidiSQL-only, one-query read-only capture and offline importer.
- Recruiting DB PR #25: additive incident notice schema on top of the
  stacked recruitment migrations. No production deployment is implied.

Keep the physical snapshot/CSV on the trusted workstation; share only the
expected/observed hash values and sanitized difference counts.
