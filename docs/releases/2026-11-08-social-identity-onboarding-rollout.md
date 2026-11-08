# Release evidence — 2026-11-08 — Self-service OAuth identities and local e-mail

## Scope and authority

The operator authorized the rollout after executing the five reviewed versioned SQL files in production. BraFurries-Database remains the sole schema authority. Production has **not** adopted an official Flyway baseline: these scripts were applied manually under the documented transitional process, without synthetic inserts into flyway_schema_history. Do not replay the scripts automatically on the existing production schema.

Reviewed SQL:
1. V20261105_001__discord_self_service_link_challenges.sql (Database #47).
2. V20261105_002__create_self_service_social_account_reconciliation.sql (Database #48).
3. V20261107_001__social_onboarding_independent_account_email.sql (Database #50).
4. V20261107_002__local_email_proof_and_social_login_audit.sql (Database #50).
5. V20261107_003__social_login_fresh_oauth_proofs.sql (Database #50).

## Operator-provided production postflight

On November 8 the operator supplied screenshots of the read-only postflight results. The screenshots show **all six expected new tables**:

- user_account_consolidations
- user_discord_link_challenges
- user_social_identities
- user_social_login_events
- user_social_login_proofs
- user_social_onboarding_challenges

They also show the **four expected columns**, types, nullability and defaults:

| Table | Column | Type | Nullable | Default |
| --- | --- | --- | --- | --- |
| users | auth_version | bigint(20) | NO | 0 |
| users | email_verified_at | datetime(6) | YES | NULL |
| users | merged_into_user_id | int(11) | YES | NULL |
| user_social_identities | login_enabled | tinyint(1) | NO | 1 |

The aggregate counts were six tables and four columns. This is **operator-supplied evidence**, not a direct database connection or an independently audited schema dump. FK, index, CHECK constraint, row count, backup and restoration evidence were not separately inspected in this release record; do not infer them from table existence alone. There was no automatic backfill of local e-mail proof.

## GitHub integration evidence

- Database #47 merged as 7b336bfaf7d0bd65276ae9cef4570ce080846cbb.
- Database #48 and #50 integrated in main as ceef66eef767e4d69675398859dc635229321f1c. Disposable MariaDB/Flyway suite: https://github.com/BraFurries/BraFurries-Database/actions/runs/42485653597 (success).
- API #73 (including intermediate #69) squash commit bab54ba7bccd2ba9c75bf0946af4f99d8d641aa4. Production workflow: https://github.com/BraFurries/BraFurries-API/actions/runs/42486254885 (success, including readiness, public API and CORS).
- Front #56 (including intermediate #54) squash commit c074ebc5588b5f099f7db6171c267b3141b6931c. Firebase Hosting deploy: https://github.com/BraFurries/BraFurries-Front-End/actions/runs/42486689442 (success).
- API and Front deployed commit trees were compared with the corresponding reviewed PR head trees: identical. Intermediate #69 and #54 were closed as incorporated; branches were not deleted.

## Residual follow-up

Track under https://github.com/BraFurries/BraFurries-API/issues/72. The automated CI and health checks **do not replace** manual end-to-end Google OAuth, Discord OAuth, SMTP e-mail verification, account disable/reactivation, and historical Community-account recovery trials. Identity merging with conflicting operational/Community data remains outside the narrow sparse V1. Legacy inventory and abandoned-unverified-email handling still need operational evidence and policy decisions.

Do not mark the broader identity-reconciliation feature fully complete from this deployment alone.
