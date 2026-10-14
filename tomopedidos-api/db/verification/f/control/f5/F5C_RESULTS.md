# F5-C actual results — 2026-10-14

Executed exclusively in F: SID7696590721605967915, PostgreSQL18.6, Goose4.
All tested outcomes were reconciled, no unresolved transaction/data state remains.

| Scenario | Initial client evidence | Independent final evidence | Result |
|---|---|---|---|
|Before COMMIT disconnect|Client lost connection (psql2), no success marker; proxy did not forward COMMIT|Fresh096: two sessions retained, parents intact, no test backend|Rollback confirmed; PASS|
|COMMIT ACK withheld|Client lost connection (psql2); UNKNOWN, no success marker; proxy observed serverCommandComplete(COMMIT)|Fresh096: zero sessions, parents intact, no test backend|Committed effect confirmed after reconciliation; PASS|
|SQL invalid batch|Real maintenance got22023/psql3, COMMIT/success marker not reached|Fresh007: four tables empty|Fail-closed; PASS|
|Clock atomicity|051 caught22008 after provisional work in a synthetic batch|Two rows restored inside fixture; ROLLBACK, fresh007 empty|No partial DELETE; PASS|
|Unsupported isolation|051 caught25000 in REPEATABLE READ|ROLLBACK, fresh007 empty|Fail-closed; PASS|
|Renew after confirmed logout|111 real auth received COMMIT and confirmation marker; a new real auth connection112 gotinvalid/null metadata|113: revoked mark remains; original activity/deadlines, epochs0, credentialrevision1|No renewal/revival; PASS|
|Renew after confirmed global epoch revoke|115 administrator-only synthetic global revoke COMMIT confirmed; new real auth112 gotinvalid/null metadata|116: Identityepoch1, session snapshot0, audienceepoch0; deadlines unchanged, no invented terminal marks|No epoch-invalid renewal; PASS|

Both fault clients withhold pending cleanup counts (`gset`) until COMMIT. Neither
printed CLIENT_COMMIT_CONFIRMED or issued tokens. Proxy exit0 is not client success;
its explicit outcome is unknown. We did not infer commit from sending the instruction.
Server evidence plus fresh independent row/parent reconciliation established the
outcome. A failure at another point would remain indeterminate and block recovery;
that branch was not claimed as empirically executed.

The proxy accepted one real maintenance connection on F loopback5433 and forwarded
only to F loopback5432. No host port or external DSN. Existing Go proxy/source/bin
hash unchanged. A noninteractive105 client replaces095's operator prompt, with
the same transaction and expected synthetic pending2/2/0 assertion. No auto retry.

090 seed and097 teardown committed exact f3 fixture IDs. After rollback scenario,
teardown deleted2 sessions/2 audiences/1 identity; after ACK-loss committed cleanup,
teardown deleted0 sessions/2 audiences/1 identity. Only synthetic data removed.
110 seeds and114 teardown committed exact f6 IDs for logout/global tests (one
session, one credential, two audiences, one identity). These commits are persistent
administrative test effects, not globally rolled-back fixtures. All removed by ID.

Final117: four tables empty; no test connections/prepared transactions; Goose4;
identity unchanged. Final052: C/D/E body/owner/ACL/roles intact. Docker running
with unchanged StartedAt2026-10-14T18:22:50.924351475Z and no published ports.
No PostgreSQL stop/restart, systemclock change, functional changes or Docker deletion.

Scope limits: SQL harness only, not backend Go success/token/retry behavior. Argon2id,
CSRF/keyring, MFA and auth service/pool/HTTP semantics remain separate. Prepared lock
timeout/statement timeout/cancel fixtures and GooseDown/re-Up were not authorized
or executed in this phase. Real systemclock changes are not tested. Recommend
closing the tested F5-C scope; do not declare all B2-A/F acceptance complete while
those applicable verification items remain pending.
