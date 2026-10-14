# F5-B executed results — 2026-10-14

23 distinct permutations executed and reviewed against MATRIX. All23 PASS after
successful final SQL state/ownership/ACL reconciliation. One native invocation per
case; source/spec hashes unchanged.18 captures show a wait followed by completion;
5 have no required wait. No deadlock, unexpected SQL error or timeout observed.

Times below measure the host harness invocation including Docker/transport overhead,
not per-operation PostgreSQL latency. Total native invocation time: 18.051s.

| Execution order | Spec / case | Observed wait | Observable result / asserted state | Seconds | Outcome |
|---|---|---|---|---|---|
| 1 | locks2.spec / 1 | d_run | examined2/deleted0/skipped2 | 0.772 | PASS |
| 2 | locks2.spec / 2 | d_run | examined2/deleted2/skipped0; rollback-first | 0.754 | PASS |
| 3 | auth9.spec / 1 | b_logout | valid then revoked; terminal persisted | 0.780 | PASS |
| 4 | auth9.spec / 2 | a_invalid | revoked then invalid; null metadata | 0.750 | PASS |
| 5 | auth9.spec / 5 | b_renew | two activity_recorded; deadlines capped | 0.763 | PASS |
| 6 | auth9.spec / 6 | b_invalid | revoked then invalid; no revival | 0.772 | PASS |
| 7 | auth9.spec / 3 | p_global | valid then global_revoked; epoch1 snapshot0 | 0.779 | PASS |
| 8 | auth9.spec / 4 | a_invalid | global_revoked then invalid; snapshot0 | 0.778 | PASS |
| 9 | auth9.spec / 7 | a_valid | rehashed revision2; valid epoch0 | 0.736 | PASS |
| 10 | auth9.spec / 8 | b_rehash | valid then rehashed revision2 epoch0 | 0.754 | PASS |
| 11 | auth9.spec / 9 | none | synthetic future activity: clock_anomaly null metadata; terminal unchanged | 0.791 | PASS |
| 12 | cleanup12.spec / 11 | d_run | first1/1/0 second1/0/1; no double delete | 0.818 | PASS |
| 13 | cleanup12.spec / 1 | a_validate_old | cleanup1/1/0 then validation invalid; old absent live retained | 0.838 | PASS |
| 14 | cleanup12.spec / 2 | c_run | validation expired then cleanup1/1/0; natural retention preserved | 0.797 | PASS |
| 15 | cleanup12.spec / 3 | c_run | mark_expired expired then cleanup1/1/0 | 0.850 | PASS |
| 16 | cleanup12.spec / 4 | none; compatible parents/different sessions | activity_recorded cleanup1/1/0 live retained | 0.801 | PASS |
| 17 | cleanup12.spec / 5 | none; compatible parents/different sessions | cleanup1/1/0 activity_recorded live retained | 0.788 | PASS |
| 18 | cleanup12.spec / 6 | none; compatible parents/different sessions | revoked cleanup1/1/0 recent terminal retained | 0.826 | PASS |
| 19 | cleanup12.spec / 7 | p_global | cleanup1/1/0 global_revoked live epoch-invalid row retained | 0.785 | PASS |
| 20 | cleanup12.spec / 8 | c_run | global_revoked cleanup1/1/0 live retained despite epoch | 0.769 | PASS |
| 21 | cleanup12.spec / 9 | p_audience | cleanup1/1/0 audience_revoked; live retained | 0.796 | PASS |
| 22 | cleanup12.spec / 10 | c_run | audience_revoked cleanup1/1/0; live retained | 0.762 | PASS |
| 23 | cleanup12.spec / 12 | none | cleanup1/1/0 provisional; rollback restored2 | 0.792 | PASS |

SQL final checks: exact cluster SID7696590721605967915, PostgreSQL180006, Goose4;
C/D/E enabled/source/owner/ACL assertions PASS; all four tables empty; no native
worker connections or prepared transactions. Read-only checks ended in ROLLBACK.
Native setup/teardown used COMMIT on exact synthetic fixtures. Native rollback
cases restored provisional deletes before committed fixture teardown. No claim
that all23 cases were globally rolled back; their synthetic transactions committed.

Capture files under ignored captures/ were reviewed individually, including SQL
assertions and waits; CAPTURED_NOT_APPROVED alone was never counted as PASS. The
unused-step warnings are expected when selecting one permutation from a larger spec.
No generated golden file was accepted automatically, no test expectations changed.

Limits: bounded SQL schedules, not proof of deadlock freedom for arbitrary traffic.
Native workers are independently connected bootstrap sessions using SET LOCAL ROLE
as synthetic actors; real actor authentication was separately checked in F4. Lexical
PHC is not Argon2id proof. The future-timestamp case did not change the system clock.
No dedicated record_activity-after-committed-revoke permutation is present in the
approved23; invalid-after-revoke and no revival were asserted in their tested paths,
but that additional renewal path must not be claimed as independently tested here.
Fault injection, disconnects, timeouts/cancellation, ambiguous commit, backend Go
and system-clock changes were not exercised. F5-C requires separate authorization.
