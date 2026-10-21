# Recruitment — foundation schema (V1, not active in production)

## Scope and authority

- Database alone owns schema and Flyway SQL: `V20261021_001__create_recruitment_foundation.sql`.
- API alone owns process administration, candidate eligibility, transition rules,
  assessment security, authorization and audit.
- Front consumes redacted API DTOs and never evaluates answers or permissions locally.
- Coddy remains outside the V1 execution path.
- Initial feature availability is **BraFurries Community only**, enforced at API
  authorization/service boundaries using an approved Community identity, not a
  hardcoded numeric Community ID or frontend-only navigation flag.
- This PR provides **schema foundation only**. No endpoint, user flow, permission
  grant, production schema change, or Flyway operational adoption is delivered.

## The first five additive tables

| Table | Key meaning | Integrity |
| --- | --- | --- |
| `recruitment_processes` | One process in a Community | `(community_id,id)` unique; author and Community FKs |
| `recruitment_process_versions` | Draft/published/superseded immutable published snapshot | `(community_id,process_id,id)` and version number unique; same-tenant process FK |
| `recruitment_stages` | Ordered stage of **one version** | `(community_id,process_version_id,position)` unique and same-tenant/version FK |
| `recruitment_applications` | One User per process, version frozen on submission | `(community_id,process_id,candidate_user_id)` unique; version FK and `(community_id,candidate_user_id)` membership FK |
| `recruitment_application_stages` | Candidate's execution of one versioned stage | Both stage and application FKs repeat `community_id` and `process_version_id`, preventing cross-tenant and cross-version links |

Internal and public stage names are independent. Candidate and Staff question
definitions are separate JSON columns; evaluation configuration has a separate
JSON column. **The presence of a JSON shape is not contract approval**: the API
must validate and version each typed schema; correctness cannot rely on JSON_VALID.

The application FK to `user_community_status` proves a user/community link,
**not** active eligibility. The API must separately check current membership
state, bans, and requirements at inscription time.

The unique application key prevents resubmission within a given recruitment
process. A later edition must use a new process identity, not merely a new
definition version.

## Deliberately postponed tables

This first migration does **not** create attempt, response, vote, evaluation,
decision, notification, exception, appeal or retention tables. They belong to
subsequent additive Database-only migrations reviewed together with the
relevant API contracts, and must refer to these parents through community
scopes. Do not repurpose Discord `form_*` tables.

Likewise, process-specific delegation must build on the existing Community
capability grants while adding explicit per-process/per-stage scoping in the
API and/or its own future schema. Existing Team hierarchy is not itself a
grant of recruitment rights.

## Snapshot and publication safety

- `DRAFT` stages may be edited; once published, an API operation must create
  a new version for structural changes rather than mutate in-flight versions.
- `status`, `visibility`, and `enrollment_status` on the process are
  orthogonal; API enforces valid transitions and all scheduling semantics.
- `publicly_available_at` is **not** a decision or proof of publication.
  The future publication ledger/decision table must determine whether results
  and next candidate actions can be exposed. Do not infer approval from the
  presence of next-stage records.
- Gabaritos, staff-only JSON and vote details must never be sent to candidates
  before authorized publication. The future API must use separate DTOs.
- Transactional and optimistic/pessimistic concurrency controls belong in the
  API stage transition and decision implementation.

## Baseline vs new versions

The canonical production dump remains represented by the **107-table**
`B20261020_001` baseline. The 107-table ownership manifest is a snapshot of
that pre-feature production shape; it is **not** evidence of deployment of
these five new objects.

The historical baseline and tenant smoke tests use the baseline-only location
to preserve the original 107-table/946-column fingerprint. The new
`recruitment_foundation_smoke_test.py` uses baseline + official versioned
locations, verifies exactly 112 application tables and validates synthetic
cross-tenant and cross-version FK failures.

Before any production release:
1. Recheck active schema fingerprint and the presence/absence of these tables.
2. Verify Flyway state and the approved manual-transition process; do not
   perform an automatic baseline or `baselineOnMigrate`.
3. Produce release evidence, backup and compatibility plan.
4. Get separate explicit approval for applying DDL, merging/deploying services
   and enabling the BraFurries-only feature.

No production actions are authorized by this migration PR.
