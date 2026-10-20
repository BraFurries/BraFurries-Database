# Disposable validation

This directory provides isolated local/CI validation for both historical versioned migrations and the candidate 107-table structural Flyway baseline:

- `compose.yaml`: pinned MariaDB and Flyway services on an internal network;
- `disposable-compose.env`: explicit empty Compose environment boundary;
- `fixtures/flyway-smoke/`: isolated, synthetic Flyway test history;
- `scripts/`: ownership, migration, documentation, safety, historical smoke, offline full-DDL comparison, and 107-table baseline smoke validators;
- `requirements.txt`: pinned Python validation dependency.

Run the harness only through the commands in [`docs/runbooks/local-validation.md`](../docs/runbooks/local-validation.md). Nothing here is a production migration artifact.
