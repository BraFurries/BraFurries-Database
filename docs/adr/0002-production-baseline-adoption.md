# ADR 0002: Adopt the existing production schema with an explicit baseline

- Status: Accepted; implementation deferred
- Date: 2026-09-02

## Context

Production already has 78 tables created through historical runtime DDL, manual work, and one Discord SQL migration. There is no official complete migration history.

Executing a creation baseline over production would collide with existing objects. Fabricating historical Flyway rows would misrepresent how the schema was created.

## Decision

Production will be adopted through an explicit, one-time Flyway baseline operation.

- The operation will record the accepted current version without recreating existing objects.
- It will run manually through the future restricted host-side wrapper.
- `baselineOnMigrate` will not be used.
- A fingerprint must match the reviewed adoption snapshot before the operation.
- A backup and tested recovery path are mandatory.
- `schema_migrations` remains legacy evidence and is not imported into Flyway history.

Fresh databases will use a separately reviewed executable baseline representation with the same logical adoption version, followed by later versioned migrations.

Phase 1 creates neither representation nor Flyway metadata.

## Rationale

This approach distinguishes two facts:

1. production already has an accepted schema state;
2. a fresh database needs an executable way to create that state.

The baseline history row describes adoption, not fictional historical execution.

## Adoption evidence

The later adoption package must record:

- export timestamp and source environment identifier without secrets;
- MariaDB version;
- charset and collation metadata;
- normalized structural fingerprint;
- checksum of the original audit dump;
- checksum of the sanitized canonical representation;
- table count;
- review approvals;
- read-only record of the legacy `schema_migrations` contents.

## Preconditions

- no unresolved schema drift;
- temporary freeze on manual and runtime DDL;
- fresh restore validation on MariaDB 10.6;
- API and Discord compatibility validation;
- backup and restore test;
- confirmation that no external deploy process invokes the legacy runner.

## Alternatives considered

### Execute a large V1 over production

Rejected because all objects already exist.

### Enable baseline-on-migrate

Rejected because it removes an important wrong-target safety check.

### Fabricate past migrations

Rejected because it creates false provenance.

### Import `schema_migrations`

Rejected because Flyway did not execute or checksum those scripts.

## Risks

- Drift between snapshot capture and baseline execution.
- A no-data dump does not prove data constraints are safe.
- Runtime DDL can mutate schema during adoption unless quiesced.
- Fresh-install reference data is outside a no-data baseline and needs separate inventory.

## Not decided here

- adoption version;
- baseline file name;
- baseline SQL;
- maintenance window;
- backup technology;
- required reference data.
