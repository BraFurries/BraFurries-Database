# BraFurries-Database

Governance and future schema-evolution authority for the MariaDB database shared by the BraFurries ecosystem.

## Current phase

This repository contains additive versioned migrations and disposable local/CI validation infrastructure. Production baseline adoption remains a separate operation.

Until the production Flyway baseline and restricted host-side wrapper are adopted, a reviewed versioned migration may be mirrored manually in production only as an explicit transitional rollout with preflight, postconditions, and recorded evidence. The 2026-09-30 Community membership/Team-assignment rollout used that transitional path; see [the release evidence](docs/releases/2026-09-30-community-membership-team-assignments.md).

It currently defines:

- schema authority and application boundaries;
- table ownership, readers, writers, and historical destructive-merge evidence;
- approved future use of Flyway;
- production-baseline and fresh-database strategies;
- expand/contract and N/N-1 compatibility rules;
- the retirement process for legacy Discord runtime DDL;
- conceptual release and recovery runbooks;
- a pinned Flyway Open Source CLI and disposable MariaDB 10.6 validation harness;
- ownership, migration-naming, YAML, and Markdown validation gates.

It does **not** yet contain an official baseline. The [corrected production-export reconciliation](docs/legacy/2026-10-19-production-schema-reconciliation.md) counts **107 tables** in the latest owner-provided structure-only export and **93 manifest entries**: every cataloged table appears in that export, while **14 additional production-export tables** lack ownership entries. An earlier 101-table export omitted six definitions; this does not prove those tables were absent from the live database. Versioned history starts with the structural adoption of `user_identity_links`.

## Authority

`BraFurries-Database` is the future authoritative source for all shared schema evolution.

- `BraFurries-API` remains configured with `spring.jpa.hibernate.ddl-auto=none` and must not mutate schema automatically.
- `BraFurries-Discord` retired its known literal runtime schema-changing SQL through its October 2026 PRs (#23–#32). Static inspection is not proof against all dynamic/indirect SQL paths; no new runtime DDL may be introduced.
- Flyway is the approved future migration engine, executed outside API and Discord startup.
- Production baseline adoption remains a manual operation through a restricted host-side wrapper and dedicated migration credential once that operational path is implemented.
- Before that adoption, any exceptional manual production DDL must match reviewed versioned SQL exactly and be recorded under `docs/releases/`; it does not create or imply Flyway history.

## Repository map

- [`ARCHITECTURE.md`](ARCHITECTURE.md): current and target architecture.
- [`AGENTS.md`](AGENTS.md): mandatory rules for contributors and automation.
- [`docs/adr/`](docs/adr/): accepted architectural decisions.
- [`docs/compatibility/`](docs/compatibility/): cross-application schema compatibility policy.
- [`docs/legacy/`](docs/legacy/): legacy Discord DDL, runner, history, and local-draft records.
- [`docs/migrations/`](docs/migrations/): future migration naming and path policy.
- [`docs/releases/`](docs/releases/): production rollout evidence for reviewed schema changes.
- [`docs/runbooks/`](docs/runbooks/): conceptual production runbooks and executable disposable-validation guidance.
- [`flyway/`](flyway/): reserved official SQL layout and validation-only Flyway configuration.
- [`ownership/`](ownership/): machine-readable table ownership and identifier semantics.
- [`validation/`](validation/): disposable Compose harness, isolated test fixture, and validators.

## Evidence versus authority

`coddy-schema-current.sql`, located outside this repository, is a no-data structural export of the current production database and was used as audit evidence. It is not copied into this repository.

The dump is not yet a canonical baseline. A sanitized, reviewed representation will be produced only in a later approved phase.

Production release evidence records observed preconditions and postconditions, but the versioned SQL under `flyway/sql/versioned/` remains the schema-change authority.

## Local drafts are not official history

Four SQL files found only in a local working copy predate this governance. They are classified as:

> `LOCAL_DRAFT / NOT_REMOTE`

They are not part of the official migration history, remain outside the Phase 2 harness, and must not be promoted without being redesigned and reviewed after baseline adoption. See [`docs/legacy/local-drafts.md`](docs/legacy/local-drafts.md).

## Local validation

Install the pinned validation dependency, run static gates, and execute the disposable database smoke test:

```text
python -m pip install -r validation/requirements.txt
python validation/scripts/validate_repository.py
python validation/scripts/validate_ownership.py
python validation/scripts/validate_migrations.py
python validation/scripts/smoke_test.py
```

See [`docs/runbooks/local-validation.md`](docs/runbooks/local-validation.md) for the pinned versions, safety guards, lifecycle, CI gates, and teardown command.

## Current non-goals

This phase does not:

- create an official baseline or unrelated migration;
- copy a production dump;
- connect GitHub-hosted CI to any production database or VM;
- change API or Discord code;
- remove legacy runtime DDL;
- create production workflows, wrappers, credentials, containers, users, or secrets;
- promote the four `LOCAL_DRAFT / NOT_REMOTE` files;
- propose immediate deletion of legacy or unused objects.

## Confirmed data-model decisions

- `user_level` is logically unique by `(user_id, server_guild_id)`.
- weekly and monthly game statistics are isolated by guild.
- `user_community_status` represents current state and is logically unique by `(user_id, community_id)`; the production schema now enforces this through the reviewed Community rollout recorded under `docs/releases/`.
- non-destructive identity links are managed by the API; destructive identity merge is abandoned.
- `minigame_scores` is functionally owned by Discord.
- unknown historical XP must not be invented or redistributed without evidence.
- irreconstructible historical statistics remain documented as incomplete.

Decisions are enforced only where an applied, reviewed migration or existing production constraint is explicitly evidenced. Documentation alone must not be treated as proof of production shape.

## Safety

Never use this repository as authorization to access production. Never place credentials, raw production data, or secret-bearing configuration here.
