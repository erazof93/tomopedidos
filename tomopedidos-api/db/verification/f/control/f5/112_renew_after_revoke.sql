-- NEW independently authenticated auth connection AFTER111 confirmed COMMIT.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
BEGIN;
DO $renew$ DECLARE r record; BEGIN
 IF session_user<>'tomopedidos_auth_runtime' OR current_user<>session_user THEN RAISE EXCEPTION 'Use independent real auth'; END IF;
 SELECT * INTO STRICT r FROM identity.record_activity(sha256(convert_to('F5C postrevoke synthetic','UTF8')),'admin');
 IF r.result<>'invalid' OR r.session_id IS NOT NULL OR r.checked_at IS NOT NULL
 THEN RAISE EXCEPTION 'Revoked session renewed or metadata disclosed'; END IF;
 RAISE NOTICE 'F5C independent renewal rejected: invalid, no metadata';
END; $renew$;
ROLLBACK;
