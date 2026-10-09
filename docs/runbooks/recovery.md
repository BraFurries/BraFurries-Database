# Conceptual runbook: migration recovery

## Status

Conceptual only. This document contains no executable rollback or production command.

## Principles

1. Prefer application rollback over schema rollback.
2. Prefer forward-fix after applied MariaDB DDL.
3. Never assume a migration containing multiple DDL statements can roll back transactionally.
4. Never use Flyway metadata repair as a substitute for fixing the actual schema.
5. Preserve evidence before taking corrective action.

## Incident classification

### A. Failure before schema mutation

- Stop the release.
- Leave applications on their current versions.
- Correct the artifact or precondition in a new review cycle.

### B. Additive schema succeeded, application failed

- Roll back the application to N-1.
- Leave compatible additive schema in place.
- Diagnose and publish a forward application fix.

### C. Migration partially affected schema

- Stop all schema deploys.
- Capture actual structure and Flyway metadata.
- Determine which statements took effect.
- Assess data and lock impact.
- Restore only when the approved recovery threshold requires it.
- Otherwise prepare a reviewed forward-fix.
- Reconcile Flyway metadata only after the schema is correct.

### D. Data repair produced unexpected results

- Stop affected writers when needed.
- Preserve before/after evidence.
- Do not rerun non-idempotent repair blindly.
- Restore affected tables or apply a reviewed compensating change according to the approved plan.

### E. Destructive change caused loss

- Activate the tested backup/restore plan.
- Treat application rollback alone as insufficient.
- Preserve incident evidence and block further migration releases.

## Decision order

1. Is production safe to keep serving?
2. Can the application roll back while keeping the expanded schema?
3. Is the schema internally consistent?
4. Did any irreversible data loss occur?
5. Is forward-fix safer than restore?
6. Does recovery meet approved RPO/RTO?

## Backup requirements

Risk-bearing releases require:

- defined backup scope;
- successful restore rehearsal;
- owner and timestamp;
- retention window;
- recovery-duration estimate;
- affected-table export when appropriate;
- proof that backup material is stored securely outside Git.

## Flyway history recovery

Do not delete or edit history rows ad hoc. If metadata and schema disagree:

1. inspect both independently;
2. document the exact mismatch;
3. restore or forward-fix the schema;
4. obtain human approval;
5. only then reconcile metadata with the supported mechanism.

## Required incident record

- release and artifact checksum;
- operator and timestamps;
- expected and actual schema versions;
- statements/effects known to have completed;
- application versions;
- data impact;
- chosen recovery path and approvals;
- validation after recovery;
- follow-up prevention actions.
