# F6-C — COMPLETE / PASS (2026-10-14)

## Preflight / offline checks

PASS exact approved F destination: Compose tp-b2a-f-20261014-r01; container tp-b2a-f-20261014-r01-pg; DB tp_b2a_f_20261014_r01; SID7696590721605967915; PostgreSQL180006. Fresh selective Docker C/N/V snapshots and unchanged Assert-FDockerSnapshot PASS: exclusive internal network/volume, permitted mounts, no published ports. Running image ID matched image inspect and approved RepoDigest sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c.

Check-F6 and Check-F PASS; all seven F6-C SQL pins/routes and seed090/teardown097/final117/metadata052 dependencies exact and unambiguous. Existing approved SQL unchanged. Private ignored Invoke-F6Maintenance.ps1 prepared from existing real-maintenance helper, limited to lock_timeout/statement_timeout/cancel_waiter, no provisioning, parser PASS and git check-ignore PASS. No real maintenance scenario executed.

Fresh000 identify, check_transition4/enabled/enabled,052enabled,117final all exit0/ROLLBACK: Goose4, four tables empty, C/D/E source/owners/roles/ACL expected, no F test connections/prepared transactions.

## Actual execution and error

090_fault_seed.sql exit0/COMMIT: one synthetic identity f3000000-0000-4000-8000-000000000001, two audience rows, two sessions f3100000-0000-4000-8000-000000000001/2. No credentials created. These are expected retained fixtures, not unexplained data.

Started original holder.sql through Docker exec -i with psql -f and tool stdin. It acquired FOR UPDATE, printed F6_HOLDER_LOCK_ACQUIRED and PID2527/backend_start2026-10-14 23:06:49.522673+00. At line9, prepared interactive prompt failed:
psql:/f/control/f6/holder.sql:9: error: backslash-prompt: could not read value for variable
Docker/tool exit1. Native invocation did not retain readable interactive stdin. Terminal barrier alone was insufficient: holder exited before any maintenance connection started. No script correction/retry after unexpected error.

lock_timeout scenarios executed0; statement_timeout0; explicit cancellation0. Expected55P03/57014 NOT tested, no target signaled. No ambiguous COMMIT claim. Holder's explicit ROLLBACK line was not reached; its uncommitted transaction closed with the failed psql connection. Do not report explicit rollback/recovery tests passed.

## Diagnostic read after stop

Only the preapproved read-only reconcile_timeout.sql was executed after the error to record current fixture/connection state; exit0/BEGIN READ ONLY/ROLLBACK. Asserted two synthetic sessions, one synthetic identity and two audiences intact. No rows in pg_stat_activity for F6-prefixed applications: holder no longer exists, hence no lock remains owned by that closed holder. No timeout/cancel waiter existed, no unrelated backend canceled. No fixture DELETE/cleanup or teardown run after stop.

Last full metadata verification before seed confirmed Goose4 and expected roles/CDE ACL. No schema/grant/migration modifications were executed afterward; final metadata/empty-state assertion was NOT run because five synthetic rows remain (1identity+2audiences+2sessions), credentials0. All four tables are therefore NOT empty at stop.

## Recovery and closure recommendation

Stop maintained. A separately authorized transport-only recovery is needed to keep holder stdin open until deliberate release, offline-test that transport, then refresh identity/metadata and reconcile the existing exact fixtures before deciding whether to reuse or remove097. Do not rerun090 against nonempty tables. No need for Goose/B1/CDE reinstalls or grants. Holder transport must preserve original assertions and explicit release-after-failure barrier; never introduce blind sleeps or arbitrary backend cancellation.

F6-C incomplete. Do not close the full PostgreSQL verification scope while three timeout/cancel cases are unexecuted. F1–F6-B prior results remain historical PASS. Backend Go integration/Argon2id/tokens/CSRF/cookies/HTTP/pools/ambiguous-outcome handling also remains pending. No claim B2-A completely verified.

