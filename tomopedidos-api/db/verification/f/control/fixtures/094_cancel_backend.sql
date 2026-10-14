-- MANUAL FAULT INJECTION, separate authorization. Never terminate arbitrary backends.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
\if :{?f_cancel_pid}
\else
\set f_cancel_pid 0
\endif
SELECT session_user='tomopedidos_bootstrap' AND EXISTS
    (SELECT 1 FROM pg_stat_activity WHERE pid=:'f_cancel_pid'::integer
     AND datname='tp_b2a_f_20261014_r01' AND usename='tomopedidos_session_maintenance'
     AND application_name='tp-b2a-f-20261014-r01:cancelled-cleanup' AND state='active'
     AND cardinality(pg_blocking_pids(pid))>0) AS f_cancel_ok \gset
\if :f_cancel_ok
SELECT pg_cancel_backend(pid) AS sent FROM pg_stat_activity
WHERE pid=:'f_cancel_pid'::integer AND datname='tp_b2a_f_20261014_r01'
  AND usename='tomopedidos_session_maintenance'
  AND application_name='tp-b2a-f-20261014-r01:cancelled-cleanup' AND state='active'
  AND cardinality(pg_blocking_pids(pid))>0 \gset f_cancel_
\if :f_cancel_sent
\echo 'Cancellation sent to revalidated F fixture backend; verify B SQLSTATE/rollback separately.'
\else
DO $wrong$ BEGIN RAISE EXCEPTION 'F cancellation was not sent'; END; $wrong$;
\endif
\else
DO $wrong$ BEGIN RAISE EXCEPTION 'Refuse cancellation: exact F backend/actor/wait not identified'; END; $wrong$;
\endif
