# Schema compatibility policy

## Scope

This policy coordinates independently deployed versions of:

- BraFurries-Database;
- BraFurries-API;
- BraFurries-Discord.

Frontend compatibility is handled through API contracts and must be included when a schema change changes an HTTP response or action.

## N/N-1 rule

During a schema rollout, the expanded schema must support:

- current application release N;
- previous supported application release N-1.

Contract changes are permitted only after N-1 is no longer deployed and is no longer the expected rollback target.

## Default deployment order

1. Database expand release.
2. Validation against currently deployed API and Discord.
3. New writer release, if any.
4. New reader release, if any.
5. Reconciliation/backfill with explicit evidence rules.
6. Observation window.
7. Contract release in a later cycle.

## Compatibility matrix template

| component | N-1 | N | required schema state | behavior before cutover | behavior after cutover |
|---|---|---|---|---|---|
| Database | TODO | TODO | TODO | TODO | TODO |
| API | TODO | TODO | TODO | TODO | TODO |
| Discord | TODO | TODO | TODO | TODO | TODO |
| Frontend, if affected | TODO | TODO | API contract only | TODO | TODO |

Every future migration release must fill this matrix.

## Additive does not automatically mean compatible

Review at least:

- nullability;
- defaults;
- generated values;
- type widening/narrowing;
- unique and foreign-key behavior;
- index creation lock/cost;
- old writers omitting new columns;
- new writers producing values old readers cannot interpret;
- JPA field types and repository keys;
- Discord SQL predicates and upsert keys.

## Rollback principle

Application rollback is preferred over schema rollback. An expand migration should remain safe when API or Discord returns to N-1.

## Breaking changes

Renames, removals, type narrowing, stricter nullability, key changes, and semantic repurposing require a multi-release contract plan. They must never be combined with unrelated changes.

## Runtime DDL compatibility

Until Discord DDL is retired, a Database release must also prove that legacy initializers:

- do not revert the canonical shape;
- do not drop a new key or column;
- do not mis-detect the migrated schema;
- do not run a conflicting rename or repair.

The long-term solution is retirement, not indefinite dual ownership.

## Unknown compatibility

`UNKNOWN` is a blocking state for production, not implicit approval. A release with unresolved reader/writer compatibility must remain unpromoted.
