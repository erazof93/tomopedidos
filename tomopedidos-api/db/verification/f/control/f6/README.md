# F6-A preparation — no PostgreSQL execution

Execution remains pending separate F6-B/F6-C approval. No SQL, Goose, Docker,
cancel or new credentials were executed/provisioned by F6-A. Existing F6 controls
only read pinned project files and compile/test local standard-library helpers.

Target fixed: project tp-b2a-f-20261014-r01; container tp-b2a-f-20261014-r01-pg;
database tp_b2a_f_20261014_r01; SID7696590721605967915; PostgreSQL180006; digest
afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c; Goosev3.29.0.
Credentials remain independent existing F secrets, never root.env or other systems.

## Dependencies and destructive effects

| Migration/package | Objects | Dependents / removal order |
|---|---|---|
|00001|identities, identity_credentials;3 PK/UNIQUE indexes|credential FK→identity; audiences/sessions from00002; guards00003; logical C/E references|
|00002|audience_revocations, sessions;3 further PK/UNIQUE indexes|session FK→audience+identity; guards/indexes00003/00004; C/E data access|
|00003|3 INVOKER guard functions+3 triggers;2 session indexes|Down drops indexes, then each trigger before its function|
|00004|cleanup terminal expression index|E discovery query benefits from index; remove E first, then explicit index Down|
|C|9 DEFINER functions owned by2 auth executors|D column grants/caller7EXECUTE; remove D caller+executor rights before exact9-function administrative Down|
|E|cleanup_sessions+column/DELETE grants|maintenance caller CONNECT/USAGE/EXECUTE; disable/drain, remove function and executor rights before table/index Down|
|B1/Goose control|5 schemas, roles/defaultACL, migration_meta.goose_db_version|Retain through cycle; no bootstrap repeat/role deletion|

`dependency_inventory.sql` captures pg_depend/owners in future execution. PL/pgSQL
string bodies/%ROWTYPE can reference tables without complete persistent catalog
edges. Therefore do not assume PostgreSQL will reject Down while C/E exist: remove
them explicitly. ACL grants do not generally prevent DROP; they vanish with their
table/function and cannot restore caller safety by themselves. FK edges and trigger
edges are concrete; approved Down orders remove dependents first. No CASCADE needed.
Unknown extensions/views/FKs/functions/grantees block execution, never add CASCADE.

Down removes all4 tables and their data irreversibly after COMMIT, including identities,
credential PHC, session state and epochs. Preconditions demand every identity table
empty and callers drained. Re-Up recreates schema, **does not recover data**. Caller
disable affects new CONNECT/EXECUTE but does not cancel old sessions. Credentials,
roles and B1 schemas/defaults remain; no role-provision scripts in recovery.

## F6-B exact plan

Every Docker/SQL/Goose invocation is a separate exec_command, stop on first mismatch.
No runner batches the mutations. Print-F6Commands.ps1 prints commands only.
Before every mutation: refresh selective Docker C/N/V snapshots, Assert-FDockerSnapshot,
image/digest,000identify+001preflight, then applicable transition assertion. Pins must
match both F6 manifest and original C/D/E/staging manifests. Never inspect Config.Env.
Drain F auth/maintenance connections voluntarily; current observer is excluded.
No blanket backend termination. Freeze jobs and fixtures for the whole cycle.

