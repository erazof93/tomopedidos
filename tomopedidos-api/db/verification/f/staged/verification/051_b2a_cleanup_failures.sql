-- F target-only staged copy; original hash is in stage-manifest.json.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
-- PREPARED ONLY. Failure/ACL fixtures; no automatic connection-loss injection.
-- Requires EMPTY disposable DB, bootstrap and E enabled. Always ROLLBACK.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL search_path TO pg_catalog;
SET LOCAL TIME ZONE 'UTC';
\ir ../administration/b2a-role-preflight.sql
SET LOCAL tomopedidos.e_stage TO 'enabled';
\ir ../administration/retention/b2a-cleanup-assert.sql
DO $negative$
DECLARE v_role text;
BEGIN
    FOREACH v_role IN ARRAY ARRAY['tomopedidos_auth_runtime','tomopedidos_runtime'] LOOP
        EXECUTE 'SET LOCAL ROLE ' || quote_ident(v_role);
        BEGIN
            PERFORM * FROM identity.cleanup_sessions(100);
            RAISE EXCEPTION 'Forbidden cleanup caller accepted';
        EXCEPTION WHEN insufficient_privilege THEN NULL;
        END;
        RESET ROLE;
    END LOOP;
END;
$negative$;
DO $empty$
BEGIN
    IF EXISTS (SELECT 1 FROM identity.sessions)
        OR EXISTS (SELECT 1 FROM identity.identities WHERE id='e3000000-0000-4000-8000-000000000001') THEN
        RAISE EXCEPTION '051 requires empty disposable fixture database';
    END IF;
END;
$empty$;
INSERT INTO identity.identities (id,email_original,created_at)
VALUES ('e3000000-0000-4000-8000-000000000001','failure-e@example.invalid',clock_timestamp()-interval '60 days');
INSERT INTO identity.audience_revocations (identity_id,audience)
SELECT 'e3000000-0000-4000-8000-000000000001'::uuid,a FROM unnest(ARRAY['admin','platform']) AS a;
WITH t AS (SELECT clock_timestamp() AS now)
INSERT INTO identity.sessions (session_id,identity_id,audience,token_hash,identity_epoch,audience_epoch,
    authentication_level,csrf_key_id,csrf_salt,created_at,last_activity_at,idle_expires_at,absolute_expires_at,expired_at)
SELECT ('e3100000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
    'e3000000-0000-4000-8000-000000000001'::uuid,'admin',sha256(convert_to('E failure '||n,'UTF8')),
    0,0,'password','e-fixture',decode(repeat('00',32),'hex'),now-interval '41 days',now-interval '41 days',
    now-interval '40 days 12 hours',now-interval '34 days',CASE WHEN n=2 THEN now+interval '1 day' END
FROM t CROSS JOIN generate_series(1,2) AS n;
SET LOCAL ROLE tomopedidos_session_maintenance;
DO $clock$
BEGIN
    BEGIN
        PERFORM * FROM identity.cleanup_sessions(100);
        RAISE EXCEPTION 'Future terminal clock anomaly accepted';
    EXCEPTION WHEN datetime_field_overflow THEN NULL;
    END;
END;
$clock$;
RESET ROLE;
DO $atomic$
BEGIN
    IF (SELECT count(*) FROM identity.sessions) <> 2 THEN
        RAISE EXCEPTION 'Failure did not roll back partial batch deletion';
    END IF;
    RAISE NOTICE 'E ACL, clock anomaly and atomic failure checks passed';
END;
$atomic$;
ROLLBACK;
-- Separate transaction: set isolation before any query; no deletion can occur.
BEGIN ISOLATION LEVEL REPEATABLE READ;
SET LOCAL search_path TO pg_catalog;
SET LOCAL ROLE tomopedidos_session_maintenance;
DO $isolation$
BEGIN
    BEGIN
        PERFORM * FROM identity.cleanup_sessions(100);
        RAISE EXCEPTION 'Unsupported isolation accepted';
    EXCEPTION WHEN invalid_transaction_state THEN NULL;
    END;
END;
$isolation$;
ROLLBACK;
