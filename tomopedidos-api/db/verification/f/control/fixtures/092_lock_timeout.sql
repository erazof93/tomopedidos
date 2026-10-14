-- Connection B, REAL maintenance login; requires A holding fixture Identity UPDATE.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
BEGIN;
SET LOCAL application_name TO 'tp-b2a-f-20261014-r01:lock-timeout';
SET LOCAL lock_timeout TO '50ms';
SET LOCAL statement_timeout TO '500ms';
DO $timeout$ BEGIN
    IF session_user<>'tomopedidos_session_maintenance' OR current_user<>session_user THEN RAISE EXCEPTION 'Use real maintenance caller'; END IF;
    BEGIN
        PERFORM * FROM identity.cleanup_sessions(100);
        RAISE EXCEPTION 'Expected F lock timeout did not occur';
    EXCEPTION WHEN lock_not_available THEN
        RAISE NOTICE 'F expected 55P03 observed; verify rows/locks after ROLLBACK';
    END;
END; $timeout$;
ROLLBACK;
