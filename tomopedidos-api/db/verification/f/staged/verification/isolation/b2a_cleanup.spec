# PREPARED ONLY. PostgreSQL isolationtester format; not run by any app/Goose script.
# Setup/teardown COMMIT synthetic fixtures: authorize a completely disposable DB.
# Requires roles and A-D/E enabled. SET ROLE here tests concurrency, not real login.
setup
{
  DO $f_target$ BEGIN IF current_database()<>'tp_b2a_f_20261014_r01' OR current_setting('cluster_name')<>'tp-b2a-f-20261014-r01' OR current_setting('server_version_num')::integer<>180006 OR session_user<>'tomopedidos_bootstrap' OR (SELECT system_identifier::text FROM pg_control_system())<>'__F_SYSTEM_ID_PENDING__' THEN RAISE EXCEPTION 'F isolation exact target failed'; END IF; END; $f_target$;

  SET TIME ZONE 'UTC';
  DO $$ BEGIN
    IF current_database() <> 'tp_b2a_f_20261014_r01' OR session_user <> 'tomopedidos_bootstrap'
       OR NOT (SELECT rolsuper FROM pg_roles WHERE rolname = session_user)
       OR EXISTS (SELECT 1 FROM identity.sessions)
       OR EXISTS (SELECT 1 FROM identity.identities WHERE id = 'e2000000-0000-4000-8000-000000000001') THEN
      RAISE EXCEPTION 'Isolation fixture requires authorized empty disposable database';
    END IF;
  END $$;
  INSERT INTO identity.identities (id,email_original,status,email_verified_at,created_at)
  VALUES ('e2000000-0000-4000-8000-000000000001','isolation-e@example.invalid','active',
          clock_timestamp()-interval '60 days',clock_timestamp()-interval '60 days');
  INSERT INTO identity.audience_revocations (identity_id,audience)
  SELECT 'e2000000-0000-4000-8000-000000000001'::uuid,a FROM unnest(ARRAY['admin','platform']) AS a;
  WITH t AS (SELECT clock_timestamp() AS now)
  INSERT INTO identity.sessions (session_id,identity_id,audience,token_hash,identity_epoch,audience_epoch,
      authentication_level,csrf_key_id,csrf_salt,created_at,last_activity_at,idle_expires_at,absolute_expires_at)
  SELECT ('e2100000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
      'e2000000-0000-4000-8000-000000000001'::uuid,'admin',sha256(convert_to('E isolation '||n,'UTF8')),
      0,0,'password','e-fixture',decode(repeat('00',32),'hex'),
      now-CASE WHEN n=1 THEN interval '41 days' ELSE interval '0 seconds' END,
      now-CASE WHEN n=1 THEN interval '41 days' ELSE interval '0 seconds' END,
      now-CASE WHEN n=1 THEN interval '41 days' ELSE interval '0 seconds' END+interval '12 hours',
      now-CASE WHEN n=1 THEN interval '41 days' ELSE interval '0 seconds' END+interval '7 days'
  FROM t CROSS JOIN generate_series(1,2) AS n;
}
teardown
{
  DELETE FROM identity.sessions WHERE identity_id='e2000000-0000-4000-8000-000000000001';
  DELETE FROM identity.audience_revocations WHERE identity_id='e2000000-0000-4000-8000-000000000001';
  DELETE FROM identity.identities WHERE id='e2000000-0000-4000-8000-000000000001';
}
session "cleanup"
step "c_begin" { BEGIN; SET LOCAL ROLE tomopedidos_session_maintenance; }
step "c_run" { SELECT examined,deleted,skipped FROM identity.cleanup_sessions(100); }
step "c_commit" { COMMIT; }
step "c_rollback" { ROLLBACK; }
step "verify" {
  DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM identity.sessions WHERE session_id='e2100000-0000-4000-8000-000000000001')
       OR NOT EXISTS (SELECT 1 FROM identity.sessions WHERE session_id='e2100000-0000-4000-8000-000000000002')
       OR (SELECT count(*) FROM identity.audience_revocations WHERE identity_id='e2000000-0000-4000-8000-000000000001')<>2 THEN
      RAISE EXCEPTION 'Cleanup survivor/parent invariant failed';
    END IF;
  END $$;
}
step "verify_rollback" {
  DO $$ BEGIN
    IF (SELECT count(*) FROM identity.sessions WHERE identity_id='e2000000-0000-4000-8000-000000000001')<>2 THEN
      RAISE EXCEPTION 'Cleanup rollback invariant failed';
    END IF;
  END $$;
}
session "auth"
step "a_begin" { BEGIN; SET LOCAL ROLE tomopedidos_auth_runtime; }
step "a_validate_old" { SELECT result FROM identity.validate_session(sha256(convert_to('E isolation 1','UTF8')),'admin'); }
step "a_expire_old" { SELECT result FROM identity.mark_expired(sha256(convert_to('E isolation 1','UTF8')),'admin'); }
step "a_renew" { SELECT result FROM identity.record_activity(sha256(convert_to('E isolation 2','UTF8')),'admin'); }
step "a_logout" { SELECT result FROM identity.revoke_session(sha256(convert_to('E isolation 2','UTF8')),'admin'); }
step "a_commit" { COMMIT; }
session "privileged_fixture"
step "p_begin" { BEGIN; SET LOCAL ROLE tomopedidos_auth_revoke_executor; }
step "p_global" { SELECT result FROM identity.revoke_global(sha256(convert_to('E isolation 2','UTF8')),'admin'); }
step "p_audience" { SELECT result FROM identity.revoke_audience(sha256(convert_to('E isolation 2','UTF8')),'admin'); }
step "p_commit" { COMMIT; }
session "cleanup2"
step "d_begin" { BEGIN; SET LOCAL ROLE tomopedidos_session_maintenance; }
step "d_run" { SELECT examined,deleted,skipped FROM identity.cleanup_sessions(100); }
step "d_commit" { COMMIT; }

# Cleanup holds old session; validation waits and sees disappearance (invalid).
permutation "c_begin" "c_run" "a_begin" "a_validate_old" "c_commit" "a_commit" "verify"
# Validation/expiration detection first; late expired_at must not extend retention.
permutation "a_begin" "a_validate_old" "c_begin" "c_run" "a_commit" "c_commit" "verify"
permutation "a_begin" "a_expire_old" "c_begin" "c_run" "a_commit" "c_commit" "verify"
# Legitimate renewal and logout of live session must never make it cleanup-eligible.
permutation "a_begin" "a_renew" "c_begin" "c_run" "a_commit" "c_commit" "verify"
permutation "c_begin" "c_run" "a_begin" "a_renew" "a_commit" "c_commit" "verify"
permutation "a_begin" "a_logout" "c_begin" "c_run" "a_commit" "c_commit" "verify"
# Global/audience exclusive locks in both directions. Epoch-only live is retained.
permutation "c_begin" "c_run" "p_begin" "p_global" "c_commit" "p_commit" "verify"
permutation "p_begin" "p_global" "c_begin" "c_run" "p_commit" "c_commit" "verify"
permutation "c_begin" "c_run" "p_begin" "p_audience" "c_commit" "p_commit" "verify"
permutation "p_begin" "p_audience" "c_begin" "c_run" "p_commit" "c_commit" "verify"
# Competing cleanups do not double-delete; rollback releases and restores rows.
permutation "c_begin" "c_run" "d_begin" "d_run" "c_commit" "d_commit" "verify"
permutation "c_begin" "c_run" "c_rollback" "verify_rollback"
