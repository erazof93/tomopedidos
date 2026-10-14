-- D read-only assertions. Include inside an authorized transaction; no mutations.
DO $preflight$
BEGIN
    IF pg_catalog.current_database() <> 'tp_b2a_f_20261014_r01'
        OR session_user <> 'tomopedidos_bootstrap' OR current_user <> session_user
        OR pg_catalog.current_setting('server_version_num')::integer / 100 <> 1800
        OR pg_catalog.current_setting('transaction_isolation') <> 'read committed'
        OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles
                       WHERE rolname = session_user AND rolsuper) THEN
        RAISE EXCEPTION 'D requires authorized local PG18 bootstrap context and READ COMMITTED';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_database
                   WHERE datname = pg_catalog.current_database() AND NOT datistemplate
                     AND datdba = (SELECT oid FROM pg_catalog.pg_roles WHERE rolname = session_user)) THEN
        RAISE EXCEPTION 'Unexpected database ownership';
    END IF;
    IF (SELECT count(*) FROM pg_catalog.pg_roles
        WHERE rolname IN ('tp_owner','tomopedidos_migrator','tomopedidos_runtime')) <> 3
        OR EXISTS (SELECT 1 FROM pg_catalog.pg_roles
                   WHERE rolname IN ('tp_owner','tomopedidos_migrator','tomopedidos_runtime')
                     AND (rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication
                          OR rolbypassrls OR rolinherit OR rolcanlogin <> (rolname <> 'tp_owner')))
        OR NOT pg_catalog.pg_has_role('tomopedidos_migrator','tp_owner','SET')
        OR pg_catalog.pg_has_role('tomopedidos_migrator','tp_owner','USAGE') THEN
        RAISE EXCEPTION 'B1 roles differ; never repair B1 through D';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_auth_members AS m
        JOIN pg_catalog.pg_roles AS member ON member.oid = m.member
        JOIN pg_catalog.pg_roles AS parent ON parent.oid = m.roleid
        WHERE (member.rolname IN ('tp_owner','tomopedidos_migrator','tomopedidos_runtime')
               OR parent.rolname IN ('tp_owner','tomopedidos_migrator','tomopedidos_runtime'))
          AND NOT (member.rolname = 'tomopedidos_migrator' AND parent.rolname = 'tp_owner'
                   AND m.set_option AND NOT m.inherit_option AND NOT m.admin_option)) THEN
        RAISE EXCEPTION 'Unexpected B1 membership';
    END IF;
    IF (SELECT count(*) FROM pg_catalog.pg_namespace AS n
        JOIN pg_catalog.pg_roles AS r ON r.oid = n.nspowner
        WHERE n.nspname IN ('identity','tenancy','authorization','audit','migration_meta')
          AND r.rolname = 'tp_owner') <> 5
        OR pg_catalog.has_schema_privilege('tomopedidos_runtime','identity','USAGE')
        OR pg_catalog.has_schema_privilege('tomopedidos_runtime','identity','CREATE') THEN
        RAISE EXCEPTION 'B1 schema baseline differs';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_database AS d
        CROSS JOIN LATERAL pg_catalog.aclexplode(COALESCE(d.datacl,
            pg_catalog.acldefault('d',d.datdba))) AS acl
        WHERE d.datname = pg_catalog.current_database() AND acl.grantee = 0) THEN
        RAISE EXCEPTION 'Unexpected PUBLIC database rights';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_namespace AS n
        CROSS JOIN LATERAL pg_catalog.aclexplode(COALESCE(n.nspacl,
            pg_catalog.acldefault('n',n.nspowner))) AS acl
        WHERE n.nspname IN ('public','identity','tenancy','authorization','audit','migration_meta')
          AND acl.grantee = 0) THEN
        RAISE EXCEPTION 'Unexpected PUBLIC schema rights';
    END IF;
END;
$preflight$;
