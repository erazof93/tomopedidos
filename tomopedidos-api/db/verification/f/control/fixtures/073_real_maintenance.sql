\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
BEGIN;
DO $call$
DECLARE v record;
BEGIN
 IF session_user<>'tomopedidos_session_maintenance' OR current_user<>session_user THEN RAISE EXCEPTION 'Expected real maintenance login'; END IF;
 SELECT * INTO STRICT v FROM identity.cleanup_sessions(100);
 IF v.examined<>0 OR v.deleted<>0 OR v.skipped<>0 THEN RAISE EXCEPTION 'Expected empty synthetic database'; END IF;
 RAISE NOTICE 'F real maintenance cleanup execution passed: empty batch';
END;
$call$;
ROLLBACK;
