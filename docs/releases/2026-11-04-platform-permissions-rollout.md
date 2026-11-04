# Rollout — BraFurries Platform Access

## Scope and authority

This migration moves only **administrative access control** from the commercial
namespace to the BraFurries platform domain. **No** commerce sales, ledger,
products, inventory, contract or royalty records are touched.

- Schema authority: BraFurries-Database
- Business authorization, audit and config authority: BraFurries-API
- Sidebar and permission editor: BraFurries-Front-End
- Runtime Coddy: no change
- Community is a tenant; effective platform grants only intersect owner-approved
  people with **active, official BraFurries Team roles** and eligible presence.
  Other Communities/Discord roles cannot provide access.

## Preflight — production READ ONLY

1. Capture a verifiable database backup, preserve recovery copy and existing
   production API version/environment configuration.
2. Inspect current structures and migration history:

```sql
SELECT DATABASE(), VERSION();
SELECT table_name FROM information_schema.tables
 WHERE table_schema=DATABASE()
 AND table_name IN (
  'commerce_authorized_users','commerce_user_permissions',
  'commerce_role_permissions','commerce_access_audit',
  'platform_authorized_users','platform_user_permissions',
  'platform_role_permissions','platform_access_audit','platform_permission_catalog');
SHOW CREATE TABLE commerce_user_permissions;
SHOW CREATE TABLE commerce_role_permissions;
SELECT 'people' AS entry, COUNT(*) AS total FROM commerce_authorized_users
 UNION ALL SELECT 'personal_grants',COUNT(*) FROM commerce_user_permissions
 UNION ALL SELECT 'role_grants',COUNT(*) FROM commerce_role_permissions
 UNION ALL SELECT 'audit',COUNT(*) FROM commerce_access_audit;
```

3. Confirm the source tables exist and target `platform_*` tables do not.
   Keep count results. Never assume there are zero grants/audits.
4. Determine whether `V20261104_002` (adding PARTNERS_MANAGE to old CHECKs)
   was already manually applied. Do **not** rerun a partially applied migration.
   If Flyway history exists, reconcile version/checksums before deployment.
   **Never** run Flyway baseline automatically on a populated production schema.

## Migration order

1. `V20261104_002__permit_partner_area_access.sql` — **only if not applied**.
2. `V20261104_003__migrate_commerce_access_to_platform.sql`.

This is MariaDB DDL with implicit commits; do not treat it as a single
rollbackable transaction. Migration 003 seeds the permission catalog and then
renames the four existing ACL tables **in place**, preserving rows, audit and
foreign keys; it replaces the per-table permission CHECKs with catalog FKs.
No ad-hoc DDL in API/Coddy.

## Postflight READ ONLY

```sql
SELECT table_name FROM information_schema.tables
 WHERE table_schema=DATABASE()
 AND (table_name LIKE 'platform_%' OR
      table_name IN ('commerce_authorized_users','commerce_user_permissions',
                     'commerce_role_permissions','commerce_access_audit'))
 ORDER BY table_name;
SELECT area,COUNT(*) AS codes FROM platform_permission_catalog
 WHERE active=1 GROUP BY area ORDER BY area;
SELECT 'people' AS entry, COUNT(*) AS total FROM platform_authorized_users
 UNION ALL SELECT 'personal_grants',COUNT(*) FROM platform_user_permissions
 UNION ALL SELECT 'role_grants',COUNT(*) FROM platform_role_permissions
 UNION ALL SELECT 'audit',COUNT(*) FROM platform_access_audit;
SELECT table_name, referenced_table_name, column_name
 FROM information_schema.key_column_usage
 WHERE table_schema=DATABASE() AND
   table_name IN ('platform_user_permissions','platform_role_permissions','platform_access_audit')
   AND referenced_table_name='platform_permission_catalog';
SELECT COUNT(*) AS unrecognized_person_codes FROM platform_user_permissions p
 LEFT JOIN platform_permission_catalog c ON c.code=p.permission_code
 WHERE c.code IS NULL;
SELECT COUNT(*) AS unrecognized_role_codes FROM platform_role_permissions p
 LEFT JOIN platform_permission_catalog c ON c.code=p.permission_code
 WHERE c.code IS NULL;
```

Expected: only platform tables as ACL authority; **10 catalog codes**
(9 COMMERCE, 1 PARTNERS); row counts of all four migrated tables **equal to
preflight**, no orphan grants, FK links to catalog.

## Application and frontend

- API deploy only after DB postflight. New `/user/me/platform-access` API,
  with temporary legacy alias `/user/me/brafurries-commerce/access`.
- Owner/user/community config accepts `PLATFORM_*` with existing
  `COMMERCE_OWNER_USER_ID` and `COMMERCE_OFFICIAL_COMMUNITY_ID` fallback,
  so no secret migration is required for this rollout.
- Confirm API readiness, user/role intersection, owner grants and
  `PARTNERS_MANAGE` isolated from finance.
- Only then deploy Front. It fetches catalog metadata from API.
- Test owner, unapproved individual, partner-only role, finance-only role,
  inactive Team role, member from another Community and revoked member.

**No automatic merge, production DDL, or deploy** is authorized by this
document. A schema mismatch blocks the API/Front rollout.
