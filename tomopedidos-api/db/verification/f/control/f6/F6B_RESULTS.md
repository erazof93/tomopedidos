# F6-B — COMPLETE / PASS (2026-10-14)

Original wrong route: control/fixtures/052*. Correct F route: /f/staged/verification/052_b2a_cleanup_metadata.sql. Original and staged files found with rg --files -g; source/copy mapping confirmed in stage-manifest, SQL unchanged.

Offline serializer Mounts0/1/2 and F/F6 checks PASS. Fresh Docker snapshot validation and real image digest PASS. Fresh SQL000 confirmed SID7696590721605967915, database tp_b2a_f_20261014_r01, PG180006. Initial052enabled, check_transition4/enabled/enabled and117final PASS/ROLLBACK: Goose4, empty tables, CDE source/owner/ACL correct, no F workers/prepared transactions. Dependencies inventoried, owners tp_owner.

Retirement: E disable→E Down→D disable→D ungrant→exact C9-function Down, each COMMIT/exit0 with state assertions and refreshed Docker/SID preflight. Roles retained, no CASCADE.

| Direction | Transition | SQL file | Goose time | State assertion |
|---|---|---|---|---|
|Down|4→3|00004_session_cleanup_index.sql|13.04ms|PASS|
|Down|3→2|00003_identity_guards_indexes.sql|8.08ms|PASS|
|Down|2→1|00002_audience_sessions.sql|13.49ms|PASS|
|Down|1→0|00001_identity_credentials.sql|12.01ms|PASS|
|Up|0→1|00001_identity_credentials.sql|27.95ms|PASS|
|Up|1→2|00002_audience_sessions.sql|19.05ms|PASS|
|Up|2→3|00003_identity_guards_indexes.sql|12.38ms|PASS|
|Up|3→4|00004_session_cleanup_index.sql|6.67ms|PASS|

At0:002_post_down and010 B1 metadata PASS/ROLLBACK; five schemas/roles/Goose retained, identity objects removed. Real migrator/SET tp_owner startup, qualified migration_meta.goose_db_version, pinned F DSN, existing independent credential. Eight F-only tool containers created and retained: f6-goose-down3/2/1/0, f6-goose-up1/2/3/4. Expected Compose orphan warnings, no removal. At4:004 metadata PASS,030 integrity/guards corpus PASS/ROLLBACK.

Restoration: C nine functions installed; D executor grants then normal auth enable; E cleanup install dormant then enable. Every script COMMIT/exit0, every post-state assertion PASS. No B1 repeat, role provisioning or credential changes. Independent real auth04126 negatives and tenant04133 negatives PASS/ROLLBACK/DockerExit0 (59 total). No SET ROLE surrogate.

Last executed SQL check_transition4/Cenabled/Eenabled PASS/ROLLBACK after E enable: four empty tables, nine indexes, three guards, C9/E1 source/owners/ACL, eight retained minimal roles and five schemas, no auth/maintenance callers/prepared transactions. Auth7 normal EXECUTE/no DML; privileged revokes denied auth/tenant/PUBLIC; cleanup maintenance-only.

NEW STOP: subsequent offline read tried staged/verification/050_b2a_cleanup_retention.sql, which does not exist. Discovery already listed050_b2a_retention_concurrency.sql. Agent route error, PathNotFound/tool exit1; stopped without retry/correction or subsequent SQL. Thus cycle and restoration completed, but F6-B NOT closed.

Pending: real maintenance login/negatives/normal call,060/061/050/051 functional retention/failure fixtures and final052/identity/Goose/empty-table checks. No F6-C. Do not repeat Down/Up or reinstall. Separate continuation authorization needed for050 path correction and pending checks after refreshed preflight.

Evidence individual commands/output/exit: F6B_TRANSCRIPT.md and docs/verification.md. While writing evidence, apply_patch rejected replacement using delete/add same target; no database action, report then written directly. Functional files untouched; no CASCADE, Docker restart/delete, principal/Celtas access, commit/push/deploy. B2-A not completely verified.



## Closing verification — PASS — 2026-10-14

This section supersedes the prior pending/stop status; previous cycle evidence remains historical. F6-B completed within its approved PostgreSQL scope.

Route corrected only in invocation: nonexistent050_b2a_cleanup_retention.sql → /f/staged/verification/050_b2a_retention_concurrency.sql. rg --files and stage-manifest source/staged mapping confirmed the correct contract; no SQL/asertion changed. Eleven pending verifier/control paths verified present, unique in F manifest and hash-exact:070,071,073,074,060,061,050,051,052,117,check_transition. Serializer roundtrips0/1/2 mounts, Check-F6 and Check-F PASS.

