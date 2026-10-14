-- PREPARED ONLY. Run separately via REAL LOGIN as auth runtime or tenant runtime.
-- Never SET ROLE from bootstrap to claim a SET ROLE denial: session_user matters.
-- No application fixtures. Each attempted statement is inside an exception subblock;
-- any unexpected success aborts. Final transaction always rolls back.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL search_path TO pg_catalog;
SET LOCAL lock_timeout TO '1s';
SET LOCAL statement_timeout TO '2s';
DO $context$
BEGIN
    IF current_database() <> 'tomopedidos_local'
        OR current_setting('server_version_num')::integer / 100 <> 1800
        OR session_user NOT IN ('tomopedidos_auth_runtime','tomopedidos_runtime')
        OR current_user <> session_user
        OR EXISTS (SELECT 1 FROM pg_roles WHERE rolname = session_user AND rolsuper) THEN
        RAISE EXCEPTION 'Use an independently authenticated local PG18 caller session';
    END IF;
END;
$context$;
DO $negative$
DECLARE v_sql text; v_count integer := 0;
BEGIN
    FOREACH v_sql IN ARRAY ARRAY[
        'SELECT id FROM identity.identities LIMIT 0',
        'SELECT password_hash FROM identity.identity_credentials LIMIT 0',
        'SELECT auth_epoch FROM identity.audience_revocations LIMIT 0',
        'SELECT token_hash FROM identity.sessions LIMIT 0',
        'INSERT INTO identity.identities (id,email_original) SELECT NULL,NULL WHERE false',
        'INSERT INTO identity.identity_credentials (identity_id,password_hash,changed_at) SELECT NULL,NULL,NULL WHERE false',
        'INSERT INTO identity.audience_revocations (identity_id,audience) SELECT NULL,NULL WHERE false',
        'INSERT INTO identity.sessions (session_id) SELECT NULL WHERE false',
        'UPDATE identity.identities SET auth_epoch=auth_epoch WHERE false',
        'UPDATE identity.identity_credentials SET password_hash=password_hash WHERE false',
        'UPDATE identity.audience_revocations SET auth_epoch=auth_epoch WHERE false',
        'UPDATE identity.sessions SET revoked_at=revoked_at WHERE false',
        'DELETE FROM identity.sessions WHERE false',
        'DELETE FROM identity.identities WHERE false',
        'CREATE TABLE identity.d_isolation_forbidden (id integer)',
        'CREATE SCHEMA d_isolation_forbidden',
        'CREATE TEMP TABLE d_isolation_forbidden (id integer)',
        'SELECT * FROM identity.revoke_audience(NULL::bytea,NULL::text)',
        'SELECT * FROM identity.revoke_global(NULL::bytea,NULL::text)',
        'SELECT identity.guard_identities_update()',
        'SELECT identity.guard_audience_revocations_update()',
        'SELECT identity.guard_sessions_update()',
        'SET LOCAL ROLE tp_owner',
        'SET LOCAL ROLE tomopedidos_migrator',
        'SET LOCAL ROLE tomopedidos_auth_executor',
        'SET LOCAL ROLE tomopedidos_auth_revoke_executor'
    ] LOOP
        BEGIN
            EXECUTE v_sql;
            RAISE EXCEPTION 'Isolation negative unexpectedly succeeded (case %)', v_count + 1;
        EXCEPTION WHEN insufficient_privilege THEN
            v_count := v_count + 1;
        END;
    END LOOP;
    IF session_user = 'tomopedidos_runtime' THEN
        FOREACH v_sql IN ARRAY ARRAY[
            'SELECT * FROM identity.lookup_credential(NULL::text,NULL::text)',
            'SELECT * FROM identity.issue_session(NULL::uuid,NULL::bigint,NULL::bigint,NULL::bigint,NULL::text,NULL::uuid,NULL::bytea,NULL::text,NULL::bytea)',
            'SELECT * FROM identity.validate_session(NULL::bytea,NULL::text)',
            'SELECT * FROM identity.record_activity(NULL::bytea,NULL::text)',
            'SELECT * FROM identity.revoke_session(NULL::bytea,NULL::text)',
            'SELECT * FROM identity.mark_expired(NULL::bytea,NULL::text)',
            'SELECT * FROM identity.rehash_conditional(NULL::uuid,NULL::bigint,NULL::text,NULL::text)'
        ] LOOP
            BEGIN
                EXECUTE v_sql;
                RAISE EXCEPTION 'Tenant function negative unexpectedly succeeded (case %)',v_count + 1;
            EXCEPTION WHEN insufficient_privilege THEN v_count := v_count + 1;
            END;
        END LOOP;
    END IF;
    IF v_count <> CASE session_user WHEN 'tomopedidos_runtime' THEN 33 ELSE 26 END THEN
        RAISE EXCEPTION 'Unexpected negative count';
    END IF;
    RAISE NOTICE 'D real caller negatives passed: actor %, count %',session_user,v_count;
END;
$negative$;
ROLLBACK;
