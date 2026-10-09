# user_ban_discord_effects — propagated Discord ban effects

Status: **official additive versioned migration, pending production application**.

## Purpose and ownership

One `user_bans` row remains the administrative action and its original target. `user_ban_discord_effects` records each concrete Discord account outcome attempted by Coddy for that action. It therefore preserves the distinction between the moderation decision and its propagated Discord effects.

The API remains the only authority for transitive `CONFIRMED` identity clusters. Coddy writes this table after consuming that API result; the table is not an identity graph and `SUSPECTED` identities must never be written as propagation candidates.

## Tenant and identifier boundaries

- tenancy comes from the parent `user_bans.community_id`;
- `identity_user_id` is `users.id` and identifies the API-returned User owning the Discord account;
- `discord_user_id` is a Discord snowflake, not `user_discord.id`;
- the unique `(ban_id, discord_user_id)` key makes retries idempotent;
- only `APPLIED` effects may be automatically reversed; `ALREADY_BANNED` accounts predate the action and must remain banned.

All Discord lookup and mutation remains restricted to the guild mapped to the parent ban's Community.

## Outcomes and partial failure

The initial outcome records `APPLIED`, `ALREADY_BANNED`, `NOT_FOUND`, `FORBIDDEN`, or `FAILED`. A Community ban targets the confirmed identity, so every known Discord account in the active `CONFIRMED` cluster is enforced by snowflake even when the account is not currently a guild member. Reversal records its own outcome and timestamp. A failure for one Discord account does not erase successful sibling effects, and retry logic must preserve a prior `APPLIED` result.

When a later identity link becomes `CONFIRMED`, active ban actions for the resulting cluster are extended to Discord accounts that do not yet have a ledger row for that action. `SUSPECTED` links never trigger this behavior.

## Compatibility and rollout

The migration is additive. Existing API and frontend versions ignore the table. Existing Coddy versions continue to use `user_bans` only.

Rollout order:

1. merge/apply BraFurries-Database #19 first, so Flyway has already applied `V20260930_003__make_user_identity_links_undirected.sql`;
2. apply this Database migration;
3. ensure the internal identity endpoint serving transitive `CONFIRMED` clusters is deployed;
4. deploy the Coddy propagation consumer.

Do not apply this `V20261001_001` migration ahead of the still-pending older `V20260930_003` migration.

Application rollback leaves effect history intact. Do not drop the table or duplicate `user_bans` rows as rollback mechanisms.