Changes this turn: this report, F6C_TRANSCRIPT.md, docs/verification.md; private ignored maintenance transport helper. No changes to B1, migrations, C/D/E SQL or grants; no Docker restart/stop/delete, principal/Celtas access, commit/push/deploy.

## Controlled recovery and completion — PASS — 2026-10-14

This section supersedes the prior STOP status. F6-C COMPLETE: all three original scenarios passed and exact synthetic fixtures were removed. No functional PostgreSQL contracts changed.

### Holder transport correction / offline checks

Original holder.sql uses psql backslash-prompt for release. Prior exec-i invocation inherited an unreadable/closed input stream, so prompt read EOF after acquiring its lock. Start-F6Holder.ps1 now owns a redirected child stdin pipe and keeps it open. It reads the exact F6_HOLDER_LOCK_ACQUIRED marker before emitting CONTROL_READY, then blocks on a named-pipe control barrier. Release-F6Holder.ps1 sends RELEASE_AFTER_CONFIRMED_FAILURE only after observed expected error/ROLLBACK/same-PID recovery. Transport writes one release line, observes original holder.sql ROLLBACK and child exit0. No manual input, sleeps, blind delays, server modifications or extra grants. Exactly one Docker invocation per live holder exec_command; bootstrap credential stays in container environment, never printed.

Test-HolderTransport.ps1 used a fake child (no Docker/SQL) with real stdin/named-pipe synchronization: acquired barrier, input stays open, explicit release, rollback marker, process exit0 PASS. Check-F6 and Check-F PASS before/after execution, original scripts/source pins unchanged. Seven original F6 SQLs and dependency paths/hashes reviewed; new read-only reconcile_existing.sql records exact reuse preconditions.

### Fresh preflight and fixture reconciliation

Fresh actual C/N/V/image snapshots and Assert-FDockerSnapshot PASS: exact project/container F, approved image digest, internal exclusive network, permitted mounts/exclusive volume, no host ports.000identify confirms SID7696590721605967915, database tp_b2a_f_20261014_r01, PostgreSQL180006;052enabled confirms C/D/E source/signatures/owners/ACL/role attributes/memberships; latest Goose4 asserted.

reconcile_existing.sql READ ONLY PASS/ROLLBACK before reuse and after each case. Global row counts exactly identities1/credentials0/audiences2/sessions2; identity UUID f300...0001/email fault-f@example.invalid/status pending/epochs0/revision0, audiences admin/platform epochs0, session UUIDs f310...0001/2/digests match original synthetic seed/CSRF fields/terminal marks NULL/deadline relationships intact and both naturally expired>30d. No extra rows, no F test connections or prepared transactions. Therefore existing fixtures reused for all three cases without duplicating090 or recreating data. Metadata preflight and final source checks imply no B1/CDE changes.

### Observed individual scenarios

| Case | Holder PID/start UTC | Real maintenance waiter/recovered PID | Expected/observed SQLSTATE | Result |
|---|---|---|---|---|
|lock_timeout250ms, statement5s|2572 / 23:10:11.465787|2580 / 2580|55P03 /55P03|PASS|
|statement_timeout2s, lock0|2602 /23:10:44.991314|2610 /2610|57014 /57014|PASS|
|explicit cancel, statement0/lock0|2632 /23:11:23.880105|2640 /2640|57014 /57014|PASS|

All dates2026-10-14. Waiter backend_start:2580=23:10:24.954065+00;2610=23:10:59.191829+00;2640=23:11:36.893002+00. Independent real maintenance TCP logins use existing private F password/stdin, no SET ROLE substitute. All original scripts captured SQLSTATE/ERROR immediately, then explicit ROLLBACK and new READ ONLY transaction on the SAME backend PID, marker F6_CONNECTION_RECOVERED_OPERATION_ERROR, probe COMMIT, DockerExit0. Probe COMMIT confirms connection recovery, NOT successful cleanup. No unknown/ambiguous result or automatic retry. No ordinary DML continued in the aborted transaction before ROLLBACK; no additional deliberate25P02 query was added to approved assertions.

