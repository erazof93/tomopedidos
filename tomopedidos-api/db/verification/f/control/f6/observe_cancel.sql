-- Fresh read-only capture of the exact F6 waiter and holder. No signal sent here.
\set ON_ERROR_STOP on
BEGIN READ ONLY;
\ir /f/control/001_preflight.sql
SELECT w.pid AS waiter_pid,w.backend_start AS waiter_start,h.pid AS holder_pid,
 h.backend_start AS holder_start,clock_timestamp() AS observed_at,pg_blocking_pids(w.pid) AS blockers
FROM pg_stat_activity w JOIN pg_stat_activity h ON pg_blocking_pids(w.pid)=ARRAY[h.pid]
WHERE w.datname='tp_b2a_f_20261014_r01' AND h.datname=w.datname
 AND w.usename='tomopedidos_session_maintenance' AND h.usename='tomopedidos_bootstrap'
 AND w.application_name='tp-b2a-f-20261014-r01:f6-cancel'
 AND h.application_name='tp-b2a-f-20261014-r01:f6-holder'
 AND w.state='active' AND w.wait_event_type='Lock' AND h.state='idle in transaction';
ROLLBACK;
