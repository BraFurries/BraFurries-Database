# Community lifecycle and network synchronization

Status: **official additive versioned migration, pending production application**.

## Scope and ownership

`V20261002_001__add_community_lifecycle_and_network_sync.sql` establishes schema only. It adds no API or Coddy runtime DDL and does not enable a new runtime flow by itself.

- `portaria_base_config` remains Discord-owned configuration, with API and Coddy existing readers/writers preserved;
- `user_community_status` remains shared current Community membership state;
- `community_network_sync_runs` is an API-owned control-plane lifecycle record. Coddy may request/advance runs only through authenticated API contracts and must not write the table directly;
- BraFurries-Database remains schema authority.

## Additive semantics

`portaria_base_config.portaria_enabled` is an explicit Portaria lifecycle flag. It is independent from `formulario_portaria_ativo`: the latter continues to express only form behavior. New/incidental base rows default to disabled. During this migration only guilds that already have at least one `form_flows` row with `type='portaria'` are backfilled to enabled, matching the pre-existing API definition of a configured Portaria without deriving lifecycle state from the form toggle.

`user_community_status.approval_required` is nullable by design. `NULL` means that Portaria applicability was not established for that membership; this migration does not infer it from approval, form, invite, or historical fields. `display_name` is nullable and stores the canonical display name for that specific User/Community membership. Neither column changes `member_since` or historical membership data.

`community_network_sync_runs` records one Community-scoped synchronization attempt with an external provider discriminator (`network_type`) and provider identifier (`external_network_id`). The external identifier intentionally has no universal foreign key because its meaning is selected by `network_type`. The migration constrains the approved trigger and lifecycle values:

- triggers: `GUILD_JOIN`, `STARTUP`, `PERIODIC`, `MANUAL`, `OWNERSHIP_CHANGE`;
- statuses: `QUEUED`, `RUNNING`, `SUCCESS`, `FAILED`.

Indexes support Community/network lookup, Community/status/start-time lifecycle queries, and efficient runtime polling by `(network_type, status, id)`. The `community_id` foreign key prevents a run from crossing or referencing a missing Community.

## Compatibility and rollout

This is an expand-only migration. Older API and Coddy versions ignore the new columns and table; newer versions must treat `approval_required = NULL` as unknown rather than approved or required. Application deployment must follow schema application and remain compatible with the nullable state.

No backfill, data rewrite, `member_since` change, or inferred approval state occurs. Recovery for an application rollback is to leave the additive objects and data intact; do not drop columns or the run history as routine rollback.

The disposable MariaDB smoke validates legacy values, nullable migration behavior, the new table's indexes, foreign key, allowed trigger/status values, and cleanup. Production application still requires the normal Flyway baseline/adoption process and operator approval.
