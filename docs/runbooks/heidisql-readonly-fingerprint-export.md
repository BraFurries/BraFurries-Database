# Read-only HeidiSQL export for the pre-recruitment 107-table schema

This optional operator workflow reduces the approved *six metadata queries*
to **one result grid** plus an offline CSV-to-JSON conversion. Neither the SQL
nor the importer changes the database. The importer **never connects** to any
database. The executable SQL is
`validation/sql/physical_schema_readonly_capture.sql`.

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

Open `validation/sql/physical_schema_readonly_capture.sql` in a HeidiSQL
query tab connected to the **approved** schema and execute the SELECT.
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
