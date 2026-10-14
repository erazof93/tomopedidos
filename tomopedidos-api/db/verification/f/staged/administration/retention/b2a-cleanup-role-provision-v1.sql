-- F target-only staged copy; original hash is in stage-manifest.json.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
-- PREPARED ONLY. Proposed E actors; execution/provisioning requires separate approval.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL search_path TO pg_catalog;
\ir ../b2a-role-preflight.sql
DO $absent$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname IN
        ('tomopedidos_cleanup_executor','tomopedidos_session_maintenance')) THEN
        RAISE EXCEPTION 'Initial E role provisioning refuses existing roles';
    END IF;
END;
$absent$;
CREATE ROLE tomopedidos_cleanup_executor NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB
    NOCREATEROLE NOREPLICATION NOBYPASSRLS;
CREATE ROLE tomopedidos_session_maintenance LOGIN NOINHERIT NOSUPERUSER NOCREATEDB
    NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD NULL;
-- No CONNECT, membership, schema, table or function grants here. No credentials/HBA.
COMMIT;
