# Legacy Discord runtime DDL

## Status

This document records current legacy behavior discovered during the 2026-09 schema audit. It does not authorize any change to Discord.

Effective with this governance:

> No new runtime DDL may be introduced in BraFurries-Discord.

Existing DDL remains temporarily operational until each path is covered, validated, converted to check-only behavior, observed, and retired.

## Retirement state machine

```text
UNMAPPED_DDL
→ EXPECTED_SCHEMA_DOCUMENTED
→ COVERED_BY_BASELINE_OR_MIGRATION
→ CHECK_ONLY
→ OBSERVED
→ RETIRED
```

No path may skip directly from schema mutation to removal unless the expected schema has been independently proven in every supported environment.

## Risk levels

| risk | meaning |
|---|---|
| CRITICAL | destructive DDL, rename, key removal, or behavior capable of irreversible/ambiguous state change |
| HIGH | runtime ALTER, lazy mutation, constraint/index repair, backfill, or metadata-lock exposure |
| MEDIUM | idempotent CREATE/ADD during startup or component load |
| LOW | read-only compatibility check with no mutation |

There are no LOW-risk runtime mutations. LOW is the target for temporary check-only replacements.

## Import-time initializers

`core/database.py` invokes 18 initializers at module import. Importing the module can therefore open a database connection and mutate schema before application startup has completed.

| initializer | affected tables | observed operation class | risk |
|---|---|---|---|
| `initialize_user_economy_table` | `user_economy` | CREATE, ALTER, index repair/removal | CRITICAL |
| `initialize_form_tables` | `form_flows`, `form_questions`, `form_submissions`, `form_decisions`, `form_published_messages` | CREATE and ALTER | HIGH |
| `initialize_active_call_logs_table` | `active_call_logs` | CREATE | MEDIUM |
| `initialize_portaria_base_config_table` | `portaria_base_config` | CREATE, ALTER, RENAME-like column transition, backfill, DROP COLUMN | CRITICAL |
| `initialize_user_community_status_invite_columns` | `user_community_status` | ALTER | HIGH |
| `initialize_portaria_account_release_table` | `portaria_account_release` | CREATE and ALTER | HIGH |
| `initialize_allowed_feature_channels_table` | `allowed_feature_channels` | CREATE | MEDIUM |
| `initialize_bot_sensitive_permission_whitelist_table` | `bot_sensitive_permission_whitelist` | CREATE, ALTER, DROP INDEX, index replacement | CRITICAL |
| `initialize_discord_backup_tables` | `backup_discord`, `backup_channels`, `backup_roles`, `backup_overwrites`, `backup_server_settings` | CREATE, ALTER, index/backfill repair | HIGH |
| `initialize_config_levels_table` | `config_levels` | CREATE, ALTER, DROP COLUMN | CRITICAL |
| `initialize_minigame_scores_table` | `minigame_scores` | CREATE | MEDIUM |
| `initialize_boss_event_tables` | `community_boss_event`, `community_boss_contribution`, `community_boss_attack_cooldown` | CREATE and ALTER | HIGH |
| `initialize_expedition_tables` | `community_expedition` | CREATE | MEDIUM |
| `initialize_community_discord_columns` | `community_discord` | ALTER | HIGH |
| `initialize_user_bans_registered_at_column` | `user_bans` | ALTER | HIGH |
| `initialize_user_level_voice_xp_columns` | `user_level` | ALTER | HIGH |
| `initialize_user_birthday_registration_columns` | `user_birthday` | ALTER | HIGH |
| `initialize_trending_presence_column` | `config_server_settings` | ALTER | HIGH |

## Lazy DDL outside `initialize_*`

These paths may execute during normal feature use rather than a controlled startup phase.

| path | table | trigger context | operation | risk |
|---|---|---|---|---|
| `_ensure_user_inventory_schema` | `user_inventory` | inventory reads/writes/purchases | add `service_metadata`, with type fallback | HIGH |
| `_ensure_ai_settings_columns` | `config_server_settings` | server settings and AI operations | add settings columns | HIGH |
| `_ensure_economy_config_columns` | `config_economy` | economy getters/setters | add bump/birthday columns | HIGH |
| `_ensure_birthday_mentionable_column` | `user_community_status` | birthday operations | add state column | HIGH |
| server-setting ensure helpers | `config_server_settings` | staff, auto-join, birthday, moderation, hashtag, thread, VIP, bump operations | add multiple columns | HIGH |
| `_ensure_user_custom_roles_columns` | `user_custom_roles` | custom-role reads/writes | add `color2` and `role_id` | HIGH |
| `_ensure_voice_sessions_table` | `voice_sessions` | XP cog construction | RENAME legacy table or CREATE | CRITICAL |

Lazy DDL is high priority for retirement because it can acquire metadata locks during user-facing operations.

## XpCog DDL

`cogs/xp.py` performs DDL while the cog is constructed:

| table | operation | risk |
|---|---|---|
| `voice_sessions` | ensure/rename/create | CRITICAL |
| `voice_xp_audit_log` | CREATE | MEDIUM |
| `voice_xp_daily_metrics` | CREATE | MEDIUM |

## Destructive or especially dangerous behavior

Observed categories include:

- dynamic `DROP INDEX` on `user_economy`;
- index removal/replacement on the sensitive-permission whitelist;
- `DROP COLUMN` in portaria schema repair;
- `DROP COLUMN` in `config_levels` repair;
- `RENAME TABLE voice_xp_sessions TO voice_sessions`;
- backfills mixed with startup repair.

These paths must eventually fail closed or report incompatibility. They must not continue as automatic repair after central migration authority is active.

## Retirement priority

1. destructive DROP/RENAME/index-replacement paths;
2. lazy DDL during business operations;
3. XpCog load-time DDL;
4. import-time ALTER/repair paths;
5. import-time idempotent CREATE paths;
6. temporary read-only checks.

## Known contradictions to resolve later

- `user_economy` runtime definition differs from the production type/FK shape.
- backup table nullability/types and cascade expectations differ from production.
- form-flow index expectations differ.
- `config_levels` nullability and removed-column behavior differ.
- runtime schema mutation conflicts with the target of a DML-only Discord credential.

No correction is included in Phase 1.
