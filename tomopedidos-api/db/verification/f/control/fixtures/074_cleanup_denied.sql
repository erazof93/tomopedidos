\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
BEGIN;
DO $denied$
BEGIN
 IF session_user NOT IN ('tomopedidos_auth_runtime','tomopedidos_runtime') OR current_user<>session_user THEN RAISE EXCEPTION 'Wrong real caller'; END IF;
 BEGIN
  PERFORM * FROM identity.cleanup_sessions(1);
  RAISE EXCEPTION 'Cleanup caller unexpectedly permitted';
 EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'F real caller cleanup denial passed: %',session_user;
 END;
END;
$denied$;
ROLLBACK;
