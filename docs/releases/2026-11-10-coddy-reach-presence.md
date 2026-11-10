# Coddy reach and Discord bot guild presence

## Scope

The additive migration `V20261110_002__track_discord_bot_guild_presence.sql` adds two nullable UTC DATETIME(6) columns to `community_discord`:

- `last_bot_joined_at`: most recent provider-confirmed installation date or observation of a new active transition;
- `last_bot_left_at`: most recent observed exit (Discord event or complete reconciliation snapshot).

Only the API is authorized to mutate these fields. The Coddy runtime reports guild presence through the existing authenticated internal lifecycle API; the Front reads aggregate metrics from the admin overview. The data stays scoped to each `community_discord.community_id` (Community is the tenant).

## Historical safety

No backfill is performed. Existing NULL timestamps mean that an exact historical date is unknown, **not** that the event never happened. If Discord supplies the bot member's actual joined_at timestamp on subsequent observations, the API may fill the missing last join date without treating it as a new installation. Existing active flags and guild user counts are untouched.

For weekly counters, the dashboard counts *distinct guilds whose most recent join or exit occurred within seven days*, not all historical events and not the net change. Repeated joins/exits within a week are intentionally not an event ledger.

## Rollout

1. Apply the Database migration first, with the standard preflight/backup and Flyway checks.
2. Deploy API (reads new columns and accepts optional `botJoinedAt` from Coddy).
3. Deploy Coddy (sends Discord's joined_at when available).
4. Deploy Front (renders the new weekly exit counter and reordered overview cards).

A rollback of application code leaves additive fields safely in place. No production DML, backfill, or down migration is required. Verify guild join, guild removal, restart snapshot, repeated observations, partner-pending counts, and admin overview metrics after rollout.
