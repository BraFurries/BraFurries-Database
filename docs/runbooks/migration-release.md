# Conceptual runbook: migration release

## Status

The target Flyway production execution path remains conceptual: this repository still contains no executable production wrapper, credentials, or deploy workflow.

Before baseline adoption, reviewed versioned SQL may be mirrored manually in production only as an explicitly approved transitional exception. Such execution must use the canonical versioned SQL, satisfy the same preflight/postcondition expectations, and record evidence under `docs/releases/`. This does not create `flyway_schema_history` and does not authorize arbitrary manual SQL.

The 2026-09-30 Community membership/Team-assignment rollout is the first recorded example of that transitional path.

## Objective

Release one reviewed Database schema version while preserving independent API and Discord deployments and N/N-1 compatibility.

## Change proposal

The proposal must identify:

- domain owner;
- schema authority;
- affected tables/columns/keys;
- runtime readers and writers;
- identity-link compatibility and confirmation that no historical records are moved;
- references without foreign keys;
- current Discord DDL paths;
- data volume and anomaly preconditions;
- API/Discord N/N-1 compatibility;
- deploy order and observation window;
- recovery strategy.

## CI gates

1. File naming and version uniqueness.
2. Immutable-history check.
3. SQL execution in disposable MariaDB 10.6.
4. Fresh database creation from baseline plus all versions.
5. Upgrade from the adopted production shape.
6. Synthetic anomaly fixtures for data-sensitive changes.
7. Flyway checksum validation.
8. Normalized schema fingerprint.
9. API JPA validation against the migrated schema.
10. Discord compatibility validation with no real services.
11. N/N-1 compatibility matrix approval.

## Production preflight

- approved immutable artifact;
- exact expected current Flyway version when Flyway history has been adopted;
- verified target environment;
- dedicated migration credential or explicitly approved transitional operator path;
- backup and restore evidence appropriate to risk;
- lock/duration estimate;
- maintenance window when required;
- API/Discord deploy artifacts ready in the documented order;
- no legacy runner execution;
- no competing migration release.

## Release sequence

Target Flyway path:

1. Freeze conflicting deploys.
2. Verify target, version, artifact checksum, and preconditions.
3. Review Flyway information and validation result.
4. Apply the migration through the restricted host-side wrapper.
5. Run structural and data postconditions.
6. Stop on any unexpected result.
7. Deploy application writers/readers in documented order.
8. Observe logs, errors, locks, and domain metrics.
9. Record release evidence.
10. Keep contract actions disabled until a later approved release.

Transitional pre-baseline exception:

1. Freeze or order conflicting writers as required by the migration.
2. Verify the exact reviewed migration artifact and production preconditions.
3. Execute only the canonical DDL represented by the reviewed versioned migration.
4. Run the documented structural/data postconditions.
5. Record evidence under `docs/releases/`, including the fact that Flyway metadata was not created.
6. Continue application rollout only after the postconditions pass.

## Single-flight rule

Flyway database locking is necessary but not sufficient. The operational wrapper must also prevent concurrent releases on the VM. Transitional manual execution must likewise be serialized operationally.

## Completion criteria

For Flyway-managed production:

- expected Flyway version is current;
- checksums validate;
- postconditions pass;
- API and Discord supported versions operate correctly;
- no runtime DDL changed the resulting schema;
- rollback target remains compatible;
- evidence package is complete.

For a transitional pre-baseline rollout:

- the exact reviewed schema effect is present;
- structural/data postconditions pass;
- the release evidence explicitly states that no Flyway history entry was created;
- dependent application deployments pass their production health gates;
- the evidence package is complete.

## Prohibited shortcuts

- application startup migration;
- direct production access from GitHub-hosted CI;
- manual SQL that is not the reviewed versioned release;
- treating a transitional manual application as Flyway baseline/history;
- editing an applied migration;
- automatic `repair`;
- enabling `baselineOnMigrate`;
- combining expand and destructive contract in one rollout.
