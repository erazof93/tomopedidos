-- F enrollment READ ONLY, no source/application scripts included.
-- Only after separate instance provisioning authorization and Docker identity checks.
\set ON_ERROR_STOP on
BEGIN READ ONLY;
DO $identity$
BEGIN
    IF current_database() <> 'tp_b2a_f_20261014_r01'
        OR current_setting('cluster_name') <> 'tp-b2a-f-20261014-r01'
        OR current_setting('server_version_num')::integer <> 180006
        OR session_user <> 'tomopedidos_bootstrap' OR current_user <> session_user
        OR inet_server_addr() IS DISTINCT FROM '127.0.0.1'::inet OR inet_server_port() <> 5432
        OR NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname=session_user AND rolsuper)
        OR EXISTS (SELECT 1 FROM pg_database WHERE datname = 'tomopedidos_local') THEN
        RAISE EXCEPTION 'F enrollment rejected: wrong disposable identity';
    END IF;
END;
$identity$;
SELECT system_identifier::text, current_database(), current_setting('cluster_name'),
       current_setting('server_version_num'), inet_server_addr(), inet_server_port()
FROM pg_control_system();
ROLLBACK;
-- Manually review/pin system_identifier in target.json; never auto-enroll existing cluster.
