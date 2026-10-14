-- READ ONLY observer barrier. Prepared, not executed in F5-A.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
BEGIN READ ONLY;
SELECT pid,usename,application_name,state,wait_event_type,wait_event,pg_blocking_pids(pid) AS blockers
FROM pg_stat_activity
WHERE datname='tp_b2a_f_20261014_r01'
 AND application_name IN ('tp-b2a-f-20261014-r01:fault-holder',
 'tp-b2a-f-20261014-r01:lock-timeout','tp-b2a-f-20261014-r01:cancelled-cleanup',
 'tp-b2a-f-20261014-r01:statement-timeout','tp-b2a-f-20261014-r01:ambiguous-cleanup')
ORDER BY pid;
ROLLBACK;
