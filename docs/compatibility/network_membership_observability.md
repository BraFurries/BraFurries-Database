# Network-scoped Community membership observability

Status: **expand-only schema proposed for event-driven membership synchronization**.

## Authority

BraFurries-Database remains schema authority. BraFurries-API owns canonical network-membership state, transition history, Community aggregates and synchronization health. Coddy observes live network state and calls authenticated API contracts; it does not write these tables directly.

## State model

`community_network_member_status` stores the current state of one User on one external network:

- tenant: `community_id`;
- network identity: `network_type + external_network_id`;
- User: `user_id`;
- current presence and the start/end of the current presence interval;
- earliest known join evidence and its provenance;
- most recent join/return and its provenance;
- last authoritative observation;
- network-scoped Portaria applicability/approval;
- network-local display name.

The logical key is `(network_type, external_network_id, user_id)`.

`user_community_status` is retained. It remains the Community-level relationship and legacy aggregate; it is not replaced by the network row. API aggregation may use network evidence to improve `member_since`, `last_join_date`, `is_present` and `left_at` without erasing older trustworthy Community history.

## Transition history

`community_network_member_events` is append-only history for meaningful state transitions such as JOIN, LEAVE, APPROVED and APPROVAL_REVOKED. A successful observation that leaves state unchanged does **not** create an event.

This makes storage growth proportional to member churn rather than:

`total members × reconciliation frequency`.

The first bootstrap snapshot establishes current state but must not fabricate historical JOIN events merely because the bot observed an already-present member. Network-reported join timestamps may seed `first_known_join_at` and `last_join_at` with their source recorded.

## Synchronization health

`community_discord.membership_sync_state` is explicit:

- `RECONCILIATION_REQUIRED`: a trustworthy full baseline is required;
- `RECONCILING`: a complete reconciliation is in progress;
- `HEALTHY`: incremental events are the primary update mechanism;
- `DEGRADED`: event continuity or reconciliation failed and recovery is required.

`last_full_reconciliation_at` records the last successful complete reconciliation. `last_membership_event_at` records the last successfully applied incremental membership event.

All existing Discord integrations default to `RECONCILIATION_REQUIRED`. This is intentional: the migration does not infer network membership from Community-level legacy rows.

## Operating model

After a trustworthy full reconciliation, Coddy should maintain membership from network events. Complete member scans are reserved for:

1. bootstrap;
2. guild/network join;
3. recovery after event continuity cannot be proven;
4. manual synchronization;
5. detected drift between the provider member count and tracked network presence.

Periodic full scans are not the primary synchronization mechanism.

## Compatibility and rollout

This migration does not backfill `community_network_member_status` or synthesize events from `user_community_status`. Older application versions ignore the new objects. New API/Coddy versions must be deployed only after this schema is applied.

Rollback of application code leaves the additive tables/columns intact. Do not delete the new history or current-state rows as routine rollback.
