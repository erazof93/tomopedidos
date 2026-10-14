setup
{
  DO $f_target$ BEGIN IF current_database()<>'tp_b2a_f_20261014_r01' OR current_setting('cluster_name')<>'tp-b2a-f-20261014-r01' OR current_setting('server_version_num')::integer<>180006 OR session_user<>'tomopedidos_bootstrap' OR (SELECT system_identifier::text FROM pg_control_system())<>'7696590721605967915' THEN RAISE EXCEPTION 'F isolation exact target failed'; END IF; END; $f_target$;

  SET TIME ZONE 'UTC';
  DO $f5_empty$ BEGIN
    IF EXISTS(SELECT 1 FROM identity.identities) OR EXISTS(SELECT 1 FROM identity.identity_credentials)
       OR EXISTS(SELECT 1 FROM identity.audience_revocations) OR EXISTS(SELECT 1 FROM identity.sessions)
    THEN RAISE EXCEPTION 'F5 requires all four fixture tables empty'; END IF;
  END; $f5_empty$;
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
  UPDATE identity.identities SET credential_revision=1 WHERE id='e2000000-0000-4000-8000-000000000001';
  INSERT INTO identity.identity_credentials VALUES ('e2000000-0000-4000-8000-000000000001', '$argon2id$v=19$m=19456,t=2,p=1$AAAAAAAAAAAAAAAAAAAAAA$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',clock_timestamp());
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
  DELETE FROM identity.identity_credentials WHERE identity_id='e2000000-0000-4000-8000-000000000001';
  DELETE FROM identity.audience_revocations WHERE identity_id='e2000000-0000-4000-8000-000000000001';
  DELETE FROM identity.identities WHERE id='e2000000-0000-4000-8000-000000000001';
}
session "auth1"
step "a_begin" { BEGIN; SET LOCAL ROLE tomopedidos_auth_runtime; }
step "a_valid" { DO $$ DECLARE r record; BEGIN SELECT * INTO STRICT r FROM identity.validate_session(sha256(convert_to('E isolation 2','UTF8')),'admin'); IF r.result<>'valid' THEN RAISE EXCEPTION 'Expected valid'; END IF; END $$; }
step "a_invalid" { DO $$ DECLARE r record; BEGIN SELECT * INTO STRICT r FROM identity.validate_session(sha256(convert_to('E isolation 2','UTF8')),'admin'); IF r.result<>'invalid' OR r.session_id IS NOT NULL THEN RAISE EXCEPTION 'Expected invalid without metadata'; END IF; END $$; }
step "a_renew" { DO $$ DECLARE r record; BEGIN SELECT * INTO STRICT r FROM identity.record_activity(sha256(convert_to('E isolation 2','UTF8')),'admin'); IF r.result<>'activity_recorded' THEN RAISE EXCEPTION 'Expected first renewal'; END IF; END $$; }
step "a_logout" { DO $$ DECLARE r record; BEGIN SELECT * INTO STRICT r FROM identity.revoke_session(sha256(convert_to('E isolation 2','UTF8')),'admin'); IF r.result<>'revoked' THEN RAISE EXCEPTION 'Expected first logout'; END IF; END $$; }
step "a_clock" { DO $$ DECLARE r record; BEGIN SELECT * INTO STRICT r FROM identity.validate_session(sha256(convert_to('E isolation 2','UTF8')),'admin'); IF r.result<>'clock_anomaly' OR r.session_id IS NOT NULL THEN RAISE EXCEPTION 'Clock did not fail closed'; END IF; END $$; }
step "a_commit" { COMMIT; }
session "auth2"
step "b_begin" { BEGIN; SET LOCAL ROLE tomopedidos_auth_runtime; }
step "b_logout" { DO $$ DECLARE r record; BEGIN SELECT * INTO STRICT r FROM identity.revoke_session(sha256(convert_to('E isolation 2','UTF8')),'admin'); IF r.result<>'revoked' THEN RAISE EXCEPTION 'Expected logout'; END IF; END $$; }
step "b_invalid" { DO $$ DECLARE r record; BEGIN SELECT * INTO STRICT r FROM identity.revoke_session(sha256(convert_to('E isolation 2','UTF8')),'admin'); IF r.result<>'invalid' OR r.session_id IS NOT NULL THEN RAISE EXCEPTION 'Second logout revived session'; END IF; END $$; }
step "b_renew" { DO $$ DECLARE r record; BEGIN SELECT * INTO STRICT r FROM identity.record_activity(sha256(convert_to('E isolation 2','UTF8')),'admin'); IF r.result<>'activity_recorded' THEN RAISE EXCEPTION 'Expected second renewal'; END IF; END $$; }
step "b_rehash" { DO $$ DECLARE r record; BEGIN SELECT * INTO STRICT r FROM identity.rehash_conditional('e2000000-0000-4000-8000-000000000001',1,'$argon2id$v=19$m=19456,t=2,p=1$AAAAAAAAAAAAAAAAAAAAAA$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA','$argon2id$v=19$m=19456,t=2,p=1$BBBBBBBBBBBBBBBBBBBBBB$BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB'); IF r.result<>'rehashed' OR r.credential_revision<>2 THEN RAISE EXCEPTION 'Expected rehash'; END IF; END $$; }
step "b_commit" { COMMIT; }
session "privileged_admin_fixture"
step "p_begin" { BEGIN; SET LOCAL ROLE tomopedidos_auth_revoke_executor; }
step "p_global" { DO $$ DECLARE r record; BEGIN SELECT * INTO STRICT r FROM identity.revoke_global(sha256(convert_to('E isolation 2','UTF8')),'admin'); IF r.result<>'global_revoked' OR r.current_identity_epoch<>1 THEN RAISE EXCEPTION 'Expected epoch revocation'; END IF; END $$; }
step "p_commit" { COMMIT; }
step "future_fixture" { WITH t AS (SELECT clock_timestamp() AS n) UPDATE identity.sessions SET last_activity_at=t.n+interval '1 day',idle_expires_at=t.n+interval '1 day 12 hours' FROM t WHERE session_id='e2100000-0000-4000-8000-000000000002'; }
session "observer"
step "assert_logout" { DO $$ BEGIN IF (SELECT revoked_at IS NULL FROM identity.sessions WHERE session_id='e2100000-0000-4000-8000-000000000002') OR (SELECT count(*) FROM identity.sessions)<>2 THEN RAISE EXCEPTION 'Logout final state'; END IF; END $$; }
step "assert_renew" { DO $$ BEGIN IF NOT EXISTS(SELECT 1 FROM identity.sessions WHERE session_id='e2100000-0000-4000-8000-000000000002' AND last_activity_at>created_at AND idle_expires_at<=last_activity_at+interval '12 hours' AND idle_expires_at<=absolute_expires_at AND revoked_at IS NULL) THEN RAISE EXCEPTION 'Renewal final state'; END IF; END $$; }
step "assert_epoch" { DO $$ BEGIN IF (SELECT auth_epoch FROM identity.identities WHERE id='e2000000-0000-4000-8000-000000000001')<>1 OR (SELECT identity_epoch FROM identity.sessions WHERE session_id='e2100000-0000-4000-8000-000000000002')<>0 THEN RAISE EXCEPTION 'Epoch changed snapshot'; END IF; END $$; }
step "assert_rehash" { DO $$ BEGIN IF (SELECT credential_revision FROM identity.identities WHERE id='e2000000-0000-4000-8000-000000000001')<>2 OR (SELECT auth_epoch FROM identity.identities WHERE id='e2000000-0000-4000-8000-000000000001')<>0 THEN RAISE EXCEPTION 'Rehash final state'; END IF; END $$; }
step "assert_clock" { DO $$ BEGIN IF (SELECT expired_at IS NOT NULL OR revoked_at IS NOT NULL FROM identity.sessions WHERE session_id='e2100000-0000-4000-8000-000000000002') THEN RAISE EXCEPTION 'Clock anomaly mutated terminal state'; END IF; END $$; }
permutation "a_begin" "a_valid" "b_begin" "b_logout" "a_commit" "b_commit" "assert_logout"
permutation "b_begin" "b_logout" "a_begin" "a_invalid" "b_commit" "a_commit" "assert_logout"
permutation "a_begin" "a_valid" "p_begin" "p_global" "a_commit" "p_commit" "assert_epoch"
permutation "p_begin" "p_global" "a_begin" "a_invalid" "p_commit" "a_commit" "assert_epoch"
permutation "a_begin" "a_renew" "b_begin" "b_renew" "a_commit" "b_commit" "assert_renew"
permutation "a_begin" "a_logout" "b_begin" "b_invalid" "a_commit" "b_commit" "assert_logout"
permutation "b_begin" "b_rehash" "a_begin" "a_valid" "b_commit" "a_commit" "assert_rehash"
permutation "a_begin" "a_valid" "b_begin" "b_rehash" "a_commit" "b_commit" "assert_rehash"
permutation "future_fixture" "a_begin" "a_clock" "a_commit" "assert_clock"
