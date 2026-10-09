# Historical Discord identity split

This document records a legacy identity correction that was already performed manually. It is **not** an executable migration or a rerunnable procedure.

## Historical behavior

Some internal `users` records were incorrectly associated with more than one `user_discord` account. Each additional Discord identity received its own internal User; when a username match was unambiguous, the original User retained the corresponding Discord account.

Illustrative example (**synthetic references, not real user IDs or Discord snowflakes**):

```text
USER_ORIGINAL -> DISCORD_ACCOUNT_PRIMARY
USER_NEW_A    -> DISCORD_ACCOUNT_SECONDARY_A
USER_NEW_B    -> DISCORD_ACCOUNT_SECONDARY_B
```

The new User derived `username` from `user_discord.username` and `display_name` from the Discord display name or username. Birthday and locale were copied as basic person attributes.

No community status, XP, records, economy, inventory, custom roles, moderation history, events, event staff, partners, API roles/permissions, tokens, password hash, or email was copied. Existing `user_discord.id` values were preserved, so `user_temp_roles.disc_user_id` required no rewrite. Direct Discord snowflakes in forms, portaria, voice sessions, and audit records were not internal User IDs and were not changed.

## Privacy and historical limits

The original record-level correspondence is deliberately excluded from documentation intended for publication; historical references in the original private repository must not be made public.

The policy above is historical evidence only. Never re-run this split automatically, recreate its Users, reassociate `user_discord`, or infer missing provenance for moderation records moved by older destructive merges.
