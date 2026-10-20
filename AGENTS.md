# AGENTS.md

Rules for contributors and Codex agents working in `BraFurries-Database`.

## Purpose

This repository is the schema authority for the MariaDB database shared by:

- `BraFurries-Discord`;
- `BraFurries-API`;
- frontend consumers indirectly through API contracts.

Domain ownership and schema authority are different. A table may belong to Discord, API, or both while all schema changes are versioned here.

## Public-repository and data-boundary status

This repository is the active public Database schema-governance repository.
Older private infrastructure/history is not a source of executable migrations.
Never copy historical private refs, unredacted production exports, database
contents, personal identifiers, credentials, operational secrets or backups
into this repository or CI artifacts. Keep adoption/versioned evidence as
reviewable, sanitized SQL and documentation.

## Current phase restriction

The repository contains reviewed additive versioned migrations and a sanitized 107-table baseline candidate with disposable MariaDB validation. No production Flyway baseline has been executed or authorized.

Do not add without a separately approved task:

- unrelated baseline SQL or a new baseline version without a separate architecture review;
- repeatable migrations or unrelated versioned migrations;
- migration binaries or dependencies outside the approved validation harness;
- database execution scripts outside disposable validation;
- Dockerfiles, production wrappers, or production workflows;
- credentials, secrets, dumps, or production snapshots.

Local SQL files documented as `LOCAL_DRAFT / NOT_REMOTE` are not official history and must not be committed or treated as applied migrations.

## Mandatory safety rules

- Never access production MariaDB, the production VM, credentials, `.env`, secret stores, or deployment systems without a separate explicit request and safety confirmation.
- Never start API or Discord when they might contact production services.
- Never execute migrations against a real database as part of routine validation.
- Never commit or push unless explicitly requested.
- Never push directly to `main`.
- Never include raw production data or the raw production schema dump.
- Preserve unrelated and untracked user work.

## Schema governance

- `BraFurries-Database` is the authoritative home for schema governance and evolution after the public-repository cutover.
- Flyway is the approved future engine, but it is not implemented in Phase 1.
- API and Discord must not apply future shared-schema migrations during startup.
- API production must retain `spring.jpa.hibernate.ddl-auto=none`.
- No new runtime DDL may be introduced in Discord.
- Existing Discord runtime DDL is legacy and must be retired one path at a time.
- Absence of a current consumer does not authorize dropping an object.

Before any future schema change:

1. inspect the ownership manifest;
2. identify all readers, writers, and any historical identity-consolidation behavior;
3. inspect both API and Discord code where relevant;
4. identify ID semantics and references without foreign keys;
5. document N/N-1 compatibility and deployment order;
6. prefer expand/contract and additive transitions;
7. document preconditions, data impact, validation, recovery, and human approvals.

## Ownership manifest rules

[`ownership/tables.yaml`](ownership/tables.yaml) must contain every known table.

Do not infer ownership from:

- the presence of a JPA Entity or Repository;
- historical destructive-consolidation code;
- a legacy runtime initializer;
- absence of a code reference.

Use `UNKNOWN` or `TODO_*` when evidence is insufficient. Keep these dimensions separate:

- `domain_owner`;
- runtime readers;
- runtime writers;
- historical destructive-merge writer evidence;
- current DDL owner;
- future schema authority;
- lifecycle status.

## Identifier semantics

Do not assume every `user_id` is `users.id` or every guild-related field has the same representation.

Consult [`ownership/id-semantics.yaml`](ownership/id-semantics.yaml). In particular:

- `users.id` is an internal user ID;
- `user_discord.id` is the internal Discord-link ID;
- `user_discord.discord_user_id` is a Discord snowflake;
- `community_discord.id` is the internal Discord-community-link ID;
- `community_discord.guild_id` is a Discord guild snowflake;
- some fields store snowflakes directly without foreign keys;
- some references are polymorphic or intentionally lack foreign keys.

## Future migration rules

When migration implementation is separately approved:

- use the approved Flyway structure and versioning policy;
- never edit an applied migration;
- keep migrations focused and reviewable;
- test against MariaDB 10.6;
- keep `baselineOnMigrate` disabled for production;
- never use Flyway `clean` outside a disposable environment;
- do not automate `repair`;
- do not assume transactional rollback for multi-statement MariaDB DDL;
- keep production execution outside API and Discord startup.

## Legacy Discord DDL

Existing DDL follows this retirement state machine:

```text
UNMAPPED_DDL
→ EXPECTED_SCHEMA_DOCUMENTED
→ COVERED_BY_BASELINE_OR_MIGRATION
→ CHECK_ONLY
→ OBSERVED
→ RETIRED
```

Do not skip directly from runtime mutation to removal without proving the schema is already present and compatible.

## Validation

For documentation-only work:

- validate Markdown links and YAML syntax;
- verify the ownership manifest covers all 107 exported tables exactly once;
- verify no unapproved SQL, dumps, credentials, or secrets were added;
- verify local drafts remain untracked and unpromoted;
- verify API and Discord repositories are unchanged;
- review `git diff` and `git status` before completion.

For migration changes, run the static validators and Docker Compose configuration check. Run the full disposable smoke test when Docker is safely available, and always confirm teardown left no project container or volume.
