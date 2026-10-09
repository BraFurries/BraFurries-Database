# community_team_demands — manual additive DDL

Status: **manual additive DDL; not an official Flyway migration**. The operator applied this DDL in production on 2026-09-17. The operator-provided `SHOW CREATE TABLE` output and foreign-key rules correspond to the canonical schema below. This is evidence of that manual application only; it does not create Flyway history.

## Purpose and ownership

`community_team_demands` stores persistent team responsibilities, not tasks, tickets, checklists, or member assignments. A demand belongs to one Community and may be linked to zero or more `community_team_roles` through `community_team_demand_roles`.

- domain owner, runtime reader and runtime writer: BraFurries-API;
- future schema authority: BraFurries-Database;
- BraFurries-Discord: no reader or writer in this phase.

## Preconditions

An operator must apply this only to a MariaDB/InnoDB database that already has `communities(id INT)` and the compatible `community_team_roles` table documented in [community_team_roles.md](community_team_roles.md). Do not run this from API or Discord startup and do not apply it against production as part of validation.

## Canonical DDL

```sql
CREATE TABLE community_team_demands (
    id INT NOT NULL AUTO_INCREMENT,
    community_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(500) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uk_ctd_community_id_id (community_id, id),
    KEY idx_ctd_community_name (community_id, name),
    CONSTRAINT fk_ctd_community FOREIGN KEY (community_id) REFERENCES communities(id)
        ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE community_team_demand_roles (
    community_id INT NOT NULL,
    demand_id INT NOT NULL,
    role_id INT NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (community_id, demand_id, role_id),
    KEY idx_ctdr_community_role (community_id, role_id),
    CONSTRAINT fk_ctdr_demand_same_community FOREIGN KEY (community_id, demand_id)
        REFERENCES community_team_demands(community_id, id)
        ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT fk_ctdr_role_same_community FOREIGN KEY (community_id, role_id)
        REFERENCES community_team_roles(community_id, id)
        ON UPDATE RESTRICT ON DELETE CASCADE
) ENGINE=InnoDB;
```

## Integrity boundaries

- A demand belongs to an existing Community through `fk_ctd_community`.
- The association primary key prevents duplicate Demand ↔ Role links.
- Both association foreign keys are tenant-aware: a demand and a role can only be linked when they belong to the same Community.
- Deleting a Role or Demand removes only rows from `community_team_demand_roles`; it never deletes the opposite entity.
- There is intentionally no member-assignment table or member-count constraint in this phase.

## Compatibility and rollout

This is additive and compatible with N/N-1 API and Discord versions because neither existing runtime read these tables before this feature. The production schema was already applied manually on 2026-09-17; deployment order is API, then frontend. Do not reapply the DDL during rollout. An application rollback leaves the tables and data intact; do not use `DROP TABLE` as a normal rollback.

`community_team_roles` may be deleted only by the API after it verifies role-tree blockers. Demand links do not block deletion: they are removed by the association-table foreign key. Future member assignments may add another API-level blocker without changing this N:N ownership rule.