Fresh physical/SQL preflight PASS: exact Compose/container F, actual image ID equals approved RepoDigest sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c, exclusive internal network/volume and permitted readonly mounts, no published ports.000 confirms database tp_b2a_f_20261014_r01, SID7696590721605967915, PG180006; check_transition latestGoose4/Cenabled/Eenabled and117 confirm initially empty four tables/no F workers/prepared transactions and exact CDE sources/roles/owners/ACL.

| Pending check executed | Result |
|---|---|
|070 independent TCP maintenance login|PASS, session/current user maintenance, ROLLBACK|
|071 real maintenance negatives|12/12 PASS, ROLLBACK|
|073 real maintenance authorized cleanup|empty batch examined0/deleted0/skipped0, ROLLBACK|
|074 real auth cleanup denial|insufficient_privilege expected, PASS/ROLLBACK|
|074 real tenant cleanup denial|insufficient_privilege expected, PASS/ROLLBACK|
|060 SQL primitive paths|nine functions exercised on synthetic fixtures, PASS/ROLLBACK|
|061 fail-closed states/audience/digest/overflows/stale CAS|PASS/ROLLBACK|
|050 eight retention cases/bounds|PASS, detailed below, ROLLBACK|
|051 atomicity/clock anomaly/isolation|PASS, both transactions ROLLBACK|
|052 enabled metadata|cleanup signature/body/owner/ACL, D and E assertions PASS/ROLLBACK|
|Final check_transition4/enabled/enabled +117|PASS/ROLLBACK, empty/clean|

TCP tests used existing independent F credentials through private helpers/stdin, no secret printing and no SET ROLE substitute. Functional050/051/060/061 use bootstrap to create synthetic fixtures and SET LOCAL ROLE for behavior inside rollback transactions, distinct from the real login/negative evidence. PUBLIC cleanup denial checked via exact ACL/effective metadata assertions; PUBLIC is not a login actor. Only normal auth7 EXECUTE allowed; privileged revokes remain denied auth/tenant/PUBLIC; callers have no direct DML; maintenance only intended cleanup, no executor membership/DDL/other functions.

### Eight retention fixtures (transient effects before rollback)

| Case | Synthetic situation | Outcome |
|---|---|---|
|1|natural expiry older than30d|deleted|
|2|recent natural expiry|retained|
|3|active/unexpired|retained|
|4|epoch-only invalid, natural deadlines future|retained|
|5|epoch-only invalid, natural terminality older than30d|deleted|
|6|old natural expiry detected late, expired_at recent|deleted; late detection does not extend retention|
|7|revocation older than30d, before natural terminality|deleted|
|8|creation older than30d, natural terminality still within30d|retained; creation not anchor|

cleanup(100) examined4/deleted4/skipped0, expected survivors2/3/4/8; parent auth_epoch remains1, two audience rows remain. ROLLBACK TO savepoint restored8 sessions. Separate savepoint cleanup(1) examined1/deleted1; NULL/0/-1/101 rejected22023, repeated cleanup in same transaction rejected25000. Exact30d arithmetic/NULL semantics and1-microsecond-over-boundary checks PASS. Outer ROLLBACK removes all fixture rows. No claim of rerunning the prior full100-row fixture or concurrency/F6-C.

051: auth/tenant unauthorized calls rejected; second synthetic session's future terminal timestamp causes22008 after provisional deletion of first, atomic assertion finds both sessions restored; parents retained until outer ROLLBACK. Separate REPEATABLE READ transaction rejects25000 before deletion, ROLLBACK. No system-clock manipulation.061 confirms fail-closed conditions and overflow/stale-CAS behavior; SQL harness does not prove HTTP/Go cryptography or application response handling.

### Final state and limits

Fresh final052,check_transition and117 all exit0/ROLLBACK: SID7696590721605967915, PG18.6, effective Goose4, four tables empty, nine indexes/three guards, C9 plus E cleanup installed, expected eight retained roles/five schema owners and exact source/ACL. No residual F test connections/prepared transactions. Fixture DELETE/UPDATE/INSERT only transactional; none committed in this closing turn. Credentials/identities/epochs outside fixture never changed.

Earlier cycle4Down+4Up remains verified and B1 metadata passed at0; not repeated now. No new SQL/permission/identity failures or unresolved blockers. No CDE reinstall/grant changes, B1/migration/function modifications, Docker restart/delete, principal/Celtas access, commit/push/deploy. Updated only F6B_RESULTS.md/F6B_TRANSCRIPT.md/docs/verification.md for closing evidence.

F6-B COMPLETE for approved cycle+postcycle verification. F6-C timeouts/cancellation and backend Go contracts remain pending; B2-A NOT completely verified.
Comprobación documental posterior: git diff --check devolvió exit1 por una línea vacía al final de docs/verification.md (línea3218), además de avisos LF/CRLF. No fue un fallo SQL ni altera los resultados de F6-B; no se repitieron pruebas ni se hicieron correcciones funcionales. Se conserva este resultado como observación editorial.
