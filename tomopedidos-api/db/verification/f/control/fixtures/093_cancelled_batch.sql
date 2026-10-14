-- Connection B; manual cancel from 094 after observing THIS F PID blocked by holder.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
BEGIN;
SET LOCAL application_name TO 'tp-b2a-f-20261014-r01:cancelled-cleanup';
SET LOCAL lock_timeout TO '10s';
SET LOCAL statement_timeout TO '15s';
SELECT pg_backend_pid() AS cancellation_fixture_pid;
DO $cancel$ BEGIN
    IF session_user<>'tomopedidos_session_maintenance' OR current_user<>session_user THEN RAISE EXCEPTION 'Use real maintenance caller'; END IF;
    BEGIN
        PERFORM * FROM identity.cleanup_sessions(100);
        RAISE EXCEPTION 'Expected F cancellation did not occur';
    EXCEPTION WHEN query_canceled THEN
        RAISE NOTICE 'F 57014 observed; record cancel timing vs statement timeout and verify rollback';
    END;
END; $cancel$;
ROLLBACK;
