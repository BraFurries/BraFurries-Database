# Release record: Community authorization and member notes (2026-10-02)

## Status and authority

These schema changes were applied in production through the approved transitional process before formal Flyway baseline adoption. The canonical DDL is the versioned SQL in `flyway/sql/versioned/`. This record does **not** mean a `flyway_schema_history` entry exists.

## Schema changes

- `V20261001_002__create_community_authorization_foundation.sql`
  - adds nullable `communities.owner_user_id`;
  - creates `community_team_role_capabilities`, `community_user_capability_grants`, and `community_audit_log`.
- `V20261001_003__create_community_member_notes.sql`
  - creates Community-scoped member notes with tenant-aware membership constraints and author/editor references.

These migrations were reviewed and validated against disposable MariaDB. The authorization foundation was applied before member notes, preserving foreign-key dependencies.

## Required compatibility and isolation

The release depends on the uniqueness of membership by `(community_id, user_id)` and Community-aware constraints for Team roles and member notes.

Application-layer authorization remains in the API, while the Database owns schema definitions. Front-End controls are not a substitute for server-side authorization.

The deployed applications were coordinated to consume the schema only after its application. Schema changes were not created by the API or Discord runtime.

## Publication boundary and follow-up

This public-facing record omits production SQL outputs, workflow run numbers, commit/deployment checkpoints, and machine-specific operational details.

A future production Flyway baseline must account for these already-applied schema objects without recreating them. The exact migration definitions and any necessary compatibility checks remain in the versioned SQL and runbooks.
