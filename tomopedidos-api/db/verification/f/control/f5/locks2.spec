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
 INSERT INTO identity.identities(id,email_original,status,email_verified_at,created_at)
 VALUES('e4000000-0000-4000-8000-000000000001','lockorder@example.invalid','active',clock_timestamp()-interval '60 days',clock_timestamp()-interval '60 days');
 INSERT INTO identity.audience_revocations(identity_id,audience)
 SELECT 'e4000000-0000-4000-8000-000000000001'::uuid,a FROM unnest(ARRAY['admin','platform']) a;
 WITH t AS(SELECT clock_timestamp() n)
 INSERT INTO identity.sessions(session_id,identity_id,audience,token_hash,identity_epoch,audience_epoch,authentication_level,csrf_key_id,csrf_salt,created_at,last_activity_at,idle_expires_at,absolute_expires_at)
 SELECT 'e4100000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000001','admin',sha256(convert_to('F5 lock order','UTF8')),0,0,'password','f-lock',decode(repeat('00',32),'hex'),n-interval '41 days',n-interval '41 days',n-interval '40 days 12 hours',n-interval '34 days' FROM t;
}
teardown
{
  DELETE FROM identity.sessions WHERE identity_id='e2000000-0000-4000-8000-000000000001';
  DELETE FROM identity.audience_revocations WHERE identity_id='e2000000-0000-4000-8000-000000000001';
  DELETE FROM identity.identities WHERE id='e2000000-0000-4000-8000-000000000001';
 DELETE FROM identity.sessions WHERE identity_id='e4000000-0000-4000-8000-000000000001';
 DELETE FROM identity.audience_revocations WHERE identity_id='e4000000-0000-4000-8000-000000000001';
 DELETE FROM identity.identities WHERE id='e4000000-0000-4000-8000-000000000001';
}
session "cleanup1"
step "c_begin" { BEGIN; SET LOCAL ROLE tomopedidos_session_maintenance; }
step "c_run" { DO $$ DECLARE r record; BEGIN SELECT * INTO STRICT r FROM identity.cleanup_sessions(100); IF r.examined<>2 OR r.deleted<>2 OR r.skipped<>0 THEN RAISE EXCEPTION 'Two-parent batch failed'; END IF; END $$; }
step "c_commit" { COMMIT; }
step "c_rollback" { ROLLBACK; }
session "cleanup2"
step "d_begin" { BEGIN; SET LOCAL ROLE tomopedidos_session_maintenance; }
step "d_run" { SELECT examined,deleted,skipped FROM identity.cleanup_sessions(100); }
step "d_commit" { COMMIT; }
session "observer"
step "verify" { DO $$ BEGIN IF (SELECT count(*) FROM identity.sessions)<>1 OR (SELECT count(*) FROM identity.identities)<>2 OR (SELECT count(*) FROM identity.audience_revocations)<>4 THEN RAISE EXCEPTION 'Multi-parent final state'; END IF; END $$; }
permutation "c_begin" "c_run" "d_begin" "d_run" "c_commit" "d_commit" "verify"
permutation "c_begin" "c_run" "d_begin" "d_run" "c_rollback" "d_commit" "verify"
