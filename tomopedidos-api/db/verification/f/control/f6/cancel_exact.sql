-- Future cancellation of one revalidated F waiter; no terminate backend.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
SELECT session_user='tomopedidos_bootstrap' AND count(*)=1 AS f_cancel_ok
FROM pg_stat_activity w JOIN pg_stat_activity h ON h.pid=:'f_holder_pid'::integer
WHERE w.pid=:'f_waiter_pid'::integer AND w.backend_start=:'f_waiter_start'::timestamptz
 AND h.backend_start=:'f_holder_start'::timestamptz
 AND w.datname='tp_b2a_f_20261014_r01' AND h.datname=w.datname
 AND w.usename='tomopedidos_session_maintenance' AND h.usename='tomopedidos_bootstrap'
 AND w.application_name='tp-b2a-f-20261014-r01:f6-cancel' AND h.application_name='tp-b2a-f-20261014-r01:f6-holder'
 AND w.state='active' AND w.wait_event_type='Lock' AND h.state='idle in transaction'
 AND pg_blocking_pids(w.pid)=ARRAY[h.pid] AND w.pid<>h.pid \gset
-- An old observation may identify the same PID but must not authorize a delayed signal.
SELECT :'f_observed_at'::timestamptz<=clock_timestamp()
 AND clock_timestamp()-:'f_observed_at'::timestamptz<=interval '5 seconds' AS f_observation_fresh \gset
\if :f_observation_fresh
\else
DO $bad$ BEGIN RAISE EXCEPTION 'F6 cancellation observation stale/future'; END; $bad$;
\endif
\if :f_cancel_ok
SELECT pg_cancel_backend(w.pid) AS sent FROM pg_stat_activity w JOIN pg_stat_activity h ON h.pid=:'f_holder_pid'::integer
WHERE w.pid=:'f_waiter_pid'::integer AND w.backend_start=:'f_waiter_start'::timestamptz AND h.backend_start=:'f_holder_start'::timestamptz
 AND w.datname='tp_b2a_f_20261014_r01' AND h.datname=w.datname
 AND w.usename='tomopedidos_session_maintenance' AND h.usename='tomopedidos_bootstrap'
 AND w.application_name='tp-b2a-f-20261014-r01:f6-cancel' AND h.application_name='tp-b2a-f-20261014-r01:f6-holder'
 AND w.state='active' AND w.wait_event_type='Lock' AND h.state='idle in transaction'
 AND pg_blocking_pids(w.pid)=ARRAY[h.pid] AND w.pid<>h.pid
 AND :'f_observed_at'::timestamptz<=clock_timestamp()
 AND clock_timestamp()-:'f_observed_at'::timestamptz<=interval '5 seconds' \gset f_cancel_
\if :f_cancel_sent
\echo 'F6_CANCEL_SENT_NOT_YET_OBSERVED'
\else
DO $bad$ BEGIN RAISE EXCEPTION 'F6 cancellation not sent'; END; $bad$;
\endif
\else
DO $bad$ BEGIN RAISE EXCEPTION 'F6 exact cancellation target rejected'; END; $bad$;
\endif
