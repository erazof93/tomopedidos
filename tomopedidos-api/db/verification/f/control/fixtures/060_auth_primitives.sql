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

SAVEPOINT f_op;
SET LOCAL ROLE tomopedidos_auth_runtime;
DO $lookup$ DECLARE v integer; BEGIN
    SELECT count(*) INTO v FROM identity.lookup_credential('primitives-f@example.invalid','admin');
    IF v<>1 THEN RAISE EXCEPTION 'Lookup positive failed'; END IF;
    SELECT count(*) INTO v FROM identity.lookup_credential('missing@example.invalid','admin');
    IF v<>0 THEN RAISE EXCEPTION 'Lookup missing failed'; END IF;
END; $lookup$;
RESET ROLE;
ROLLBACK TO f_op;

SAVEPOINT f_issue;
SET LOCAL ROLE tomopedidos_auth_runtime;
DO $issue$ DECLARE v record; BEGIN
    SELECT * INTO STRICT v FROM identity.issue_session('f2000000-0000-4000-8000-000000000001',1,0,0,'admin',
        'f2100000-0000-4000-8000-000000000003',sha256(convert_to('F issued fixture','UTF8')),'f-test',decode(repeat('00',32),'hex'));
    IF v.result<>'issued' OR v.absolute_expires_at<>v.created_at+interval '604800 seconds'
        OR v.idle_expires_at<>v.created_at+interval '43200 seconds' THEN RAISE EXCEPTION 'Issue positive failed'; END IF;
END; $issue$;
RESET ROLE;
DO $inserted$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM identity.sessions WHERE session_id='f2100000-0000-4000-8000-000000000003') THEN
        RAISE EXCEPTION 'Issued session absent inside transaction';
    END IF;
END; $inserted$;
ROLLBACK TO f_issue;

SAVEPOINT f_stale;
SET LOCAL ROLE tomopedidos_auth_runtime;
DO $stale$ DECLARE v record; BEGIN
    SELECT * INTO STRICT v FROM identity.issue_session('f2000000-0000-4000-8000-000000000001',0,0,0,'admin',
        'f2100000-0000-4000-8000-000000000003',sha256(convert_to('F stale fixture','UTF8')),'f-test',decode(repeat('00',32),'hex'));
    IF v.result<>'invalid' OR v.session_id IS NOT NULL THEN RAISE EXCEPTION 'Stale evidence accepted'; END IF;
END; $stale$;
RESET ROLE;
ROLLBACK TO f_stale;

SAVEPOINT f_platform;
SET LOCAL ROLE tomopedidos_auth_runtime;
DO $platform$ DECLARE v record; BEGIN
    SELECT * INTO STRICT v FROM identity.issue_session('f2000000-0000-4000-8000-000000000001',1,0,0,'platform',
        'f2100000-0000-4000-8000-000000000003',sha256(convert_to('F platform fixture','UTF8')),'f-test',decode(repeat('00',32),'hex'));
    IF v.result<>'invalid' THEN RAISE EXCEPTION 'Platform password issuance accepted'; END IF;
END; $platform$;
RESET ROLE;
ROLLBACK TO f_platform;

SAVEPOINT f_validate;
SET LOCAL ROLE tomopedidos_auth_runtime;
DO $validate$ DECLARE v record; BEGIN
    SELECT * INTO STRICT v FROM identity.validate_session(sha256(convert_to('F primitive 1','UTF8')),'admin');
    IF v.result<>'valid' OR v.identity_id IS NULL OR v.checked_at IS NULL THEN RAISE EXCEPTION 'Validate failed'; END IF;
END; $validate$;
RESET ROLE;
ROLLBACK TO f_validate;

SAVEPOINT f_activity;
SET LOCAL ROLE tomopedidos_auth_runtime;
DO $activity$ DECLARE v record; BEGIN
    SELECT * INTO STRICT v FROM identity.record_activity(sha256(convert_to('F primitive 1','UTF8')),'admin');
    IF v.result<>'activity_recorded' THEN RAISE EXCEPTION 'Activity failed'; END IF;
END; $activity$;
RESET ROLE;
DO $renewed$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM identity.sessions WHERE session_id='f2100000-0000-4000-8000-000000000001'
        AND last_activity_at>created_at+interval '1 minute' AND idle_expires_at<=absolute_expires_at) THEN
        RAISE EXCEPTION 'Renewal metadata failed';
    END IF;
