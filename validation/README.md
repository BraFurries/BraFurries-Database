# Disposable validation

This directory is the complete Phase 2 local/CI harness:

- `compose.yaml`: pinned MariaDB and Flyway services on an internal network;
- `disposable-compose.env`: explicit empty Compose environment boundary;
- `fixtures/flyway-smoke/`: isolated, synthetic Flyway test history;
- `scripts/`: ownership, migration, documentation, safety, and smoke validators;
- `requirements.txt`: pinned Python validation dependency.

Run the harness only through the commands in [`docs/runbooks/local-validation.md`](../docs/runbooks/local-validation.md). Nothing here is a production migration artifact.
