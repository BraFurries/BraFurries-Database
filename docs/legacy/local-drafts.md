# Local drafts that are not remote history

## Classification

The following files were found only in the local working copy:

> `LOCAL_DRAFT / NOT_REMOTE`

They are untracked, are not present in the empty remote history, and are not included in the Phase 1 governance commit.

| local file | draft intent | official status |
|---|---|---|
| `migrations/V20260824_001__add_users_known_since.sql` | add/backfill first-known user timestamp | LOCAL_DRAFT / NOT_REMOTE |
| `migrations/V20260824_002__add_user_community_presence.sql` | add current-presence fields/index | LOCAL_DRAFT / NOT_REMOTE |
| `migrations/V20260824_003__create_user_membership_events.sql` | create append-only membership history | LOCAL_DRAFT / NOT_REMOTE |
| `migrations/V20260824_004__add_user_ban_lifecycle.sql` | add ban revocation lifecycle metadata | LOCAL_DRAFT / NOT_REMOTE |

## Governance

- They are not evidence of applied production history.
- They are not part of a baseline.
- Their version numbers are not reserved as official Flyway versions.
- They must not be copied into the future official migration directory without redesign and review.
- Their intended features may be reconsidered after baseline adoption.
- Any future implementation must start from the then-current schema and approved ownership/compatibility policy.

## Phase 1 handling

Phase 1 preserves these local files unchanged and outside Git history. This document records their existence without copying their SQL content.
