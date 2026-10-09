# Architecture

## Purpose

`BraFurries-Database` is the future authoritative source for schema evolution of the MariaDB database shared by the BraFurries ecosystem.

This repository coordinates schema. It does not take functional ownership away from Discord or API domain owners.

## Current state

- Production has 78 audited tables.
- The real schema is evidenced by an external no-data dump.
- Discord still performs extensive runtime `CREATE`, `ALTER`, `RENAME`, index removal, and column removal.
- Discord also has a legacy `schema_migrations` table and Python migration runner.
- API production uses `spring.jpa.hibernate.ddl-auto=none`.
- The remote Database repository had no official migration history before this governance bootstrap.
- Four local SQL files are `LOCAL_DRAFT / NOT_REMOTE` and are not authoritative.
- Phase 2 provides pinned, disposable local/CI validation with Flyway Open Source 13.4.0 and MariaDB 10.6.28.
- The baseline directory remains empty. Versioned history starts with the additive `user_identity_links` structure already present in production.

## Target state

```text
BraFurries-Database
    |
    +-- schema authority
    +-- reviewed Flyway migrations
    +-- ownership manifest
    +-- validation and release policy
    |
    +------> BraFurries-API
    |        ddl-auto=none
    |        DML only
    |
    +------> BraFurries-Discord
             DML only
             no runtime schema mutation
```

Flyway will execute as a separate host-side migration process. Neither application will run it during startup.

## Responsibility boundaries

### Database repository

- Owns schema versioning and migration metadata.
- Records table ownership and lifecycle status.
- Defines compatibility, validation, release, and recovery policy.
- Produces future migration artifacts.
- Does not contain production credentials.

### API

- Owns API/auth/events/partners functionality where documented.
- Manages non-destructive identity links and their administrative audit trail.
- Never consolidates identity by deleting Users or moving their historical records.
- Keeps Hibernate schema mutation disabled.
- Aligns Entities to the canonical schema rather than generating it.

### Discord

- Owns operational Discord functionality where documented.
- Must not gain new runtime DDL.
- Retires existing initializers and lazy ensures incrementally.
- Eventually operates with a database credential that cannot execute DDL.

### Production migration executor

- Runs host-side on the shared VM.
- Uses a narrow wrapper and dedicated database credential.
- Is invoked manually for first adoption.
- Does not require Docker group membership.
- Is not exposed to GitHub-hosted runners.

## Schema adoption

Production already contains the schema. It will be adopted by an explicit Flyway baseline operation that records the current state without recreating objects.

Fresh databases will use a separately reviewed executable baseline representation and all later versioned migrations.

The baseline command and the fresh-database baseline are related by version but have different behavior. Historical migrations that never existed will not be fabricated.

The external production dump remains audit evidence only. No raw dump or canonical baseline is included in Phase 1.

## Compatibility model

API and Discord deploy independently. Schema evolution follows expand/contract:

1. apply an additive schema expansion;
2. deploy compatible writers and readers;
3. reconcile/backfill when evidence permits;
4. observe both systems;
5. perform contract only after N-1 is no longer supported.

Every future migration must document a compatibility matrix for Database, API, and Discord.

## Domain ownership versus technical access

The ownership manifest separates:

- functional `domain_owner`;
- normal runtime readers;
- normal runtime writers;
- historical destructive-merge writer evidence (normally empty after retirement);
- current DDL owner;
- future schema authority.

Identity links do not change the ownership of Discord-owned data and do not authorize cross-User mutation.

## Runtime DDL transition

No new runtime DDL may be introduced in Discord after adoption of this governance.

Existing paths move through:

```text
UNMAPPED_DDL
→ EXPECTED_SCHEMA_DOCUMENTED
→ COVERED_BY_BASELINE_OR_MIGRATION
→ CHECK_ONLY
→ OBSERVED
→ RETIRED
```

Destructive operations and lazy DDL have the highest retirement priority. This phase documents them but does not alter Discord.

## Legacy migration history

`schema_migrations` and `scripts/run_migrations.py` belong to the Discord migration mechanism.

- The table is preserved as legacy history.
- Its rows will not be copied into `flyway_schema_history`.
- The runner will be frozen and retired after Flyway adoption.
- Two active versioners will not be maintained indefinitely.

## Confirmed logical data model

### XP

`user_level` is logically keyed by:

```text
(user_id, server_guild_id)
```

The current unique constraint on `user_id` conflicts with this rule. Historical XP without reliable guild evidence must not be invented or distributed artificially.

### Game statistics

Weekly and monthly game statistics are isolated by guild. Current unique constraints do not include guild and conflict with the logical model.

Historical data that cannot be reconstructed confidently will be marked incomplete rather than redistributed by inference.

### Community status

`user_community_status` represents current state and is logically keyed by:

```text
(user_id, community_id)
```

Production has one duplicate group containing 21 rows. A later reconciliation must determine field-level winners before enforcing uniqueness.

## Linked user identities

Destructive account consolidation is abandoned. BraFurries-API manages auditable links between distinct Users through `user_identity_links`; BraFurries-Discord may read the same links only for staff moderation context. Every User retains its own Discord link, credentials, permissions, tokens, history, XP, economy, inventory, community state, and owned resources.

Each row is an undirected edge between two semantically equivalent endpoints, `user_a_id` and `user_b_id`; there is no primary, secondary, or root User. The database canonicalizes each active pair through `active_user_low_id` and `active_user_high_id`, rejects duplicate active edges in either direction, and continues to reject self-links. `CONFIRMED` edges form transitive identity clusters for read-only moderation history with provenance: if A is confirmed with B and B with C, all three belong to the same confirmed cluster. `SUSPECTED` edges remain administrative context only and never join a confirmed cluster. Revocation is soft and audited.

Any future data transfer is an explicit, selective domain operation and is not identity linking.

## Identifier model

Internal IDs and Discord snowflakes coexist. The authoritative catalog is [`ownership/id-semantics.yaml`](ownership/id-semantics.yaml).

No identifier normalization is part of Phase 1.

## Lifecycle statuses

Legacy, abandoned, unused, obsolete, future, and unimplemented are documentation states. They do not authorize object deletion.

## Validation boundary

MariaDB validation uses internal networking and ephemeral storage. Official versioned migrations are exercised only in this disposable environment.

This phase contains no:

- baseline;
- production database or VM access;
- production workflow;
- application change;
- runtime-DDL removal;
- secret or credential;
- raw production dump.
