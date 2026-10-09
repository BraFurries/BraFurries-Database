# community_team_roles — manual additive DDL

Status: **manual additive DDL; not an official Flyway migration**. This document does not assert that the table is already present in any environment.

## Purpose and ownership

`community_team_roles` stores community-defined internal organisational roles. It is unrelated to Discord roles and is owned by `communities.id`.

- domain owner, runtime reader and runtime writer: BraFurries-API;
- future schema authority: BraFurries-Database;
- BraFurries-Discord: no reader or writer in this phase.

## Preconditions

An operator must apply this only to a MariaDB/InnoDB database that already has `communities(id INT)` and must verify that `community_discord` registrations are current. Do not run it from API or Discord startup and do not apply it against production as part of validation.

## Canonical DDL

```sql
CREATE TABLE community_team_roles (
    id INT NOT NULL AUTO_INCREMENT,
    community_id INT NOT NULL,
    parent_role_id INT NULL,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(500) NULL,
    active TINYINT(1) NOT NULL DEFAULT 1,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uk_ctr_community_id_id (community_id, id),
    KEY idx_ctr_community_active (community_id, active),
    KEY idx_ctr_parent (community_id, parent_role_id),
    CONSTRAINT fk_ctr_community FOREIGN KEY (community_id) REFERENCES communities(id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_ctr_parent_same_community FOREIGN KEY (community_id, parent_role_id)
        REFERENCES community_team_roles(community_id, id)
        ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB;
```

## Integrity boundaries

- Parent existence is guaranteed by `fk_ctr_parent_same_community`.
- A parent belonging to the same Community is guaranteed by the composite foreign key
  `(community_id, parent_role_id) -> (community_id, id)`.
- Self-parent is validated by BraFurries-API.
- Indirect cycles are validated by BraFurries-API.
- These tree rules are not represented by SQL constraints in this phase. BraFurries-API
  is the only runtime writer of this table in this phase.

## Compatibility and rollout

This is additive and compatible with N/N-1 API and Discord versions because neither existing runtime reads the table. Apply and verify the DDL first, then deploy API, then frontend. An application rollback leaves the table and data intact; do not use `DROP TABLE` as a normal rollback.

The ownership manifest is intentionally unchanged: it inventories the 78 audited, evidenced production tables and this document is a proposal pending manual application.
