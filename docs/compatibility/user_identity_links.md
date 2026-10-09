# User identity links

Status: **existing table structurally adopted by Flyway; undirected-edge rename pending coordinated rollout**.

`user_identity_links` records traceability between distinct `users.id` values. It never moves a Discord account, moderation record, credential, role, token, asset, or ownership record. BraFurries-API is the only writer; API and Discord may read the table for staff-only moderation context.

## Canonical structure

[`V20260924_001__create_user_identity_links.sql`](../../flyway/sql/versioned/V20260924_001__create_user_identity_links.sql) is the immutable structural-adoption migration and uses the signed `INT(11)` type of `users.id`, InnoDB, and the production `utf8mb4_general_ci` convention evidenced by the structural audit. `CREATE TABLE IF NOT EXISTS` is deliberate because production received this table manually before Flyway adoption. Release preflight must compare `SHOW CREATE TABLE user_identity_links` with the expected pre-migration structure; `IF NOT EXISTS` is not permission to accept drift.

[`V20260930_003__make_user_identity_links_undirected.sql`](../../flyway/sql/versioned/V20260930_003__make_user_identity_links_undirected.sql) removes the retired hierarchy physically. `user_a_id` and `user_b_id` are equivalent endpoints of one undirected edge; neither endpoint is primary, secondary, linked-to, or a root. For active rows, the stored generated columns are:

```text
active_user_low_id  = LEAST(user_a_id, user_b_id)
active_user_high_id = GREATEST(user_a_id, user_b_id)
```

Both generated values are `NULL` after revocation. The unique key on `(active_user_low_id, active_user_high_id)` therefore prevents A-B and B-A from coexisting as separate active edges while allowing complete revoked history. Endpoint foreign keys retain both Users, and the distinct-users check continues to reject self-links. Status/source checks and all audit fields remain unchanged.

## Semantics

- `CONFIRMED` edges participate transitively in an identity cluster. A--B and B--C place A, B, and C in the same confirmed cluster for staff-only aggregated moderation reads while preserving every record's source User and Discord identifiers.
- `SUSPECTED` is context only, does not connect confirmed clusters, and never aggregates history or grants access.
- revocation is soft: `revoked_at`, `revoked_by_user_id`, and `revocation_reason` are populated and the original link remains auditable.
- identity links never share authentication, authorization, Discord privileges, sessions, API roles, or permissions.
- `user_discord` normally has one row per User going forward; legacy multiple rows remain tolerated as aliases of the same User.

## Compatibility and rollout

The physical column rename is intentionally a contract change and provides no aliases for the retired names. It is not compatible with API or Discord versions that still query `primary_user_id` or `linked_user_id`. Before applying the migration, release coordination must stop incompatible writers/readers or deploy versions prepared for the new columns in a way that does not query the table until the migration completes. The required order is: approve Database, API, and Discord changes; verify no active unordered pair is duplicated; quiesce incompatible identity-link access; apply the Database migration; deploy/enable compatible API and Discord versions; then verify cluster reads. The Front-End contract is unaffected because it does not address these physical columns directly.

The migration renames columns in place and does not rewrite endpoint values, topology, status, source, timestamps, actors, reasons, revocation state, or row IDs. Application rollback after the migration requires a forward-compatible application fix; the old column names are not restored.

## Validation and recovery

Validate the migration only against the disposable MariaDB 10.6 harness. Production preflight must compare the current structure with the expected pre-migration schema and must reject active reverse/duplicate pairs before DDL begins. A failed structure or data preflight stops the release for investigation; do not use `DROP TABLE`, Flyway `repair`, or an automated data rewrite as recovery.
