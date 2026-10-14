-- F only. Synthetic lexical PHC/token digests do NOT prove passwords, MFA or CSRF.
-- SAVEPOINT per locking operation, restored before next: no shared->exclusive upgrade.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
BEGIN;
SET LOCAL search_path TO pg_catalog;
SET LOCAL TIME ZONE 'UTC';
DO $empty$ BEGIN
    IF session_user <> 'tomopedidos_bootstrap' OR current_user <> session_user
        OR EXISTS (SELECT 1 FROM identity.identities) OR EXISTS (SELECT 1 FROM identity.sessions) THEN
        RAISE EXCEPTION 'F primitives require empty disposable fixture tables and bootstrap';
    END IF;
END; $empty$;
INSERT INTO identity.identities(id,email_original,status,email_verified_at,credential_revision,created_at)
VALUES('f2000000-0000-4000-8000-000000000001','primitives-f@example.invalid','active',
    clock_timestamp()-interval '10 days',1,clock_timestamp()-interval '10 days');
INSERT INTO identity.audience_revocations(identity_id,audience)
SELECT 'f2000000-0000-4000-8000-000000000001'::uuid,a FROM unnest(ARRAY['admin','platform']) AS a;
INSERT INTO identity.identity_credentials VALUES('f2000000-0000-4000-8000-000000000001',
 '$argon2id$v=19$m=19456,t=2,p=1$AAAAAAAAAAAAAAAAAAAAAA$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',clock_timestamp());
WITH t AS (SELECT clock_timestamp() AS n)
INSERT INTO identity.sessions(session_id,identity_id,audience,token_hash,identity_epoch,audience_epoch,
    authentication_level,csrf_key_id,csrf_salt,created_at,last_activity_at,idle_expires_at,absolute_expires_at)
SELECT ('f2100000-0000-4000-8000-'||lpad(k::text,12,'0'))::uuid,
    'f2000000-0000-4000-8000-000000000001','admin',sha256(convert_to('F primitive '||k,'UTF8')),
    0,0,'password','f-test',decode(repeat('00',32),'hex'),
    n-CASE k WHEN 1 THEN interval '1 hour' ELSE interval '2 days' END,
    n-CASE k WHEN 1 THEN interval '1 hour' ELSE interval '2 days' END,
    n-CASE k WHEN 1 THEN interval '1 hour' ELSE interval '2 days' END+interval '43200 seconds',
    n-CASE k WHEN 1 THEN interval '1 hour' ELSE interval '2 days' END+interval '604800 seconds'
FROM t CROSS JOIN generate_series(1,2) AS k;

-- Negative cases use independent savepoints; admin mutations are fixtures only.
SAVEPOINT f_disabled;
UPDATE identity.identities SET status='disabled',auth_epoch=1;
SET LOCAL ROLE tomopedidos_auth_runtime;
DO $disabled$ DECLARE v record; BEGIN
 SELECT * INTO STRICT v FROM identity.validate_session(sha256(convert_to('F primitive 1','UTF8')),'admin');
 IF v.result<>'invalid' OR v.identity_id IS NOT NULL THEN RAISE EXCEPTION 'Disabled identity accepted'; END IF;
END; $disabled$;
RESET ROLE;
ROLLBACK TO f_disabled;

SAVEPOINT f_missing;
DELETE FROM identity.audience_revocations WHERE audience='platform';
SET LOCAL ROLE tomopedidos_auth_runtime;
DO $missing$ DECLARE v record; BEGIN
 SELECT * INTO STRICT v FROM identity.validate_session(sha256(convert_to('F primitive 1','UTF8')),'admin');
 IF v.result<>'invalid' THEN RAISE EXCEPTION 'Missing audience accepted'; END IF;
END; $missing$;
RESET ROLE;
ROLLBACK TO f_missing;

SAVEPOINT f_revoked;
UPDATE identity.sessions SET revoked_at=clock_timestamp() WHERE session_id='f2100000-0000-4000-8000-000000000001';
SET LOCAL ROLE tomopedidos_auth_runtime;
DO $revoked$ DECLARE v record; BEGIN
 SELECT * INTO STRICT v FROM identity.record_activity(sha256(convert_to('F primitive 1','UTF8')),'admin');
 IF v.result<>'invalid' OR v.session_id IS NOT NULL THEN RAISE EXCEPTION 'Revoked session revived'; END IF;
END; $revoked$;
RESET ROLE;
ROLLBACK TO f_revoked;

SAVEPOINT f_token;
SET LOCAL ROLE tomopedidos_auth_runtime;
DO $token$ DECLARE v record; BEGIN
 SELECT * INTO STRICT v FROM identity.validate_session(decode(repeat('00',31),'hex'),'admin');
 IF v.result<>'invalid' OR v.session_id IS NOT NULL THEN RAISE EXCEPTION 'Malformed digest accepted'; END IF;
