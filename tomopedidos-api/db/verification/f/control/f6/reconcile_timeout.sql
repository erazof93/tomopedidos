\set ON_ERROR_STOP on
BEGIN READ ONLY;
\ir /f/control/001_preflight.sql
DO $rows$ BEGIN
 IF (SELECT count(*) FROM identity.sessions WHERE session_id IN('f3100000-0000-4000-8000-000000000001','f3100000-0000-4000-8000-000000000002'))<>2
 OR (SELECT count(*) FROM identity.identities WHERE id='f3000000-0000-4000-8000-000000000001')<>1
 OR (SELECT count(*) FROM identity.audience_revocations WHERE identity_id='f3000000-0000-4000-8000-000000000001')<>2
 THEN RAISE EXCEPTION 'F6 failed operation left partial/unexpected data'; END IF;
END; $rows$;
SELECT pid,backend_start,application_name,state,wait_event_type,pg_blocking_pids(pid)
FROM pg_stat_activity WHERE datname=current_database() AND application_name LIKE 'tp-b2a-f-20261014-r01:f6-%';
ROLLBACK;
