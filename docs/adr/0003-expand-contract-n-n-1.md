# ADR 0003: Expand/contract with N/N-1 compatibility

- Status: Accepted
- Date: 2026-09-02

## Context

Database, API, and Discord have independent release cycles. A schema change cannot assume simultaneous deployment.

## Decision

All shared-schema evolution will follow expand/contract and explicitly support application versions N and N-1 during rollout.

### Expand

1. Add backward-compatible schema capability.
2. Validate old and new application versions against it.
3. Apply schema before any application requires it.
4. Deploy compatible writers.
5. Deploy compatible readers.

### Transition

1. Reconcile or backfill only from evidence.
2. Support old and new representations when necessary.
3. Observe production and compare metrics.
4. Confirm N-1 is no longer deployed or eligible for rollback.

### Contract

1. Disable old behavior.
2. Apply stronger constraints or removals only in a later release.
3. Retain a tested application rollback path whenever possible.

## Required migration-release metadata

Every future schema release must declare:

- affected tables and columns;
- domain owner, readers, and writers;
- API N and N-1 compatibility;
- Discord N and N-1 compatibility;
- minimum application versions;
- deploy order;
- data preconditions;
- lock and duration risk;
- validation and recovery steps;
- the later condition that permits contract.

## Rationale

Additive transitions allow either application to be rolled back without forcing a schema rollback. This is particularly important because MariaDB DDL should not be treated as a transactionally reversible release unit.

## Alternatives considered

### Coordinated big-bang deploy

Rejected because applications deploy independently and production is a shared VM.

### Application-first rollout

Rejected when new code requires absent schema.

### Immediate rename/removal

Rejected because N-1 may still use the old contract.

## Risks

- Temporary dual-write or dual-read logic increases complexity.
- Compatibility windows can remain open indefinitely without explicit completion criteria.
- Additive columns can still be incompatible if defaults, nullability, or indexes are chosen incorrectly.

## Enforcement

A schema PR is incomplete without a compatibility statement. Unknown compatibility must block production release rather than be silently inferred.