Before releasing each holder, reconcile_timeout READ ONLY verified both sessions and parents retained; only intended holder remained idle-in-transaction, with no blocking PIDs of its own. After failure/rollback/recovery evidence, explicit named-pipe release yielded original holder ROLLBACK and F6_HOLDER_RELEASED_ROLLBACK_CONFIRMED/exit0. Subsequent exact reconcile verified no F test backends/prepared transactions. No persistent modification by cleanup, no waiter locks remain, and holder locks ended with its explicit rollback.

Cancellation: observe_cancel returned EXACTLY one pair, waiter2640/holder2632, sole blocker{2632}, observed_at2026-10-14 23:11:52.707612+00. cancel_exact.sql revalidated PID+backend_start/database/actor/application/state/sole blocker and observation≤5s before one pg_cancel_backend call. Marker SENT was not treated as observed cancellation. Only subsequent waiter57014/ROLLBACK/same-PID recovery proved success. Holder2632 remained alive/idle and independent observers succeeded after cancellation; no other signal call or backend termination occurred. Observation-to-cancel subsecond, within20s supervision window from waiter start. Statement timeout used a deterministic row-lock wait to exceed2s, no CPU load/system-clock manipulation.

### Exact cleanup and final state

After final holder release, reconcile_existing asserted exact fixture set and no workers/prepared transactions. Existing097_fault_teardown.sql then deleted sessions2/audiences2/identity1, COMMIT/exit0, all restricted to the recorded synthetic identity UUID. These explicit committed DELETEs retire only synthetic fixtures and are irreversible; timeout/cancel operations themselves were rolled back. No credential rows existed or were deleted.

Fresh final Docker/image checks PASS, then052enabled,check_transition4/Cenabled/Eenabled,117final all exit0/ROLLBACK. Final SID7696590721605967915/PG18.6/Goose4; four empty tables, C9+Ecleanup installed, nine indexes/three guards, expected eight minimal roles/five schema owners/source hashes/ACL, auth7 normal functions/no DML, privileged revokes denied auth/tenant/PUBLIC, maintenance cleanup-only. No F test connections/prepared transactions, hence no locks owned by closed holder/waiter backends. No residual fixtures or unknown outcomes.

### Sources and limits

SHA256:
- holder.sql62A86B68E375722614E2F5A90973C99244D9D0EE20EC9C80650E946C9F63CF42
- lock_timeout.sql3DD4B07EC787F271EEB091B5B1B699FAAF65133AD0362B0A65A3398E0E80FCCE
- statement_timeout.sql1FC225C6C650AD65D1C776710EA5C62BE9E41240E7EDD5CB0681A1B4FAAEB7E1
- cancel_waiter.sql54C7A8A88DBBC40EB7A3B9180D5D81B3ACD31E6C6ECAB7CB29AD90BA0AE42FAF
- Start-F6Holder.ps115EC27FDAB7ED0818A7499ABC34C385BECAF96286781D97A55DF899A8EE40FD1
- Release-F6Holder.ps11A5217ECCAD371E78B6B01B6CAED07DAE991B2BC8FACA80F993BDC28E136E4FE
- Test-HolderTransport.ps170E5AC2AE64CEBF5E6E1F10333987BB76CF3FF365DB26D25E55215420062218F
- reconcile_existing.sql5C158C67693EE8C4FBAA93531C55EB8B41A4B6BB3E7DD2BC3445FF4A34DFF6E2

Created transport helpers/offline test/read-only reconciliation; updated this report, F6C_TRANSCRIPT.md, docs/verification.md. Original holder/scenario SQL and C/D/E/B1/migrations/grants unchanged. No Goose, reinstall, credential change, restart/stop/delete Docker, principal/Celtas access, commit/push/deploy. No unexpected error in this recovery.

Recommend closing the approved, executed PostgreSQL verification scope F1–F6-C, with evidence limited to tested schedules/failures (not exhaustive fault proof). Backend Go integration, Argon2id/rehash crypto, tokens, CSRF/keyring/cookies/HTTP/MFA, pools/context/deadlines and application ambiguous-outcome handling remain pending. No automatic claim B2-A completely verified.
