\set ON_ERROR_STOP on
BEGIN READ ONLY;
\ir /f/control/001_preflight.sql
DO $absent$
BEGIN
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname IN ('tomopedidos_cleanup_executor','tomopedidos_session_maintenance'))
 OR EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='identity' AND p.proname='cleanup_sessions')
 THEN RAISE EXCEPTION 'F4B partial/preexisting E installation rejected'; END IF;
END;
$absent$;
SELECT 'F4B E absent' AS result;
ROLLBACK;
