-- Run via real SCRAM TCP login separately for migrator/auth/tenant/maintenance.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
BEGIN READ ONLY;
DO $login$
BEGIN
    IF session_user NOT IN ('tomopedidos_migrator','tomopedidos_auth_runtime','tomopedidos_runtime','tomopedidos_session_maintenance')
        OR current_user<>session_user OR inet_client_addr() IS NULL
        OR NOT has_database_privilege(session_user,current_database(),'CONNECT')
        OR EXISTS (SELECT 1 FROM pg_roles WHERE rolname=session_user AND
                   (rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls OR rolinherit)) THEN
        RAISE EXCEPTION 'Real TCP caller context failed';
    END IF;
    IF session_user IN ('tomopedidos_auth_runtime','tomopedidos_session_maintenance')
        AND EXISTS (SELECT 1 FROM pg_auth_members AS m JOIN pg_roles AS r ON r.oid IN(m.member,m.roleid)
                    WHERE r.rolname=session_user) THEN RAISE EXCEPTION 'Caller membership drift'; END IF;
    RAISE NOTICE 'F real login context passed: %',session_user;
END;
$login$;
ROLLBACK;
