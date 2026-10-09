# Manual production DDL evidence

## 2026-09-29 — Bump monthly reward ledger

Production application was performed manually by the operator using the canonical DDL from:

`flyway/sql/versioned/V20260929_002__create_bump_monthly_reward_ledger.sql`

Observed after application:

- `bump_monthly_reward_runs` exists;
- `bump_monthly_reward_grants` exists;
- both tables were empty immediately after creation;
- the expected PRIMARY, UNIQUE, CHECK, and FOREIGN KEY constraints were observed for both tables.

This record documents production state only. It does **not** claim that Flyway executed the migration or that `flyway_schema_history` was adopted. Production Flyway adoption remains deferred.

The versioned migration remains the canonical schema definition for these tables.
