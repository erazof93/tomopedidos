-- PREPARED ONLY; bootstrap prerequisite 001_roles.sql. No application tables.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL search_path TO pg_catalog;
DO $guard$
DECLARE
  name text;
  owner_oid oid;
  schema_owner oid;
BEGIN
  IF current_database() <> 'tomopedidos_local' OR session_user <> 'tomopedidos_bootstrap'
     OR current_user <> session_user
     OR NOT (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'B1 requires local bootstrap context';
  END IF;
  SELECT oid INTO STRICT owner_oid FROM pg_roles WHERE rolname = 'tp_owner';
  IF (SELECT count(*) FROM pg_roles WHERE rolname IN ('tp_owner','tomopedidos_migrator','tomopedidos_runtime'))<>3
     OR EXISTS (SELECT 1 FROM pg_roles WHERE rolname IN ('tp_owner','tomopedidos_migrator','tomopedidos_runtime')
                AND (rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls OR rolinherit
                     OR rolcanlogin<>(rolname<>'tp_owner')))
     OR NOT pg_has_role('tomopedidos_migrator','tp_owner','SET')
     OR pg_has_role('tomopedidos_migrator','tp_owner','USAGE')
     OR EXISTS (SELECT 1 FROM pg_auth_members m JOIN pg_roles member ON member.oid=m.member
                JOIN pg_roles granted ON granted.oid=m.roleid
                WHERE (member.rolname IN ('tp_owner','tomopedidos_migrator','tomopedidos_runtime') OR granted.rolname='tp_owner')
                  AND NOT (member.rolname='tomopedidos_migrator' AND granted.rolname='tp_owner'
                           AND m.set_option AND NOT m.inherit_option AND NOT m.admin_option)) THEN
    RAISE EXCEPTION '001 role baseline is missing or changed';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname=current_database()
                 AND datdba=(SELECT oid FROM pg_roles WHERE rolname=session_user)
                 AND NOT datistemplate) THEN RAISE EXCEPTION 'Unexpected database ownership'; END IF;
  IF EXISTS (SELECT 1 FROM pg_depend d JOIN pg_namespace n ON n.oid=d.refobjid
             WHERE d.refclassid='pg_namespace'::regclass AND n.nspname='public'
               AND d.classid<>'pg_default_acl'::regclass) THEN
    RAISE EXCEPTION 'public contains objects; review consumers before revoking access';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname='public' AND nspowner NOT IN
             (SELECT oid FROM pg_roles WHERE rolname IN ('pg_database_owner','tomopedidos_bootstrap'))) THEN
    RAISE EXCEPTION 'Unexpected public schema ownership';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_default_acl d CROSS JOIN LATERAL aclexplode(d.defaclacl) a
             WHERE d.defaclrole=owner_oid AND a.grantee NOT IN
               (0,owner_oid,(SELECT oid FROM pg_roles WHERE rolname='tomopedidos_migrator'),
                            (SELECT oid FROM pg_roles WHERE rolname='tomopedidos_runtime'))) THEN
    RAISE EXCEPTION 'Default privileges include unrelated grantees';
  END IF;
  FOREACH name IN ARRAY ARRAY['identity', 'tenancy', 'authorization', 'audit', 'migration_meta'] LOOP
    SELECT nspowner INTO schema_owner FROM pg_namespace WHERE nspname = name;
    IF FOUND AND schema_owner <> owner_oid THEN
      RAISE EXCEPTION 'Existing schema has another owner; no ownership takeover';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_depend d JOIN pg_namespace n ON n.oid=d.refobjid
               WHERE d.refclassid='pg_namespace'::regclass AND n.nspname=name
                 AND d.classid<>'pg_default_acl'::regclass) THEN
      RAISE EXCEPTION 'B1 schema contains objects; reapplication needs review';
    END IF;
  END LOOP;
END
$guard$;

CREATE SCHEMA IF NOT EXISTS identity AUTHORIZATION tp_owner;
CREATE SCHEMA IF NOT EXISTS tenancy AUTHORIZATION tp_owner;
CREATE SCHEMA IF NOT EXISTS "authorization" AUTHORIZATION tp_owner;
CREATE SCHEMA IF NOT EXISTS audit AUTHORIZATION tp_owner;
CREATE SCHEMA IF NOT EXISTS migration_meta AUTHORIZATION tp_owner;

REVOKE ALL ON DATABASE tomopedidos_local FROM PUBLIC, tomopedidos_migrator, tomopedidos_runtime;
GRANT CONNECT ON DATABASE tomopedidos_local TO tomopedidos_migrator, tomopedidos_runtime;
REVOKE ALL ON SCHEMA public FROM PUBLIC, tomopedidos_migrator, tomopedidos_runtime;
REVOKE ALL ON SCHEMA identity, tenancy, "authorization", audit, migration_meta
  FROM PUBLIC, tomopedidos_migrator, tomopedidos_runtime;
GRANT USAGE ON SCHEMA tenancy, "authorization" TO tomopedidos_runtime;
DO $schema_acl$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_namespace n CROSS JOIN LATERAL aclexplode(n.nspacl) a
             WHERE n.nspname IN ('identity','tenancy','authorization','audit','migration_meta')
               AND a.grantee NOT IN (n.nspowner,(SELECT oid FROM pg_roles WHERE rolname='tomopedidos_runtime'))) THEN
    RAISE EXCEPTION 'New schema inherited unrelated grants; transaction aborted';
  END IF;
END
$schema_acl$;

-- Defaults are tied to the creator tp_owner, not inherited automatically.
-- Global revoke is necessary to remove PostgreSQL's default PUBLIC function EXECUTE.
ALTER DEFAULT PRIVILEGES FOR ROLE tp_owner REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, tomopedidos_runtime;
ALTER DEFAULT PRIVILEGES FOR ROLE tp_owner REVOKE ALL ON TABLES FROM PUBLIC, tomopedidos_migrator, tomopedidos_runtime;
ALTER DEFAULT PRIVILEGES FOR ROLE tp_owner REVOKE ALL ON SEQUENCES FROM PUBLIC, tomopedidos_migrator, tomopedidos_runtime;
ALTER DEFAULT PRIVILEGES FOR ROLE tp_owner REVOKE ALL ON FUNCTIONS FROM tomopedidos_migrator;
ALTER DEFAULT PRIVILEGES FOR ROLE tp_owner IN SCHEMA identity, tenancy, "authorization", audit, migration_meta
  REVOKE ALL ON TABLES FROM PUBLIC, tomopedidos_migrator, tomopedidos_runtime;
ALTER DEFAULT PRIVILEGES FOR ROLE tp_owner IN SCHEMA identity, tenancy, "authorization", audit, migration_meta
  REVOKE ALL ON SEQUENCES FROM PUBLIC, tomopedidos_migrator, tomopedidos_runtime;
ALTER DEFAULT PRIVILEGES FOR ROLE tp_owner IN SCHEMA identity, tenancy, "authorization", audit, migration_meta
  REVOKE ALL ON FUNCTIONS FROM PUBLIC, tomopedidos_migrator, tomopedidos_runtime;

-- Migrator must SET ROLE tp_owner, including Goose connection options.
ALTER ROLE tomopedidos_migrator IN DATABASE tomopedidos_local SET search_path TO migration_meta, pg_catalog;
ALTER ROLE tomopedidos_runtime IN DATABASE tomopedidos_local SET search_path TO pg_catalog;
COMMIT;