| Step | Action / expected version,C,E after COMMIT | Assertion |
|---|---|---|
|0|Current4,enabled,enabled|052enabled + check_transition; empty/drained|
|1|E disable→4,enabled,dormant|052dormant; maintenance no CONNECT/USAGE/EXECUTE|
|2|E administrative Down→4,enabled,absent|check_transition; cleanup gone, no E executor rights|
|3|D disable→4,executors,absent|040executors; auth no CONNECT/USAGE/EXECUTE|
|4|D ungrant→4,c,absent|check_transition with C stagec; owners/source unchanged|
|5|control003 exact C Down→4,absent,absent|check_transition; only3 B helper functions left|
|6|Goose down-to3→3,absent,absent|latest-version assertion;4 tables/8 indexes/3 guards|
|7|Goose down-to2→2,absent,absent|4 tables/6 indexes/no guard functions or triggers|
|8|Goose down-to1→1,absent,absent|2 tables/3 indexes, audiences/sessions absent|
|9|Goose down-to0→0,absent,absent|zero identity objects; control002 + B1 metadata010 read-only, retained roles/schemas|
|10|Goose up-to1→1,absent,absent|2 tables/3 indexes and latest version1|
|11|Goose up-to2→2,absent,absent|4 tables/6 indexes and latest version2|
|12|Goose up-to3→3,absent,absent|3 guards/8 indexes and latest version3|
|13|Goose up-to4→4,absent,absent|9 indexes;004metadata,030integrity corrected with ROLLBACK|
|14|C install only, roles retained→4,c,absent|C package source/owner/ACL assert, check_transition|
|15|D executor grants→4,executors,absent|040executors; callers still disabled|
|16|D enable→4,enabled,absent|040enabled;7 authEXECUTE only;041 real auth26/tenant33|
|17|E install only, roles retained→4,enabled,dormant|052dormant; no maintenance CONNECT/EXECUTE|
|18|E enable→4,enabled,enabled|052enabled;070maintenance real login,071negatives|
|19|Read-only/state fixtures|060/061/050/051 bounded fixtures with ROLLBACK, real auth/tenant/maintenance connections;007empty and final identity|

Goose ALWAYS `-table migration_meta.goose_db_version`, migrator real login with
startup `role=tp_owner` and search_path=migration_meta,pg_catalog per Compose tools.
Administrative C/D/E uses bootstrap, never operational caller credentials as admin.
Retain auxiliary Goose containers: no --rm/remove-orphans/down/rm/prune. Explicit
future approval must include creation of these F-only tool containers if needed.

check_transition arguments: `-v f_version=V -v f_c=absent|c|executors|enabled
-v f_e=absent|dormant|enabled`. It is read-only and checks latest row per version,
empty tables, counts/owners/roles/schemas/drained callers, and C/E pinned assertions
when present. Original006_f3_state max historicalis_applied is **not** suitable
for Down: old successful Up rows remain. Original004 after Re-Up4 is supplemented
by latest-row transition check, not altered. SQL parser/execution is still pending.

## F6-C timeouts/cancel plan

Execute after stable recovery to version4/C/D/Eenabled (or separately before Down),
never during disable/reinstall. One case at a time, distinct real connections.

1. Fresh F physical/SQLpreflight/052/007. Authorized090 seed COMMIT exact f3 IDs only.
2. Bootstrap holder.sql locks fixture Identity FOR UPDATE, records PID/backend_start
   and prints F6_HOLDER_LOCK_ACQUIRED. This acquired-lock signal is the barrier.
3. A new REAL maintenance connection runs one of the files below. No SET ROLE admin
   as surrogate operational session; existing private maintenance secret/psql-W.
4. Observe exact F PID/start/application/blockers via observe_cancel.sql. The
   cancellation case requires exactly one captured pair; record0/>1 means stop.
   Timeouts use the acquired-holder signal as their barrier (short timeout may
   finish before a manual observer sees the waiter). Never sleeps alone, never
   release holder before failure is actually observed during the normal test.
5. On cancellation only, cancel_exact.sql requires waiter+holder PID/backend_start,
   roles/DB/application/state and sole blocker identity, then rechecks before one
   pg_cancel_backend. Supplied observations must be <=5s old; stale/reused PID,
   extra blocker or wrong role blocks. PID-only cancellation is forbidden. No
   pg_terminate_backend or arbitrary PostgreSQL/server/container operations.
6. Expected error is captured immediately from psql SQLSTATE/ERROR. ON_ERROR_STOP
   is disabled for **one** deliberate failing query only; ON_ERROR_ROLLBACK=off.
   The file restores ON_ERROR_STOP, explicitly ROLLBACKs, asserts exact error code,
   then starts a new read-only transaction in the same connection. Recovered_pid
   must equal initial waiter_pid; successful probe COMMIT is not cleanup success.
