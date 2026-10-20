# Local and CI schema validation

## Scope and safety boundary

This runbook covers only disposable local and GitHub-hosted CI validation. It is not a production migration runbook and contains no production host, IP, URL, database name, credential, secret, or environment integration.

The harness never starts BraFurries-API or BraFurries-Discord. It never reads either application's `.env` files and never publishes the MariaDB port to the host.

## Pinned toolchain

| component | exact selection | purpose |
|---|---|---|
| Flyway | `flyway/flyway:13.4.0` | Open Source CLI/container for `info`, `migrate`, and `validate` |
| MariaDB | `mariadb:10.6.28` | Exact disposable target within the approved 10.6 series |
| JDBC driver | MariaDB Connector/J, `org.mariadb.jdbc.Driver` | Bundled with the Flyway CLI image |

Redgate's current documentation records Flyway 13.4.0 as the 2026-08-26 release, describes `flyway/flyway` as the Open Source image, confirms that the CLI ships the MariaDB driver, and lists MariaDB 10.6 for foundational migration capabilities. Community/Open Source functionality is sufficient because this phase uses only SQL migrations and the core `info`, `migrate`, and `validate` commands.

Official references:

- [Flyway 13.4.0 release notes](https://documentation.red-gate.com/flyway/release-notes-and-older-versions/release-notes-for-flyway-engine)
- [Flyway Docker editions and usage](https://documentation.red-gate.com/fd/flyway-docker-321585710.html)
- [MariaDB driver reference](https://documentation.red-gate.com/flyway/reference/database-driver-reference/mariadb)
- [Supported MariaDB versions and capabilities](https://documentation.red-gate.com/fd/supported-database-versions-143754067.html)
- [MariaDB 10.6.28 official image tag](https://hub.docker.com/_/mariadb/tags?name=10.6&page=1)

No paid capability is required. If a future requirement needs a licensed feature, adoption must stop for an explicit edition/license decision.

### Upgrade strategy

Upgrade Flyway or MariaDB only through a reviewed pull request that changes the exact image tag, reviews upstream release and compatibility notes, runs the complete disposable smoke test, and records any behavior or driver change. Floating tags such as `latest`, `13`, or `10.6` are forbidden.

## Prerequisites

- Python 3.11 or later;
- Docker Engine or Docker Desktop with Docker Compose v2;
- network access only when the pinned images or Python dependency must first be downloaded.

Install the single pinned Python dependency:

```text
python -m pip install -r validation/requirements.txt
```

## Static validation

Run from the repository root:

```text
python validation/scripts/validate_repository.py
python validation/scripts/validate_ownership.py
python validation/scripts/validate_migrations.py --allow-official
docker compose --env-file validation/disposable-compose.env --project-name brafurries_flyway_phase2 --file validation/compose.yaml config --quiet
```

`--allow-official` validates the reviewed versioned history, names, and version uniqueness. Omitting it remains a safety check that proves official SQL is not accidentally accepted by legacy Phase 2 callers.

## Full smoke test

```text
python validation/scripts/smoke_test.py
```

The script performs safety preflight before container creation, then:

1. starts MariaDB 10.6.28 and waits for its healthcheck;
2. confirms the test database starts empty;
3. runs Flyway `info`, `migrate`, `info`, and `validate`;
4. checks the synthetic table, fixture row, history row, and stored checksum;
5. proves that a temporary modified copy triggers checksum mismatch;
6. runs `migrate` again and proves history/data idempotence;
7. destroys containers and storage;
8. recreates an empty database and reapplies/validates the fixture;
9. performs final teardown and verifies no project container or volume remains.

Cleanup also runs after failure. To destroy an interrupted environment manually, use only the fixed project and Compose file:

```text
docker compose --env-file validation/disposable-compose.env --project-name brafurries_flyway_phase2 --file validation/compose.yaml down --volumes --remove-orphans
```

## Disposable design

- MariaDB data uses container `tmpfs`; no persistent or host database directory is mounted.
- The network is `internal: true` and neither service publishes a host port.
- Credentials are synthetic, hardcoded, and scoped only to the disposable Compose network.
- Flyway mounts the test configuration, smoke fixture, and official versioned directory as read-only.
- The database name is fixed to `brf_flyway_smoke_test`.
- The fixture creates only `__brf_flyway_smoke_test` plus Flyway's own history table.

The fixture is executable test input. It is intentionally outside `flyway/sql/` and is never part of official schema history.

## Safety guards

Before `docker compose up`, `smoke_test.py` renders and validates the effective Compose configuration. It aborts unless:

- the database host is exactly the internal `mariadb` service;
- the database name is exactly the test-only name and does not contain `coddy`;
- image versions match the pinned constants;
- the active Docker endpoint is a local Unix socket or Windows named pipe, never TCP/SSH;
- no service publishes ports, uses host networking, defines extra hosts, or builds a local image;
- all networks are internal;
- MariaDB storage is disposable `tmpfs`;
- connection and production-like environment overrides are absent.

Only environment-variable names are reported on rejection; values are never read or printed. An explicit empty Compose env file prevents automatic discovery of an unrelated `.env`.

## CI gates

`.github/workflows/schema-validation.yml` currently runs on pull requests (not pushes to `main`) using GitHub-hosted Ubuntu runners with read-only repository permission and no environment or secrets. It checks:

- YAML parsing with duplicate-key rejection;
- local Markdown link targets;
- the now **107-entry ownership manifest** and registered values. Private structure-only exports may be reconciled offline by the [production inventory checker](production-inventory-check.md); CI never fetches the dump and the comparison only checks table names;
- migration paths, naming, uniqueness, reserved draft versions, and approved official SQL;
- rendered Docker Compose validity;
- the complete disposable Flyway/MariaDB smoke test.

CI does not use SSH, a self-hosted runner, a production environment, or any deploy step.

## Still prohibited

- production VM or database access;
- real credentials or application `.env` files;
- unreviewed baseline, repeatable, or unrelated versioned SQL;
- production baseline or `baselineOnMigrate`;
- promotion of `LOCAL_DRAFT / NOT_REMOTE` files;
- Flyway execution from API or Discord startup;
- Flyway `clean` or automated `repair`;
- production wrapper, user, deploy, or workflow;
- production dumps or snapshots.
