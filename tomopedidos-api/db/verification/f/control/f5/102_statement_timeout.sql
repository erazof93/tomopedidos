-- REAL maintenance TCP, only after091 holder acquired+observer barrier; never F5-A.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
BEGIN;
SET LOCAL application_name TO 'tp-b2a-f-20261014-r01:statement-timeout';
SET LOCAL lock_timeout TO '5s';
SET LOCAL statement_timeout TO '1s';
DO $actor$ BEGIN
 IF session_user<>'tomopedidos_session_maintenance' OR current_user<>session_user
 THEN RAISE EXCEPTION 'Expected real maintenance'; END IF;
END; $actor$;
-- ON_ERROR_STOP exits on57014; finalROLLBACK below is not reached on expected timeout.
-- Disconnect rollback must be reconciled; exit/nonzero is expected, not success alone.
SELECT examined,deleted,skipped FROM identity.cleanup_sessions(100);
ROLLBACK;
