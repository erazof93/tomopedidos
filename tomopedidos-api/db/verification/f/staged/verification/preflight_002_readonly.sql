-- F target-only staged copy; original hash is in stage-manifest.json.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
-- Prepared only; not executed. Inventory, not an automatic approval gate.
\set ON_ERROR_STOP on
BEGIN READ ONLY;
SET LOCAL search_path TO pg_catalog;
SELECT current_database(), session_user, current_user,
       current_setting('server_version') AS version;
SELECT d.datname, pg_get_userbyid(d.datdba) AS owner, d.datistemplate,
       r.rolsuper AS bootstrap_superuser, d.datallowconn
FROM pg_database d JOIN pg_roles r ON r.rolname=session_user
WHERE d.datname=current_database();
-- NULL ACL means built-in defaults, not absence of privileges.
SELECT d.datname, CASE WHEN a.grantee=0 THEN 'PUBLIC'
       ELSE pg_get_userbyid(a.grantee) END AS grantee,
       pg_get_userbyid(a.grantor) AS grantor, a.privilege_type, a.is_grantable
FROM pg_database d
CROSS JOIN LATERAL aclexplode(COALESCE(d.datacl,acldefault('d',d.datdba))) a
WHERE d.datname=current_database();
SELECT n.nspname, pg_get_userbyid(n.nspowner) AS owner,
       CASE WHEN a.grantee=0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END AS grantee,
       a.privilege_type, a.is_grantable
FROM pg_namespace n
LEFT JOIN LATERAL aclexplode(COALESCE(n.nspacl,acldefault('n',n.nspowner))) a ON true
WHERE n.nspname IN ('public','identity','tenancy','authorization','audit','migration_meta');
-- Current effective rights include PUBLIC and inherited grants; inspect memberships too.
SELECT r.rolname, r.rolcanlogin, r.rolsuper,
       has_database_privilege(r.oid,current_database(),'CONNECT') AS connect_now,
       has_database_privilege(r.oid,current_database(),'TEMP') AS temp_now,
       has_database_privilege(r.oid,current_database(),'CREATE') AS create_now,
       has_schema_privilege(r.oid,n.oid,'USAGE') AS public_usage_now,
       has_schema_privilege(r.oid,n.oid,'CREATE') AS public_create_now
FROM pg_roles r LEFT JOIN pg_namespace n ON n.nspname='public'
ORDER BY r.rolname;
SELECT rolname, rolcanlogin, rolinherit, rolsuper, rolcreatedb, rolcreaterole,
       rolreplication, rolbypassrls FROM pg_roles
WHERE rolname IN ('tp_owner','tomopedidos_migrator','tomopedidos_runtime');
SELECT member.rolname AS member, granted.rolname AS granted_role,
       m.admin_option,m.inherit_option,m.set_option
FROM pg_auth_members m JOIN pg_roles member ON member.oid=m.member
JOIN pg_roles granted ON granted.oid=m.roleid ORDER BY member,granted_role;
SELECT n.nspname,pg_describe_object(d.classid,d.objid,d.objsubid) AS object,d.deptype
FROM pg_depend d JOIN pg_namespace n ON n.oid=d.refobjid
WHERE d.refclassid='pg_namespace'::regclass
AND n.nspname IN ('public','identity','tenancy','authorization','audit','migration_meta')
ORDER BY n.nspname,object;
SELECT extname,extversion,pg_get_userbyid(extowner) AS owner,
       extnamespace::regnamespace AS schema FROM pg_extension;
-- All creators: includes schema defaults of bootstrap that could affect CREATE SCHEMA.
SELECT pg_get_userbyid(defaclrole) AS creator,
       CASE WHEN defaclnamespace=0 THEN 'GLOBAL'
            ELSE defaclnamespace::regnamespace::text END AS scope,
       defaclobjtype,defaclacl FROM pg_default_acl;
SELECT r.rolname,db.datname,d.classid::regclass AS catalog,d.objid,d.deptype
FROM pg_shdepend d JOIN pg_roles r ON r.oid=d.refobjid
LEFT JOIN pg_database db ON db.oid=d.dbid
WHERE d.refclassid='pg_authid'::regclass
AND r.rolname IN ('tp_owner','tomopedidos_migrator','tomopedidos_runtime');
SELECT parname,paracl FROM pg_parameter_acl;
-- Show setting names only; arbitrary values can contain private connection details.
SELECT COALESCE(r.rolname,'ALL') AS role,COALESCE(db.datname,'ALL') AS database,
       split_part(setting,'=',1) AS setting_name
FROM pg_db_role_setting s LEFT JOIN pg_roles r ON r.oid=s.setrole
LEFT JOIN pg_database db ON db.oid=s.setdatabase
CROSS JOIN LATERAL unnest(s.setconfig) AS config(setting);
-- No query text, passwords, or environment values.
SELECT pid,usename,application_name,client_addr,backend_type,state
FROM pg_stat_activity WHERE datname=current_database();
ROLLBACK;
