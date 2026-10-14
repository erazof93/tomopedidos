-- F target-only staged copy; original hash is in stage-manifest.json.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
-- PREPARED ONLY: apply manually after separate execution approval.
-- psql script, outside Goose migrations; no passwords or application tables.
\set ON_ERROR_STOP on
BEGIN;
DO $guard$
BEGIN
  IF current_database() <> 'tp_b2a_f_20261014_r01'
     OR session_user <> 'tomopedidos_bootstrap'
     OR current_user <> session_user
     OR NOT (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'B1 requires the local database and bootstrap superuser';
  END IF;
END
$guard$;
SET LOCAL search_path TO pg_catalog;
DO $database$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname=current_database()
                 AND datdba=(SELECT oid FROM pg_roles WHERE rolname=session_user)
                 AND NOT datistemplate) THEN
    RAISE EXCEPTION 'Unexpected database ownership';
  END IF;
END
$database$;

DO $roles$
DECLARE
  name text;
  existing record;
BEGIN
  FOREACH name IN ARRAY ARRAY['tp_owner', 'tomopedidos_migrator', 'tomopedidos_runtime'] LOOP
    SELECT * INTO existing FROM pg_roles WHERE rolname = name;
    IF FOUND THEN
      IF existing.rolsuper OR existing.rolcreatedb OR existing.rolcreaterole
         OR existing.rolreplication OR existing.rolbypassrls OR existing.rolinherit
         OR existing.rolcanlogin <> (name <> 'tp_owner') THEN
        RAISE EXCEPTION 'Existing B1 role attributes differ; explicit review required';
      END IF;
    ELSIF name = 'tp_owner' THEN
      CREATE ROLE tp_owner NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
    ELSIF name = 'tomopedidos_migrator' THEN
      CREATE ROLE tomopedidos_migrator LOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
    ELSE
      CREATE ROLE tomopedidos_runtime LOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
    END IF;
  END LOOP;
  IF EXISTS (
    SELECT 1 FROM pg_auth_members m JOIN pg_roles member ON member.oid = m.member
    JOIN pg_roles granted ON granted.oid = m.roleid
    WHERE member.rolname = 'tomopedidos_runtime'
       OR (member.rolname = 'tomopedidos_migrator' AND granted.rolname <> 'tp_owner')
       OR member.rolname = 'tp_owner'
       OR (granted.rolname = 'tp_owner' AND member.rolname <> 'tomopedidos_migrator')
  ) THEN
    RAISE EXCEPTION 'Unexpected B1 role membership; no automatic cleanup';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_database d JOIN pg_roles r ON r.oid = d.datdba
    WHERE r.rolname IN ('tp_owner', 'tomopedidos_migrator', 'tomopedidos_runtime')
  ) THEN
    RAISE EXCEPTION 'B1 role owns a database; explicit review required';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_auth_members m JOIN pg_roles r ON r.oid=m.member
             JOIN pg_roles owner ON owner.oid=m.roleid
             WHERE r.rolname='tomopedidos_migrator' AND owner.rolname='tp_owner'
               AND (m.admin_option OR m.inherit_option OR NOT m.set_option)) THEN
    RAISE EXCEPTION 'Existing owner membership options need review';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_shdepend d JOIN pg_roles r ON r.oid=d.refobjid
             WHERE d.refclassid='pg_authid'::regclass
               AND r.rolname IN ('tp_owner','tomopedidos_migrator','tomopedidos_runtime')
               AND d.dbid<>0 AND d.dbid<>(SELECT oid FROM pg_database WHERE datname=current_database())) THEN
    RAISE EXCEPTION 'B1 role is used in another database';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_parameter_acl p CROSS JOIN LATERAL aclexplode(p.paracl) a
             WHERE a.grantee=0 OR a.grantee IN
               (SELECT oid FROM pg_roles WHERE rolname IN ('tp_owner','tomopedidos_migrator','tomopedidos_runtime'))) THEN
    RAISE EXCEPTION 'Unexpected parameter privileges';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_namespace n JOIN pg_roles r ON r.oid=n.nspowner
             WHERE r.rolname='tp_owner' AND n.nspname NOT IN
               ('identity','tenancy','authorization','audit','migration_meta'))
     OR EXISTS (SELECT 1 FROM pg_shdepend d JOIN pg_roles r ON r.oid=d.refobjid
                WHERE d.refclassid='pg_authid'::regclass AND r.rolname='tp_owner'
                  AND d.dbid=(SELECT oid FROM pg_database WHERE datname=current_database())
                  AND d.deptype='o' AND d.classid NOT IN ('pg_namespace'::regclass,'pg_default_acl'::regclass)) THEN
    RAISE EXCEPTION 'Owner role already manages unrelated objects';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_shdepend d JOIN pg_roles r ON r.oid=d.refobjid
             WHERE d.refclassid='pg_authid'::regclass AND d.deptype='o'
               AND r.rolname IN ('tomopedidos_migrator','tomopedidos_runtime')) THEN
    RAISE EXCEPTION 'Login role owns existing objects; explicit review required';
  END IF;
END
$roles$;

-- Each option is explicit; runtime receives no membership.
GRANT tp_owner TO tomopedidos_migrator WITH ADMIN FALSE;
GRANT tp_owner TO tomopedidos_migrator WITH INHERIT FALSE;
GRANT tp_owner TO tomopedidos_migrator WITH SET TRUE;
COMMIT;