END; $token$;
RESET ROLE;
ROLLBACK TO f_token;

SAVEPOINT f_wrong_audience;
SET LOCAL ROLE tomopedidos_auth_runtime;
DO $wrong_audience$ DECLARE v record; BEGIN
 SELECT * INTO STRICT v FROM identity.validate_session(sha256(convert_to('F primitive 1','UTF8')),'platform');
 IF v.result<>'invalid' THEN RAISE EXCEPTION 'Cross audience token accepted'; END IF;
END; $wrong_audience$;
RESET ROLE;
ROLLBACK TO f_wrong_audience;

SAVEPOINT f_global_overflow;
UPDATE identity.identities SET auth_epoch=9223372036854775807;
INSERT INTO identity.sessions SELECT 'f2100000-0000-4000-8000-000000000004'::uuid,identity_id,audience,
 sha256(convert_to('F global overflow','UTF8')),9223372036854775807,audience_epoch,authentication_level,
 csrf_key_id,csrf_generation,csrf_salt,created_at,last_activity_at,idle_expires_at,absolute_expires_at,revoked_at,expired_at
 FROM identity.sessions WHERE session_id='f2100000-0000-4000-8000-000000000001';
SET LOCAL ROLE tomopedidos_auth_revoke_executor;
DO $overflow$ BEGIN BEGIN
 PERFORM * FROM identity.revoke_global(sha256(convert_to('F global overflow','UTF8')),'admin');
 RAISE EXCEPTION 'Global overflow accepted';
 EXCEPTION WHEN numeric_value_out_of_range THEN NULL; END;
END; $overflow$;
RESET ROLE;
ROLLBACK TO f_global_overflow;

SAVEPOINT f_audience_overflow;
UPDATE identity.audience_revocations SET auth_epoch=9223372036854775807 WHERE audience='admin';
INSERT INTO identity.sessions SELECT 'f2100000-0000-4000-8000-000000000004'::uuid,identity_id,audience,
 sha256(convert_to('F audience overflow','UTF8')),identity_epoch,9223372036854775807,authentication_level,
 csrf_key_id,csrf_generation,csrf_salt,created_at,last_activity_at,idle_expires_at,absolute_expires_at,revoked_at,expired_at
 FROM identity.sessions WHERE session_id='f2100000-0000-4000-8000-000000000001';
SET LOCAL ROLE tomopedidos_auth_revoke_executor;
DO $overflow$ BEGIN BEGIN
 PERFORM * FROM identity.revoke_audience(sha256(convert_to('F audience overflow','UTF8')),'admin');
 RAISE EXCEPTION 'Audience overflow accepted';
 EXCEPTION WHEN numeric_value_out_of_range THEN NULL; END;
END; $overflow$;
RESET ROLE;
ROLLBACK TO f_audience_overflow;

SAVEPOINT f_revision_overflow;
UPDATE identity.identities SET credential_revision=9223372036854775807;
SET LOCAL ROLE tomopedidos_auth_runtime;
DO $overflow$ BEGIN BEGIN
 PERFORM * FROM identity.rehash_conditional('f2000000-0000-4000-8000-000000000001',9223372036854775807,
 '$argon2id$v=19$m=19456,t=2,p=1$AAAAAAAAAAAAAAAAAAAAAA$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
 '$argon2id$v=19$m=65536,t=2,p=1$AAAAAAAAAAAAAAAAAAAAAA$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA');
 RAISE EXCEPTION 'Revision overflow accepted';
 EXCEPTION WHEN numeric_value_out_of_range THEN NULL; END;
END; $overflow$;
RESET ROLE;
ROLLBACK TO f_revision_overflow;

SAVEPOINT f_rehash_stale;
SET LOCAL ROLE tomopedidos_auth_runtime;
DO $stale$ DECLARE v record; BEGIN
 SELECT * INTO STRICT v FROM identity.rehash_conditional('f2000000-0000-4000-8000-000000000001',0,
 '$argon2id$v=19$m=19456,t=2,p=1$AAAAAAAAAAAAAAAAAAAAAA$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
 '$argon2id$v=19$m=65536,t=2,p=1$AAAAAAAAAAAAAAAAAAAAAA$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA');
 IF v.result<>'not_applied' THEN RAISE EXCEPTION 'Stale CAS accepted'; END IF;
END; $stale$;
RESET ROLE;
ROLLBACK TO f_rehash_stale;
DO $done$ BEGIN RAISE NOTICE 'F fail-closed state/audience/digest/overflow/CAS checks passed'; END; $done$;
ROLLBACK;