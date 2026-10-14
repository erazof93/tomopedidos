-- F6 future REAL maintenance connection. Expected failure only; no operation success.
\set ON_ERROR_STOP on
\set ON_ERROR_ROLLBACK off
\set VERBOSITY sqlstate
\ir /f/control/001_preflight.sql
BEGIN;
SET LOCAL application_name TO 'tp-b2a-f-20261014-r01:f6-statement-timeout';
SET LOCAL lock_timeout TO '0';
SET LOCAL statement_timeout TO '2s';
DO $actor$ BEGIN IF session_user<>'tomopedidos_session_maintenance' OR current_user<>session_user THEN RAISE EXCEPTION 'Use real maintenance actor'; END IF; END; $actor$;
SELECT pg_backend_pid() AS waiter_pid,backend_start AS waiter_start FROM pg_stat_activity WHERE pid=pg_backend_pid() \gset f_request_
SELECT :'f_request_waiter_pid'::integer AS waiter_pid, :'f_request_waiter_start'::timestamptz AS backend_start;
\set ON_ERROR_STOP off
SELECT examined,deleted,skipped FROM identity.cleanup_sessions(100) \gset f_unconfirmed_
\set f_operation_state :SQLSTATE
\set f_operation_error :ERROR
\set ON_ERROR_STOP on
ROLLBACK;
SELECT :'f_operation_state'='57014' AND :'f_operation_error'::boolean AS f_expected_error \gset
\if :f_expected_error
\else
DO $bad$ BEGIN RAISE EXCEPTION 'F6 operation did not fail with expected SQLSTATE'; END; $bad$;
\endif
-- Same connection, new transaction. Probe commit does not mean cleanup succeeded.
BEGIN READ ONLY;
SELECT pg_backend_pid() AS recovered_pid, pg_backend_pid()=:'f_request_waiter_pid'::integer AS same_connection \gset f_recovered_
\if :f_recovered_same_connection
\else
DO $bad$ BEGIN RAISE EXCEPTION 'F6 expected same connection recovery'; END; $bad$;
\endif
SELECT :'f_recovered_recovered_pid'::integer AS recovered_pid;
SELECT 'F6_CONNECTION_RECOVERED_OPERATION_ERROR' AS classification;
COMMIT;