END; $renewed$;
ROLLBACK TO f_activity;

SAVEPOINT f_logout;
SET LOCAL ROLE tomopedidos_auth_runtime;
DO $logout$ DECLARE v record; BEGIN
    SELECT * INTO STRICT v FROM identity.revoke_session(sha256(convert_to('F primitive 1','UTF8')),'admin');
    IF v.result<>'revoked' THEN RAISE EXCEPTION 'Logout failed'; END IF;
END; $logout$;
RESET ROLE;
DO $revoked$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM identity.sessions WHERE session_id='f2100000-0000-4000-8000-000000000001' AND revoked_at IS NOT NULL) THEN
        RAISE EXCEPTION 'Logout mark absent';
    END IF;
END; $revoked$;
ROLLBACK TO f_logout;

SAVEPOINT f_expiry;
SET LOCAL ROLE tomopedidos_auth_runtime;
DO $expiry$ DECLARE v record; BEGIN
    SELECT * INTO STRICT v FROM identity.mark_expired(sha256(convert_to('F primitive 2','UTF8')),'admin');
    IF v.result<>'expired' OR v.session_id IS NOT NULL THEN RAISE EXCEPTION 'Expiry failed/metadata leaked'; END IF;
END; $expiry$;
RESET ROLE;
DO $expired$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM identity.sessions WHERE session_id='f2100000-0000-4000-8000-000000000002' AND expired_at IS NOT NULL) THEN
        RAISE EXCEPTION 'Expiry terminal mark absent';
    END IF;
END; $expired$;
ROLLBACK TO f_expiry;

SAVEPOINT f_audience;
SET LOCAL ROLE tomopedidos_auth_revoke_executor;
DO $audience$ DECLARE v record; BEGIN
    SELECT * INTO STRICT v FROM identity.revoke_audience(sha256(convert_to('F primitive 1','UTF8')),'admin');
    IF v.result<>'audience_revoked' OR v.current_audience_epoch<>1 THEN RAISE EXCEPTION 'Audience scope failed'; END IF;
END; $audience$;
RESET ROLE;
ROLLBACK TO f_audience;

SAVEPOINT f_global;
SET LOCAL ROLE tomopedidos_auth_revoke_executor;
DO $global$ DECLARE v record; BEGIN
    SELECT * INTO STRICT v FROM identity.revoke_global(sha256(convert_to('F primitive 1','UTF8')),'admin');
    IF v.result<>'global_revoked' OR v.current_identity_epoch<>1 THEN RAISE EXCEPTION 'Global scope failed'; END IF;
END; $global$;
RESET ROLE;
ROLLBACK TO f_global;

SAVEPOINT f_rehash;
SET LOCAL ROLE tomopedidos_auth_runtime;
DO $rehash$ DECLARE v record; BEGIN
    SELECT * INTO STRICT v FROM identity.rehash_conditional('f2000000-0000-4000-8000-000000000001',1,
        '$argon2id$v=19$m=19456,t=2,p=1$AAAAAAAAAAAAAAAAAAAAAA$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
        '$argon2id$v=19$m=65536,t=2,p=1$AAAAAAAAAAAAAAAAAAAAAA$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA');
    IF v.result<>'rehashed' OR v.credential_revision<>2 THEN RAISE EXCEPTION 'Rehash failed'; END IF;
END; $rehash$;
RESET ROLE;
DO $rehash_epoch$ BEGIN
    IF (SELECT auth_epoch FROM identity.identities WHERE id='f2000000-0000-4000-8000-000000000001')<>0 THEN
        RAISE EXCEPTION 'Rehash changed epoch';
    END IF;
END; $rehash_epoch$;
ROLLBACK TO f_rehash;

DO $restored$ BEGIN
    IF (SELECT count(*) FROM identity.sessions)<>2
       OR (SELECT credential_revision FROM identity.identities WHERE id='f2000000-0000-4000-8000-000000000001')<>1 THEN
        RAISE EXCEPTION 'Primitive savepoint rollback failed';
    END IF;
    RAISE NOTICE 'F nine primitive SQL paths passed on synthetic fixtures; no cryptographic proof';
END; $restored$;
ROLLBACK;
