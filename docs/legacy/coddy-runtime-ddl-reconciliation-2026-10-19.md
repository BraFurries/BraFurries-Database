# Runtime DDL reconciliation — Coddy (2026-10-19)

> **Atualização após os merges — 19/10/2026:** este inventário abaixo
> preserva o estado **histórico** do Coddy em `45f6397`; suas contagens,
> funções e observações sobre PR #23 não descrevem mais a `main`.
> Na `main` `e701680`, as PRs #23–#32 já foram integradas em etapas,
> com os quatro últimos deploys verificados; a varredura textual de 79 arquivos
> Python de runtime não encontrou comandos DDL explícitos. O limite de SQL
> dinâmico/indireto permanece e o baseline Flyway não foi implantado.
> Consulte [a reconciliação de 101 tabelas vs 93 entradas do manifesto](2026-10-19-production-schema-reconciliation.md)
> antes de propor baseline.
>

> **Read-only code audit, not a production database audit.** This report supplements
> `docs/legacy/discord-runtime-ddl.md` and the retirement tracking issue
> [BraFurries-Discord #3](https://github.com/BraFurries/BraFurries-Discord/issues/3).
> Source reviewed: `BraFurries-Discord` main `45f6397c2321903e035bf26559c7d1515a6b10da`.
> No schema mutation, runtime deploy, Flyway baseline, or production validation
> was performed as part of this inventory.

## Findings

A case-insensitive scan for `CREATE|ALTER|DROP|RENAME|TRUNCATE` +
`TABLE|INDEX|COLUMN|DATABASE|VIEW` identified **54 textual DDL statement
sites** in `core/database.py` and **2** in `cogs/xp.py`. This is a count
of source-code sites, **not** tables, operations executed, Flyway migrations,
or proof of exhaustiveness. SQL assembled indirectly from fragments requires
additional manual audit.

The historical inventory lists 18 startup/import-time initializers. Some were
already converted to check-only behavior, so the 2026-09 document must not be
treated as the current behavior of each initializer.

### Import-time initialization paths still containing DDL

| Function in `core/database.py` | Sites (line numbers on audited main) | Objects | Notes / risk |
|---|---|---|---|
| `initialize_user_economy_table` | 290, 333, 339, 343 | `user_economy` | CREATE, index add, **DROP INDEX**; critical |
| `initialize_form_tables` | 438, 459, 475, 494, 509, 530, 536, 542, 550 | `form_*` | Five CREATE + four ALTER; high |
| `initialize_active_call_logs_table` | 564 | `active_call_logs` | CREATE; medium |
| `initialize_allowed_feature_channels_table` | 650 | `allowed_feature_channels` | CREATE; medium |
| `initialize_bot_sensitive_permission_whitelist_table` | 712, 730, 740, 742 | `bot_sensitive_permission_whitelist` | CREATE, ALTER, **DROP INDEX**; critical |
| `initialize_config_levels_table` | 934, 968, 974, 990 | `config_levels` | CREATE, ALTER, **DROP COLUMN**; critical |
| `initialize_minigame_scores_table` | 998 | `minigame_scores` | CREATE; medium |
| `initialize_boss_event_tables` | 357, 371, 381, 407 | `community_boss_*` | Three CREATE + one ALTER; high |
| `initialize_expedition_tables` | 417 | `community_expedition` | CREATE; medium |
| `initialize_community_discord_columns` | 1027, 1034, 1041 | `community_discord` | Three ALTER; high |
| `initialize_user_bans_registered_at_column` | 1056 | `user_bans` | ALTER; high |
| `initialize_user_level_voice_xp_columns` | 1071, 1077, 1083, 1089, 1095, 1101 | `user_level` | Six ALTER; high |
| `initialize_user_birthday_registration_columns` | 1116, 1123, 1130 | `user_birthday` | Three ALTER; high |
| `initialize_trending_presence_column` | 1155 | `config_server_settings` | ALTER; high |

Import calls appear together near line 1292 of the audited revision.
Import-time check-only initializers include
`initialize_portaria_base_config_table`,
`initialize_user_community_status_invite_columns`,
`initialize_portaria_account_release_table`, and
`initialize_portaria_bypasses_table`: retain/verify them separately, rather
than blindly remove them on the basis of historical documentation.

### Lazy or cog-load DDL paths

| Function | Sites (audited main) | Object | Trigger / concern |
|---|---|---|---|
| `_ensure_user_inventory_schema` | `core/database.py:1395,1404` | `user_inventory.service_metadata` | Runtime ALTER with JSON→LONGTEXT fallback |
| `_ensure_voice_sessions_table` | `core/database.py:2164,2171` | `voice_xp_sessions`, `voice_sessions` | Cog-load **RENAME** + CREATE |
| `_ensure_economy_config_columns` | `core/database.py:3624` | `config_economy` | Dynamic ALTER |
| `_ensure_birthday_mentionable_column` | `core/database.py:5300` | `user_community_status` | Runtime ALTER |
| `_ensure_auto_join_roles_columns` | `core/database.py:6524` | `config_server_settings` | Dynamic ALTER |
| `_ensure_birthday_channel_column` | `core/database.py:6557` | `config_server_settings` | ALTER |
| `_ensure_hashtag_role_mentions_columns` | `core/database.py:6628` | `config_server_settings` | Dynamic ALTER |
| `_ensure_thread_owner_only_columns` | `core/database.py:6668` | `config_server_settings` | Dynamic ALTER |
| `_ensure_bump_columns` | `core/database.py:6793` | `config_server_settings` | Dynamic ALTER |
| `XpCog._ensure_voice_xp_audit_tables` | `cogs/xp.py:75,93` | `voice_xp_audit_log`, `voice_xp_daily_metrics` | Cog-load CREATE |

`BraFurries-Discord` [draft PR #23](https://github.com/BraFurries/BraFurries-Discord/pull/23)
proposes to remove the 2 voice-session DDL sites in `core/database.py` and the
2 cog-load CREATE sites in `cogs/xp.py`, replacing them with a read-only
schema preflight. **This PR is not yet merged, and runtime DDL retirement is
not complete.**

## Authority and versioned-schema evidence

- `flyway/sql/versioned/V20261004_001__formalize_xp_leveling_schema.sql`
  includes `voice_sessions`, `voice_xp_audit_log`, and
  `voice_xp_daily_metrics` with critical indexes and columns.
- The Flyway SQL in version control is **not proof it has been applied to every
  supported database**, nor proof that the production Flyway baseline has been
  adopted. See `docs/adr/0002-production-baseline-adoption.md` and
  `docs/runbooks/baseline-adoption.md`.
- No runtime/embedded DDL is to be moved to API. New schema work stays in this
  Database repository; Coddy preflights and executes operational DML only.

## Production DDL snapshot cross-check (2026-10-19)

The project owner supplied a **production MariaDB 10.6 schema-only dump**
(exported with row/data export disabled). The complete dump is **not committed**
to this public repository. This proves the definitions reported by the export
at capture time, not table contents, Flyway execution history, or runtime state
at the eventual deployment time.

- The `coddy` schema export contains 101 `CREATE TABLE` definitions.
- All 10 expected columns were found in each of `voice_sessions`,
  `voice_xp_audit_log`, and `voice_xp_daily_metrics` (30 columns total).
- The compound primary key `(server_guild_id, discord_user_id)` is present
  on `voice_sessions`.
- The unique key `(metric_day, server_guild_id, modality, voice_channel_id)`
  is present on `voice_xp_daily_metrics`.
- The read-only `information_schema` preflight proposed in Coddy PR #23
  therefore matches **this exported production schema**.
- The dump contains `schema_migrations` but no
  `flyway_schema_history`; version-control presence of
  `V20261004_001` does not establish actual Flyway deployment.
- The dump contains no `INSERT` statements; it cannot verify table row counts,
  duplicates or historical consistency. In particular, the nullable
  `voice_channel_id` in the daily-metrics unique index permits duplicate
  logical grouping keys with NULL in MariaDB; investigate separately before
  changing semantics or constraints.

**Result:** the production-structure prerequisite for Coddy PR #23 is satisfied
at capture time. No new schema migration is needed **for that four-DDL-site
removal** based on the snapshot. Keep the formal Flyway adoption, data-level
validation, and any drift remediation separate; still check deployment
readiness and obtain explicit merge/deploy approval.

## Controlled rollout: voice-XP first

1. Gather read-only `information_schema.COLUMNS` and `STATISTICS` evidence
   for the three voice tables in the intended production schema. Confirm the
   expected columns and the session and daily-metric unique keys.
2. Verify the existing migration deployment history **without inventing Flyway
   metadata**. Compare with the canonical SQL and investigate drift.
3. If anything is missing, prepare/review an expand migration in **Database**,
   validate with disposable MariaDB/Flyway, then apply it only after explicit
   rollout approval and backup/recovery preparation.
4. After schema compatibility is proven, review the Coddy PR diff + CI and
   separately authorize merge/deploy. Observe XP cog load, voice sessions,
   telemetry writes, and Discord readiness. Keep rollback available.
5. Repeat one group at a time, prioritizing **destructive operations** and
   **lazy ALTER**. Do not delete legacy `schema_migrations` automatically.

The account used by Coddy can eventually lose DDL privileges **only after**
all import-time and lazy runtime DDL paths have been retired and verified.
Grant restrictions must not be used as a substitute for completing the code
migration.

## Parallel control-plane audit

Track administrative-authority/fallback checks separately in
[BraFurries-Discord #19](https://github.com/BraFurries/BraFurries-Discord/issues/19).
A legitimate Discord-runtime write of an observed network effect is different
from the bot writing an API-owned administrative policy. Preserve guild /
Community isolation in both.
