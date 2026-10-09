# community_team_role_assignments — Community Team member assignments

Status: **official additive versioned migration, pending production application**.

## Purpose and ownership

`community_team_role_assignments` represents the current organisational assignment of an internal BraFurries user to an internal Community Team role.

- schema authority: BraFurries-Database;
- domain owner, reader and writer: BraFurries-API;
- BraFurries-Front-End consumes the API contract only;
- BraFurries-Discord has no reader/writer responsibility for this table;
- Discord and Telegram identifiers are not assignment keys.

The user identity is `users.id`. A person may occupy more than one role in the same Community.

## Verified prerequisites

The existing `community_team_roles` production shape was introduced from the approved manual DDL documented in Database PR #4 and is consumed by the API with Hibernate schema management disabled. Its tenant-aware key is:

```text
UNIQUE (community_id, id)
```

The current-membership prerequisite is formalized by Database issue #15 / PR #16:

```text
UNIQUE (community_id, user_id)
```

This migration is intentionally stacked after PR #16 and must not be applied before that unique key exists.

## Canonical DDL

The authoritative migration is:

`flyway/sql/versioned/V20260930_002__create_community_team_role_assignments.sql`

The effective table shape is:

```sql
CREATE TABLE community_team_role_assignments (
    community_id INT(11) NOT NULL,
    role_id INT(11) NOT NULL,
    user_id INT(11) NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (community_id, role_id, user_id),
    KEY idx_ctra_community_user (community_id, user_id),
    CONSTRAINT fk_ctra_role_same_community
        FOREIGN KEY (community_id, role_id)
        REFERENCES community_team_roles(community_id, id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_ctra_member_same_community
        FOREIGN KEY (community_id, user_id)
        REFERENCES user_community_status(community_id, user_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
```

## Integrity boundaries

The database guarantees:

- one row per Community ↔ Role ↔ User assignment;
- a referenced role belongs to the same `community_id` as the assignment;
- the referenced internal user has a membership-state row in the same Community;
- a role with assignments cannot be deleted implicitly;
- a membership row with assignments cannot be deleted implicitly.

BraFurries-API must still:

- resolve the authorized guild to a Community before every operation;
- validate the member in that same Community;
- reject new assignments to inactive roles;
- handle banned/absent members explicitly without deleting organisational history;
- include assignments in role deletion impact and remove assignments explicitly before role deletion.

Team-role hierarchy is organisational metadata and must not grant API authorization.

## Compatibility and rollout

This change is additive. Existing API, Front and Discord versions ignore the new table.

Rollout order:

1. deploy the hardened Coddy writer from BraFurries-Discord#563;
2. revalidate zero duplicate `user_community_status` pairs;
3. apply Database PR #16 and verify `UNIQUE (community_id, user_id)`;
4. apply this assignment migration and verify its composite FKs/indexes;
5. deploy the API assignment contract from BraFurries-API#123;
6. deploy the Front assignment UI from BraFurries-Front-End#79.

Application rollback leaves the assignment table and rows intact. Do not use `DROP TABLE` as a routine rollback.

`CREATE TABLE IF NOT EXISTS` exists only to support eventual Flyway adoption in environments where this exact additive DDL may have been applied manually. The disposable validation must still prove the expected columns, keys and foreign-key rules; a structurally different pre-existing table is not considered compatible.

Production baseline adoption remains a separate operation.