7. Fresh bootstrap reconcile_timeout: two fixture sessions/parents intact; inspect
   locks/backends. Release holder with ROLLBACK only after failure evidence, verify
   no blocked worker/session and no preparedtransaction;097 exact teardownCOMMIT.
8. 007empty/final117/052enabled. Capture commands, actors, SQLSTATE, rollback markers,
   backend_start, timing, counts and recovered PID. Never retry cleanup after loss.

| Case | Timeouts | Expected classification |
|---|---|---|
|lock_timeout.sql|lock250ms,statement5s|55P03,ERROR_ROLLED_BACK_CONNECTION_RECOVERED|
|statement_timeout.sql|lock0,statement2s|57014,ERROR_ROLLED_BACK_CONNECTION_RECOVERED|
|cancel_waiter.sql|lock0,statement0; external watchdog must cancel only identified waiter|57014 only after confirmed cancellation sent/observed, not inferred from timer|

cancel_waiter deliberately has no automatic SQL timeout to distinguish explicit
cancel from57014statement timeout. Supervisor deadline20s requires stopping new
work and separately authorized targeted cancellation of the same captured PID if
the intended signal fails; never close Docker CLI and assume its backend stopped.
If targeted cancellation cannot be established, mark the test failed and recover
only the captured fixture connections under recovery approval. This waiter script
always ROLLBACKs its cleanup attempt, even if releasing the holder lets it finish;
00000 then fails the expected-error assertion. Such recovery is not a passed cancel
case. Do not leave an unsupervised blocked query, signal an arbitrary PID or restart
the server to hide the failed test.
Connection loss before SQLSTATE/rollback/recovery marker →UNKNOWN_RECONCILE_NO_RETRY,
no operation success. pg_cancel_backend=true only means signal sent, not observed
failure. Unexpected success/SQLSTATE/deadlock/partial row loss means stop and retain
fixture evidence; no grant widening or function fix.

The helper binary has no DB/process/network imports and cannot run/cancel SQL. Its
offline tests model Goose history, classifications and exact target/PID reuse. The
SQL files themselves have not been compiled/executed by PostgreSQL in F6-A.
Reference: [psql18 error variables and control](https://www.postgresql.org/docs/18/app-psql.html).

## Stop and recover a partial administrative cycle

Each package/migration has its own transaction. Confirm COMMIT/version and previous
state before advancing; do not wrap nested package BEGIN/COMMIT in a global tx.
Error before COMMIT: connection rollback leaves prior transition; preserve evidence.
Lost COMMIT response: fresh read-only transition inventory/latest Goose records,
source/owner/ACL and drained sessions determine actual state. Never reapply initial
install/provision blindly. Resume from the exact observed state and only after scope
approval; role provisioning/B1 never repeated. Unknown data/dependency/grants or
nonempty table blocks all Down. Restore missing migrations ascending, then C/D/E in
the above order; enable callers last. No CASCADE, cleanup global, rollback of real
credential data or Docker deletion as a recovery shortcut.

## Backend Go boundary — explicitly not implemented here

Current API router only exposes /healthz; internal/database has a future Executor
interface, no connected auth/session repository. Dependency pgx is not implementation.
Pending Go contracts/tests: Argon2id verification/parameter/resource ceilings/rehash
equivalence; random raw tokens, digest handling, key lifecycle; CSRF binary/keyring
and rotation; cookie Secure/HttpOnly/SameSite/expiry; HTTP login/logout/renewal/MFA,
recent authentication/privileged authority; transactions/pool search_path/role reset,
context cancellation, deadlines and one operation/transaction; outcome-unknown vs
confirmed commit, no automatic retry/token/cookie issuance before confirmed commit,
client/UI reconciliation, error mapping and secret-safe logging. SQL lexical PHC,
epochs, locks, constraints, retention and F5 proxy results prove only their tested
PostgreSQL scope, not those application guarantees. Real system-clock jumps remain
separate controlled-VM work, never host-clock manipulation.

Approve F6-B only after every transition+post-cycle isolation/source/fixtures and
empty state passes. Approve F6-C only after all3 exact failures, rollback, released
locks and same/new-connection recovery pass. Full B2-A closure must identify any
remaining application/operational acceptance separately; no blanket verified claim.
