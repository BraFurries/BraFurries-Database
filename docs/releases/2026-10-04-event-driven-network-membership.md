# Release record: Event-driven network membership (2026-10-04)

## Status and authority

`V20261002_002__add_network_member_state_and_events.sql` was applied in production through the approved transitional process before Flyway baseline adoption. The migration under `flyway/sql/versioned/` is authoritative; this record does not imply that `flyway_schema_history` exists.

The migration:

- adds membership synchronization health fields;
- extends synchronization triggers with `DRIFT` and `RECOVERY`;
- creates `community_network_member_status` and `community_network_member_events`;
- adds `last_sync_run_id` linkage for snapshot reconciliation.

## Runtime rollout

The API provides the control plane for incremental network membership events, full snapshot batch/finalize, Community membership aggregation, reconciliation health and recovery. Authorization and data access are scoped by Community, network type and external network ID.

The Coddy runtime publishes incremental member events, performs full reconciliation for bootstrap, recovery, manual/drift and guild lifecycle cases, and uses bounded batches. It includes periodic health/drift checks and recovery of failed operations.

The production rollout included the initial reconciliation, subsequent incremental updates and recovery handling. The source repository does not publish real guild identifiers, run identifiers, exact membership counts or snapshots of operational state.

## Behavioral contracts

- Current User-to-network presence is canonical in `community_network_member_status`.
- Meaningful network transitions are append-only in `community_network_member_events`.
- Community membership presence is recomputed from all network states.
- `member_since` preserves the oldest credible Community participation evidence.
- `last_join_date` records the latest observed join or return.
- Missing members are marked absent only during complete snapshot finalization.
- Incremental events observed after a reconciliation starts are protected from being overwritten by finalize.
- A full snapshot does not fabricate JOIN events during bootstrap.
- A successful complete snapshot advances `last_full_reconciliation_at` and completes its sync run atomically.
- Health self-healing only closes membership runs older than the completed-snapshot watermark.
- Tenant isolation is scoped by Community, network type and external network ID.

## Publication boundary and follow-up

Detailed production queries, workflow runs, release SHAs and live synchronization metrics are intentionally excluded from this publication-facing record.

Production Flyway baseline adoption remains separate future work; the baseline must account for schema already applied through the transitional process.
