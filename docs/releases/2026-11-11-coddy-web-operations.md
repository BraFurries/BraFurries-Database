# Coddy Web presence and outbound message controls — staged rollout

## Ownership and security
- **Database:** `V20261111_002` creates a global desired presence singleton and an action audit/idempotency ledger. No existing data is moved or removed.
- **API:** control plane, global `ROLE_ADMIN` only, validates active Community/Discord guild linkage for sends, content lengths, payload hashes, request UUIDs and audit records.
- **Coddy:** runtime only; authenticated bearer internal endpoints perform Discord actions and inspect *live* writable channels. It reapplies the persisted desired presence at READY. No runtime DDL or platform authorization decisions.
- **Front:** global administration panel, controlled selection + preview + explicit confirmation; no bot secrets and no direct Discord API.
- **Multi-tenancy:** global presence has no tenant. Message dispatch is always linked to an active `community_discord` with its exact Community ID; Coddy confirms the guild/channel match. An admin of a single guild without global ADMIN must never gain access.
- **Idempotency:** an audit UUID is consumed once; retries with the same key never invoke Discord twice. An uncertain response after dispatch stays `REQUESTED` or `UNKNOWN`, not automatically retried. Neither message contents nor OAuth/bot tokens are stored in the ledger.

## Deployment sequence
1. Validate schema PR against disposable MariaDB 10.6. Confirm production backup and inspect the existing schema, migration version and disk/locking risk.
2. Operator applies the exact Database migration and checks both new tables/constraints; do not create DDL via API or Coddy.
3. Deploy Coddy's internal endpoints, while **retaining** the legacy `/coddy status` and `/coddy falar` commands.
4. Deploy API, verify global admin denial for non-admins and cross-tenant guild validation.
5. Deploy Front, verify presence update and one safe test message with explicit confirmation.
6. **Only after Web parity is verified**, deploy the separate Coddy slash-command retirement PR; confirm `tree.sync()` removed both public commands. Do not claim #11 complete for unrelated command retirement.
7. Validate audit/response outcomes, live bot presence after reconnect, and no duplicate sends.

## Rollback
- Stop issuing Web mutations by hiding Front controls or reverting API PR; Database tables can remain for N/N-1 compatibility.
- Keep legacy slash commands until Web parity is demonstrated.
- Sent Discord messages are external effects and are not rolled back by a database transaction.
- Do not automatically retry an uncertain delivery with a new request key.
- No production DDL, DML or deploy is authorized by this document itself.
