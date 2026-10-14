-- PREPARED ONLY; read-only checks after approved bootstrap application.
\set ON_ERROR_STOP on
BEGIN READ ONLY;
SET LOCAL search_path TO pg_catalog;
DO $verify$
DECLARE
  v_row record;
  v_name text;
  v_expected_owner oid;
BEGIN
  IF current_database() <> 'tomopedidos_local' OR session_user<>'tomopedidos_bootstrap'
     OR current_user<>session_user
     OR NOT (SELECT rolsuper FROM pg_roles WHERE rolname=current_user) THEN
    RAISE EXCEPTION 'Wrong verification context';
  END IF;
  IF (SELECT count(*) FROM pg_roles WHERE rolname IN ('tp_owner','tomopedidos_migrator','tomopedidos_runtime')) <> 3 THEN
    RAISE EXCEPTION 'B1 roles missing';
  END IF;
  FOR v_row IN SELECT * FROM pg_roles WHERE rolname IN ('tp_owner','tomopedidos_migrator','tomopedidos_runtime') LOOP
    IF v_row.rolsuper OR v_row.rolcreatedb OR v_row.rolcreaterole OR v_row.rolreplication OR v_row.rolbypassrls OR v_row.rolinherit
       OR v_row.rolcanlogin <> (v_row.rolname <> 'tp_owner') THEN RAISE EXCEPTION 'Unsafe role attributes'; END IF;
  END LOOP;
  IF NOT pg_has_role('tomopedidos_migrator','tp_owner','SET')
     OR pg_has_role('tomopedidos_migrator','tp_owner','USAGE')
     OR pg_has_role('tomopedidos_runtime','tp_owner','MEMBER') THEN
    RAISE EXCEPTION 'Unexpected owner delegation';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_auth_members m JOIN pg_roles r ON r.oid=m.member
             WHERE r.rolname='tomopedidos_runtime') THEN RAISE EXCEPTION 'Runtime membership is not empty'; END IF;
  IF EXISTS (SELECT 1 FROM pg_auth_members m JOIN pg_roles r ON r.oid=m.member
             WHERE r.rolname='tomopedidos_migrator' AND m.admin_option) THEN RAISE EXCEPTION 'Migrator can delegate'; END IF;
  IF EXISTS (SELECT 1 FROM pg_auth_members m JOIN pg_roles member ON member.oid=m.member
             JOIN pg_roles granted ON granted.oid=m.roleid
             WHERE (member.rolname IN ('tp_owner','tomopedidos_migrator','tomopedidos_runtime')
                    OR granted.rolname='tp_owner')
               AND NOT (member.rolname='tomopedidos_migrator' AND granted.rolname='tp_owner'
                        AND m.set_option AND NOT m.inherit_option AND NOT m.admin_option)) THEN
    RAISE EXCEPTION 'Unexpected membership graph';
  END IF;
  FOREACH v_name IN ARRAY ARRAY['tomopedidos_migrator','tomopedidos_runtime'] LOOP
    IF NOT has_database_privilege(v_name,current_database(),'CONNECT')
       OR has_database_privilege(v_name,current_database(),'CREATE')
       OR has_database_privilege(v_name,current_database(),'TEMP') THEN RAISE EXCEPTION 'Unsafe database privileges'; END IF;
  END LOOP;
  SELECT oid INTO STRICT v_expected_owner FROM pg_roles WHERE rolname='tp_owner';
  IF EXISTS (SELECT 1 FROM pg_database WHERE datdba IN
             (SELECT oid FROM pg_roles WHERE rolname IN ('tp_owner','tomopedidos_migrator','tomopedidos_runtime')))
     OR EXISTS (SELECT 1 FROM pg_shdepend d JOIN pg_roles r ON r.oid=d.refobjid
                WHERE d.refclassid='pg_authid'::regclass
                  AND r.rolname IN ('tp_owner','tomopedidos_migrator','tomopedidos_runtime')
                  AND d.dbid<>0 AND d.dbid<>(SELECT oid FROM pg_database WHERE datname=current_database())) THEN
    RAISE EXCEPTION 'Roles have ownership or privileges in another database';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_parameter_acl p CROSS JOIN LATERAL aclexplode(p.paracl) a
             WHERE a.grantee=0 OR a.grantee IN
               (SELECT oid FROM pg_roles WHERE rolname IN ('tp_owner','tomopedidos_migrator','tomopedidos_runtime'))) THEN
    RAISE EXCEPTION 'Unexpected parameter privileges';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_shdepend d JOIN pg_roles r ON r.oid=d.refobjid
             WHERE d.refclassid='pg_authid'::regclass
               AND r.rolname IN ('tomopedidos_migrator','tomopedidos_runtime') AND d.deptype='o') THEN
    RAISE EXCEPTION 'Login roles must not own objects';
  END IF;
  FOREACH v_name IN ARRAY ARRAY['identity','tenancy','authorization','audit','migration_meta'] LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname=v_name AND nspowner=v_expected_owner)
       OR has_schema_privilege('tomopedidos_runtime',v_name,'CREATE')
       OR has_schema_privilege('tomopedidos_migrator',v_name,'CREATE') THEN RAISE EXCEPTION 'Unexpected schema privileges'; END IF;
    IF has_schema_privilege('tomopedidos_runtime',v_name,'USAGE') <> (v_name IN ('tenancy','authorization')) THEN
      RAISE EXCEPTION 'Unexpected runtime schema access';
    END IF;
  END LOOP;
  IF has_schema_privilege('tomopedidos_runtime','public','USAGE')
     OR has_schema_privilege('tomopedidos_migrator','public','USAGE') THEN
    RAISE EXCEPTION 'PUBLIC still exposes public schema';
  END IF;
  FOR v_row IN SELECT oid,nspname FROM pg_namespace
           WHERE nspname NOT LIKE 'pg_temp_%' AND nspname NOT LIKE 'pg_toast_temp_%' LOOP
    IF has_schema_privilege('tomopedidos_runtime',v_row.oid,'CREATE')
       OR has_schema_privilege('tomopedidos_migrator',v_row.oid,'CREATE') THEN
      RAISE EXCEPTION 'Login role has unexpected schema CREATE';
    END IF;
  END LOOP;
  IF EXISTS (SELECT 1 FROM pg_default_acl d CROSS JOIN LATERAL aclexplode(d.defaclacl) a
             WHERE d.defaclrole=v_expected_owner AND d.defaclobjtype IN ('r','S','f')
               AND a.grantee<>v_expected_owner) THEN
    RAISE EXCEPTION 'Future objects have unexpected default grantees';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_default_acl WHERE defaclrole=v_expected_owner
                  AND defaclobjtype='f' AND defaclnamespace=0) THEN
    RAISE EXCEPTION 'Global function default override is missing';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_namespace n CROSS JOIN LATERAL aclexplode(n.nspacl) a
             WHERE n.nspname IN ('identity','tenancy','authorization','audit','migration_meta')
               AND a.grantee<>v_expected_owner
               AND NOT (a.grantee=(SELECT oid FROM pg_roles WHERE rolname='tomopedidos_runtime')
                        AND n.nspname IN ('tenancy','authorization')
                        AND a.privilege_type='USAGE' AND NOT a.is_grantable)) THEN
    RAISE EXCEPTION 'Unexpected schema ACL grantee or grant option';
  END IF;
END
$verify$;
SELECT 'B1 metadata checks passed' AS result;
ROLLBACK;
