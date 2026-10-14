-- F target-only staged copy; original hash is in stage-manifest.json.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
-- PREPARED ONLY. Initial role provisioning, outside Goose and B1.
-- Roles are cluster-wide. Separate authorization and isolated target required.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL search_path TO pg_catalog;
SET LOCAL lock_timeout TO '1s';
SET LOCAL statement_timeout TO '2s';
\ir b2a-role-preflight.sql
DO $absent$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname IN
        ('tomopedidos_auth_executor','tomopedidos_auth_revoke_executor','tomopedidos_auth_runtime')) THEN
        RAISE EXCEPTION 'Initial provisioning refuses existing D roles; inspect drift, do not rerun';
    END IF;
END;
$absent$;
CREATE ROLE tomopedidos_auth_executor NOLOGIN NOINHERIT NOSUPERUSER
    NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
CREATE ROLE tomopedidos_auth_revoke_executor NOLOGIN NOINHERIT NOSUPERUSER
    NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
-- LOGIN is the approved role attribute, not an authentication setup.
-- No password, CONNECT, schema privileges, memberships or caller EXECUTE yet.
CREATE ROLE tomopedidos_auth_runtime LOGIN NOINHERIT NOSUPERUSER
    NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD NULL;
DO $verify$
BEGIN
    IF (SELECT count(*) FROM pg_catalog.pg_roles WHERE rolname IN
        ('tomopedidos_auth_executor','tomopedidos_auth_revoke_executor','tomopedidos_auth_runtime')
        AND NOT rolsuper AND NOT rolcreatedb AND NOT rolcreaterole
        AND NOT rolreplication AND NOT rolbypassrls AND NOT rolinherit
        AND rolcanlogin = (rolname = 'tomopedidos_auth_runtime')) <> 3 THEN
        RAISE EXCEPTION 'Provisioning attribute assertion failed';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_auth_members AS m
        JOIN pg_catalog.pg_roles AS r ON r.oid IN (m.member,m.roleid)
        WHERE r.rolname IN ('tomopedidos_auth_executor','tomopedidos_auth_revoke_executor','tomopedidos_auth_runtime'))
        OR pg_catalog.has_database_privilege('tomopedidos_auth_runtime','tp_b2a_f_20261014_r01','CONNECT') THEN
        RAISE EXCEPTION 'Provisioning must not enable membership or connectivity';
    END IF;
END;
$verify$;
COMMIT;
