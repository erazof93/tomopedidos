# F5-A preparation

Prepared only. F5-A authorizes tools/offline tests, not PostgreSQL races, SQL fixtures,
fault injection or fixture teardown. C/D/E/B1/migrations are unchanged.

Selected: installed `isolationtester (PostgreSQL) 18.6 (Debian 18.6-1.pgdg12+2)` at
`/usr/lib/postgresql/18/lib/pgxs/src/test/isolation/isolationtester`. Only filesystem
discovery and `-V` were executed in Docker, no SQL. It has no parse-only option:
every non-`-V` invocation establishes connections. Structural offline lint is not
native parser/SQL compilation verification.
Primary source: [PostgreSQL REL_18_6 isolationtester.c](https://github.com/postgres/postgres/blob/REL_18_6/src/test/isolation/isolationtester.c).

Harness: standalone Go module, standard library only, go.mod minimum1.26.0; compiled
with installed Go1.27.2. No pgx/toolchain/dependency installation, no backend changes.
Windows binary coordinates a single Docker native call. Linux binary is for the
separate loopback-only fault proxy inside the already-approved F container.
There are 23 native permutations (12 E +9 auth +2 multi-parent), numbered in MATRIX.
All are prepared, none executed. `cleanup12.spec` fixes the reviewed F1 control ID
in a new copy; the old staged .spec and Prepare-FStage are not regenerated. Otherwise
RefreshEnrollment would encounter the authorized staged041 syntax correction.

## Offline commands (safe in F5-A)

From this directory, with `GOTOOLCHAIN=local`, `GOPROXY=off`:

```powershell
go test -count=1 ./...
go build -mod=readonly -o bin/f5harness.exe .
# In a separate build invocation, set GOOS=linux GOARCH=amd64:
go build -mod=readonly -o bin/f5harness-linux .
./bin/f5harness.exe -mode check -root .
```

Unit tests operate on in-memory bytes/receipts, open no PostgreSQL/network connections.
Pins reject drift, duplicate/unknown step names and pending IDs. This is structural
lint, not a complete .spec/SQL parser. `bin/` and `captures/` ignored by Git.

## Future native execution — commands NOT executed

1. Obtain explicit approval for chosen case and its committed synthetic setup/teardown.
2. Each Docker snapshot capture is a separate exec_command: default context, exact F
   container/network/volume. Use the existing selective format, never Config.Env.
   Assert-FDockerSnapshot must pass. Verify digest, version18.6 and all resource IDs.
3. Separate bootstrap001 preflight and007 reconcile: SID7696590721605967915, version4,
   all four tables empty. Separate052 e_stage=enabled verifies C/D/E prerequisites.
4. Trusted operator writes private receipt after those real checks: run_id, database,
   system_identifier, full F container_id, verified_at UTC, no_ports=true,
   exclusive_resources=true, goose_version=4. Age must be <=30s, not future dated.
   Store under .local/b2a-f; never fabricate receipt from stale preparation evidence.
   Receipt is an evidence guard, not an authentication mechanism against an admin.
5. Run **one case only**, then review/reconcile before approving the next:

```powershell
./bin/f5harness.exe -mode native -root . -spec cleanup12.spec -case 1 -receipt D:\tomopedidos\.local\b2a-f\f5-live.json -approval F5_NATIVE_ONLY_7696590721605967915
# auth9.spec: cases1–9; locks2.spec: cases1–2. No automatic loop.
```

The runner invokes only one `docker --context default exec -i ... isolationtester`.
Conninfo is compiled-in host127.0.0.1/port5432/dbF/bootstrap, no DSN override.
Password is referenced from POSTGRES_PASSWORD inside F, never host arguments/logs.
Native sessions use SET LOCAL ROLE only as synthetic SQL concurrency actors; this
does not replace independent authentication evidence from F4. Privileged revokes
are administrator-only fixture sessions, never operational grants.

Each spec repeats exact DB/cluster/version/session/control-ID guard before setup.
Setup requires dedicated empty sessions plus exact fixture collision checks. Cleanup
after a successful permutation removes only its literal synthetic identity/session
IDs in dependency order. Those changes COMMIT: rollback of a test transaction does
not remove separately committed seeds. Document this before future execution.

Captures contain operation result/status and SQL source with synthetic literals only;
never log live tokens/digests/PHC/passwords. `CAPTURED_NOT_APPROVED` is intentional:
review outputs against MATRIX, wait completion and final SQL assertions, then capture
007 and exact fixture absence. Build reviewed per-case golden outputs only from
executed/reconciled evidence; no automatic acceptance of newly generated golden files.
Native tester can print SQL ERROR and continue current-case steps; the runner rejects
the entire capture even if exit0. Never start next case. Preserve partial state.

## Stop/recovery, no Docker deletion

Use native PG_TEST_TIMEOUT_DEFAULT10 (bounded worker wait watchdog). Stop scheduling
new cases on timeout/error. Closing the Docker CLI alone does not prove backend
workers stopped: do not rely on killing it as cleanup. In a fresh bootstrap connection,
inspect pg_stat_activity/pg_locks for exact F database, application prefix and captured
PID set. Cancel only those revalidated workers if separately authorized, wait until
they have disconnected/rolled back, preserve capture and reconcile. No arbitrary
pg_terminate_backend, no Docker down/rm/prune. If interrupted before native teardown,
remove only the documented fixture UUIDs after separate recovery approval; never
global DELETE/cleanup. Do not reset epochs/reapply C/D/E to recover.

## Separate ambiguous-commit harness

`proxy.go` accepts one maintenance client at127.0.0.1:5433 **inside F only**, forwards
to127.0.0.1:5432. Compiled Linux binary refuses another hostname (F ID4218b22fbb21),
expired receipt, other database/actor/application, startup options, extended queries
and oversized frames. No port is published, no container/network is created.
Startup must use maintenance + app `tp-b2a-f-20261014-r01:ambiguous-cleanup`.
SSL/GSS negotiation is declined; explicit sslmode=disable on this loopback test only.
No wire contents/auth messages are printed. Bound one client/socket lifetime30s.

Future commands, separate invocations and new fault approval required:

```text
# First run090 seed only after fresh F preflight and empty-state approval.
docker --context default exec tp-b2a-f-20261014-r01-pg /f/control/f5/bin/f5harness-linux -mode proxy -receipt /f/control/f5/captures/f5-live.json -fault before-commit -approval F5_FAULT_ONLY_7696590721605967915
# Or -fault drop-ack; never both on the same fixture without reconciliation.
# Separate interactive real maintenance psql through127.0.0.1:5433:
docker --context default exec -it -e PGAPPNAME=tp-b2a-f-20261014-r01:ambiguous-cleanup -e PGSSLMODE=disable tp-b2a-f-20261014-r01-pg psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5433 -d tp_b2a_f_20261014_r01 -U tomopedidos_session_maintenance -W -v f_actor=tomopedidos_session_maintenance -v f_system_id=7696590721605967915 -f /f/control/fixtures/095_ambiguous_batch.sql
# After outcome unknown, fresh DIRECT bootstrap096 reconciliation, never retry cleanup.
```

Private Linux receipt contains identity metadata only, no credentials, in ignored
captures path. Do not mount host credential files. Proxy mode is separate from native
mode and requires a different scope token; these tokens do not substitute user approval.
before-commit event says COMMIT not forwarded; rows2 and backend gone support rollback.
drop-ack event records observed serverCommandComplete but caller stays unknown;
rows0 in fresh reconciliation establishes committed deletion of exact synthetic rows.
If counts are partial/parents changed or transport failed elsewhere, block and investigate.
Commit/teardown DELETE are irreversible for seeds; no production data/PITR assertions.

## Not verified / backend dependencies

SQL races directly test locks, state, epochs, retention and provisional results.
Future SQL051/092–094 cover atomicity, timeouts/cancel; realclock jumps need an isolated
VM, not host-time changes. Proxy protocol/frame recognition tests do not establish
real SCRAM transport or commit behavior until F5-B execution.
Go auth/session services, Argon2id proof/rehash equivalence, CSRF/keyring, MFA/recent
authentication, HTTP/pool/context cancellation, retry policy and UI outcome-unknown
handling are not implemented/certified by this standalone harness. Keep them separate.
No implementation hooks/time mocks or privilege widening are added to C/D/E.
