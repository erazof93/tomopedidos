-- REAL maintenance login, not SET ROLE from bootstrap. Every attempted statement rolls back.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
BEGIN;
SET LOCAL search_path TO pg_catalog;
DO $negative$
DECLARE v_sql text; v_n integer:=0;
BEGIN
    IF session_user<>'tomopedidos_session_maintenance' OR current_user<>session_user THEN RAISE EXCEPTION 'Use real maintenance login'; END IF;
    FOREACH v_sql IN ARRAY ARRAY[
        'SELECT session_id FROM identity.sessions LIMIT 0',
        'SELECT password_hash FROM identity.identity_credentials LIMIT 0',
        'DELETE FROM identity.sessions WHERE false',
        'UPDATE identity.identities SET auth_epoch=auth_epoch WHERE false',
        'CREATE TABLE identity.f_forbidden(id integer)',
        'SET LOCAL ROLE tp_owner','SET LOCAL ROLE tomopedidos_cleanup_executor',
        'SET LOCAL ROLE tomopedidos_auth_executor','SET LOCAL ROLE tomopedidos_auth_revoke_executor',
        'SELECT * FROM identity.validate_session(NULL::bytea,NULL::text)',
        'SELECT * FROM identity.revoke_global(NULL::bytea,NULL::text)',
        'SELECT * FROM identity.revoke_audience(NULL::bytea,NULL::text)'
    ] LOOP
        BEGIN
            EXECUTE v_sql;
            RAISE EXCEPTION 'Maintenance negative unexpectedly accepted';
        EXCEPTION WHEN insufficient_privilege THEN v_n:=v_n+1;
        END;
    END LOOP;
    IF v_n<>12 THEN RAISE EXCEPTION 'Maintenance negative count differs'; END IF;
    RAISE NOTICE 'F maintenance negatives passed: %',v_n;
END;
$negative$;
ROLLBACK;
