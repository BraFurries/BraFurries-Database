# ADR 0001: Flyway as the future migration engine

- Status: Accepted; implementation deferred
- Date: 2026-09-02

## Context

BraFurries-Discord and BraFurries-API share one MariaDB database and deploy independently. Discord currently contains runtime schema mutations and a small Python migration runner. API production has Hibernate schema mutation disabled.

The ecosystem needs one versioned schema authority with ordering, checksums, validation, and concurrency coordination.

## Decision

Flyway will be the future migration engine.

- Migration sources will live only in BraFurries-Database.
- Flyway will execute outside API and Discord startup.
- Production will use a pinned host-side CLI invoked through a restricted wrapper.
- First production adoption will be manual.
- A dedicated MariaDB migration credential will be used.
- GitHub-hosted runners will never access production.
- `baselineOnMigrate` will remain disabled in production.
- `clean` will remain disabled outside disposable validation environments.

Phase 1 does not install or configure Flyway.

## Rationale

Flyway provides capabilities missing from the current runner:

- deterministic ordering;
- checksums;
- schema history;
- validation;
- database-coordinated locking;
- explicit baseline support;
- MariaDB-aware SQL parsing.

Keeping execution outside applications preserves independent deploys and prevents API or Discord startup from becoming a schema-control plane.

## Alternatives considered

### Keep the Python runner

Rejected as the long-term solution. It has no checksum, naïvely splits on semicolons, and would require reimplementing locking and recovery semantics.

### Run Flyway in Spring Boot startup

Rejected. It couples migrations to API availability and makes one application operationally responsible for shared schema.

### Run Flyway in Discord startup

Rejected for the same reason and because Discord runtime DDL is being retired.

### Liquibase

Viable, but its additional abstraction and changelog complexity do not currently provide a necessary advantage over reviewed MariaDB SQL with Flyway.

### Production container

Deferred. A container is not required for host-native MariaDB and would create unnecessary Docker permission concerns on the shared VM.

## Consequences

- Database changes become independent release artifacts.
- API and Discord application users will eventually lose DDL grants.
- Migration version and MariaDB driver must be pinned and tested.
- Operational migration execution needs a separate restricted wrapper.
- Existing Discord DDL and migration history require a controlled retirement period.

## Risks

- Running multiple Flyway versions can change behavior; pin the version.
- `repair` can hide metadata problems if misused; never automate it.
- Flyway locking does not replace release-level single-flight controls.
- MariaDB DDL recovery must not be treated as multi-statement transactional rollback.

## Not decided here

- exact Flyway version or edition;
- exact wrapper implementation;
- production secret mechanism;
- migration naming/version value;
- any SQL content.
