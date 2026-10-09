# Community authorization foundation

Status: **schema foundation only; not yet applied to production**.

## Purpose

Community is the organizational tenant. A Community may exist before any Discord, Telegram, or future network integration.

The authorization foundation introduced by `V20261001_002__create_community_authorization_foundation.sql` separates:

- Community ownership;
- role-derived organizational capabilities;
- direct Community-wide capability grants;
- administrative audit evidence.

Discord guild ownership and `Manage Guild` remain separate runtime concepts.

## Ownership

`communities.owner_user_id` is nullable.

This is intentional:

- a Community created directly by the future API can set the authenticated User as Owner;
- an integration such as Coddy may create a Community before an internal Owner is claimed;
- the migration does not infer or backfill Owner from `community_discord.discord_admin_id`.

Ownership claim/creation rules belong to the API and are not encoded as migration DML.

## Capabilities

Capabilities are stored as VARCHAR codes rather than a MariaDB ENUM or database catalogue.

The API will define valid capability codes and composition rules.

The initial application design includes concepts such as:

- `COMMUNITY_ADMIN`;
- `TEAM_VIEW`;
- `TEAM_ASSIGN_MEMBERS`;
- `TEAM_MANAGE_STRUCTURE`;
- `TEAM_MANAGE_DEMANDS`;
- `MEMBERS_VIEW`;
- `MEMBER_DETAILS_VIEW`;
- `MEMBER_NOTES_VIEW`;
- `MEMBER_NOTES_MANAGE`.

`COMMUNITY_ADMIN` is intended to be a direct grant controlled by Community ownership rules. Hierarchical TEAM authorization and strict-descendant scope are API responsibilities.

## Tenant isolation

`community_team_role_capabilities` uses the composite role key `(community_id, role_id)`.

`community_user_capability_grants` uses the composite membership key `(community_id, user_id)`.

These constraints prevent a role or member from another Community being attached to the current tenant by identifier alone.

## Audit

`community_audit_log` records actor, Community, action, optional target reference, optional metadata, and timestamp.

Application code must avoid copying note contents or arbitrary sensitive personal data into audit metadata.

## Rollout boundary

This migration is additive. Existing Communities remain valid with `owner_user_id = NULL`.

Before production application, operators must verify referenced production key shapes and the already-applied membership uniqueness prerequisite. Applying this migration does not itself enable Community authorization in API or Front-End.
