-- Run via REAL auth login. Revocation must confirm before independent renewal.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
BEGIN;
DO $revoke$ DECLARE r record; BEGIN
 IF session_user<>'tomopedidos_auth_runtime' OR current_user<>session_user THEN RAISE EXCEPTION 'Use real auth'; END IF;
 SELECT * INTO STRICT r FROM identity.revoke_session(sha256(convert_to('F5C postrevoke synthetic','UTF8')),'admin');
 IF r.result<>'revoked' THEN RAISE EXCEPTION 'Expected live-session revocation'; END IF;
END; $revoke$;
COMMIT;
\echo 'F5C_REVOCATION_COMMIT_CONFIRMED'
