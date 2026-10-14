-- Fresh bootstrap READ ONLY. Does not retry cleanup or claim original caller outcome.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
BEGIN READ ONLY;
DO $reconcile$ DECLARE v integer; BEGIN
    SELECT count(*) INTO v FROM identity.sessions WHERE session_id IN
        ('f3100000-0000-4000-8000-000000000001','f3100000-0000-4000-8000-000000000002');
    IF v NOT IN (0,2) THEN RAISE EXCEPTION 'F partial fault batch observed'; END IF;
    IF NOT EXISTS (SELECT 1 FROM identity.identities WHERE id='f3000000-0000-4000-8000-000000000001')
        OR (SELECT count(*) FROM identity.audience_revocations WHERE identity_id='f3000000-0000-4000-8000-000000000001')<>2 THEN
        RAISE EXCEPTION 'F fault fixture parents were changed';
    END IF;
    RAISE NOTICE 'F reconciliation: fixture rows remaining %, original caller still unknown if ACK lost',v;
END; $reconcile$;
SELECT pid,application_name,state,wait_event_type,wait_event,pg_blocking_pids(pid)
FROM pg_stat_activity WHERE datname='tp_b2a_f_20261014_r01'
AND application_name LIKE 'tp-b2a-f-20261014-r01:%';
ROLLBACK;
