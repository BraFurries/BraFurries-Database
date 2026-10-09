# Release record: Community membership and Team assignments (2026-09-30)

## Status and authority

The reviewed schema changes were applied in production through the transitional, manually mirrored DDL process **before** production Flyway baseline adoption. This record is descriptive; it is not an instruction to reapply DDL and does not assert the existence of `flyway_schema_history`.

The canonical source of schema behavior remains the versioned SQL under `flyway/sql/versioned/`.

## Schema changes

- `V20260930_001__enforce_unique_user_community_status.sql` enforces one membership record per `(community_id, user_id)`, using `uk_user_community_status_community_user`.
- `V20260930_002__create_community_team_role_assignments.sql` creates a Community-scoped N:N assignment table for Users and Team roles.

Before the uniqueness constraint was applied, historical duplicate memberships were reconciled, and the membership writer had been hardened to avoid recreating duplicates. The reviewed migrations were validated against a disposable MariaDB instance before application.

## Schema contracts

`community_team_role_assignments` uses:

- composite primary key `(community_id, role_id, user_id)`;
- index `idx_ctra_community_user (community_id, user_id)`;
- `created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)`;
- same-Community composite foreign keys `fk_ctra_member_same_community` and `fk_ctra_role_same_community`.

The foreign keys prevent associations between a membership and a Team role belonging to different Communities. The versioned SQL remains authoritative for exact constraints and update/delete semantics.

## Application compatibility

The Community member directory and Team-assignment workflows depend on these schema contracts. Schema rollout preceded application enablement.

## Publication boundary and follow-up

Detailed production query output, workflow run identifiers, host details, and deployment checkpoints are intentionally excluded from this publication-facing record.

A future production Flyway baseline must recognize the schema effects already applied through the transitional process; it must not replay these migrations against an already-migrated schema.
