# F5 matrix — prepared, not executed

Native sessions are independent libpq connections. Lock waits are detected by
`pg_isolation_test_session_is_blocked`, not sleeps. Each invocation runs one numbered
permutation. A SQL error or missing wait/result stops acceptance; never advance or retry.
The native tool can finish its current permutation/teardown after printing a SQL
error: do not mistake that output or exit0 for approval. Review the capture and
reconcile immediately. No automatic loop over cases is provided.

## Twelve inherited E permutations: cleanup12.spec

| Case | Order/barrier | Observable results | Final invariant |
|---|---|---|---|
|1|Cleanup holds old session; validation blocks until commit|cleanup 1/1/0; validation invalid|Old absent, live retained, parents unchanged|
|2|Old validation detects expiry; cleanup blocks until auth commit|validation expired; cleanup 1/1/0|Late detection does not restart 30d|
|3|Explicit old expiry first; cleanup waits|mark_expired expired; cleanup 1/1/0|Same natural-terminal anchor|
|4|Live renewal first, old cleanup|activity_recorded; cleanup 1/1/0|Live retained; no false eligibility|
|5|Old cleanup first, live renewal|cleanup 1/1/0; activity_recorded|Live retained; separate session locks|
|6|Live logout first, old cleanup|revoked; cleanup 1/1/0|Recently revoked live row retained|
|7|Cleanup parent SHARE; global revocation waits|cleanup 1/1/0; global_revoked|Live epoch-only invalidated row retained|
|8|Global parent UPDATE; cleanup waits|global_revoked; cleanup 1/1/0|Same retention despite epoch change|
|9|Cleanup audience SHARE; audience revoke waits|cleanup 1/1/0; audience_revoked|Live snapshot immutable, row retained|
|10|Audience revoke first; cleanup waits|audience_revoked; cleanup 1/1/0|Epoch does not create terminal time|
|11|Two cleanup callers; second waits on old row|first 1/1/0; second 1/0/1|No double delete; one live survivor|
|12|Cleanup followed by rollback|provisional 1/1/0|Two original sessions restored|

Rows 4–6 need not wait: they touch different sessions with compatible parent SHARE
locks. Never assert a wait merely because calls overlap. For every capture check
the actual wait events, operation results and SQL final invariant together.

## Additional native scenarios: auth9.spec

| Case | Barrier | Asserted result/final state |
|---|---|---|
|1|Validation holds session UPDATE; logout waits|valid then revoked; revoked_at persists|
|2|Logout holds session; validation waits|revoked then invalid with no session metadata|
|3|Validation holds Identity SHARE; global revoke waits|valid then global_revoked; epoch1/snapshot0|
|4|Global revoke holds Identity UPDATE; validation waits|global_revoked then invalid; epoch1/snapshot0|
|5|First renewal holds session; second waits|Both activity_recorded; deadlines ordered and capped|
|6|First logout holds session; second waits|First revoked, second invalid; terminal row retained|
|7|Rehash holds Identity UPDATE; validation waits|revision2/epoch0; validation valid|
|8|Validation holds Identity SHARE; rehash waits|valid then rehashed; revision2/epoch0|
|9|Synthetic future activity, then validation|clock_anomaly, null metadata, no terminal mutation|

Case9 changes fixture timestamps, **not the host/server clock**. Real clock jumps
require separately authorized VM/time virtualization; they are not covered here.
Rehash uses lexical synthetic PHC, does not verify Argon2id, equivalence or MFA.

## Stable multi-parent ordering: locks2.spec

Two identities, two old sessions and one live session. Both cleanups acquire parents
and sessions in the production order Identity → audience → session, UUID sorted.
Case1: first deletes2/commits; second waits, then examines2/deletes0/skips2.
Case2: first provisionally deletes2/rolls back; second waits, then deletes2.
Final: one live session, two parents, four audiences. No 40P01 tolerated.
This is a bounded regression case, not proof of deadlock freedom for all workloads.

## Separate faults; not native permutations

| Fault | Deterministic barrier | Assertion/recovery |
|---|---|---|
|SQL/clock/isolation rejection|Prepared 051 fixture, no external threads|22008/25000; whole call atomic, ROLLBACK|
|Lock timeout|091 holder reports lock acquired; observer confirms exact waiter PID and blocker|092 must see55P03, ROLLBACK; release holder after error observed|
|Statement timeout|Same lock barrier with statement_timeout shorter than lock_timeout|57014, no successful counts; ROLLBACK, rows unchanged|
|Cancel|093 waiter active and blocked; 094 revalidates F actor/application/PID|57014; no arbitrary backend cancellation|
|Disconnect before COMMIT|Proxy sees exact single simple-query COMMIT and does not forward it|Caller unknown; server disconnect rollback; reconcile2 rows|
|Lost COMMIT acknowledgment|Proxy observes backend CommandComplete(COMMIT), withholds it|Caller unknown; fresh reconciliation0 rows establishes committed effect|
|Other disconnect point|Neither proxy event nor current row counts establish the original outcome alone|Unknown; stop, no retry; preserve evidence and investigate|

090–097 use their existing distinct synthetic fault UUIDs. Seed has COMMIT; teardown
is by exact fixture IDs only, after evidence and new approval for recovery execution.
Never replay a cleanup call after ambiguous commit. No proxy/injection is run by
`check`, builds or unit tests.
