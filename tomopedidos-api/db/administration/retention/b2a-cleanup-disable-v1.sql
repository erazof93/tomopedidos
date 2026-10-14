-- PREPARED ONLY. Drain job/connections first; revocation does not cancel active calls.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL search_path TO pg_catalog;
\ir ../b2a-role-preflight.sql
SET LOCAL tomopedidos.e_stage TO 'enabled';
\ir b2a-cleanup-assert.sql
REVOKE EXECUTE ON FUNCTION identity.cleanup_sessions(integer) FROM tomopedidos_session_maintenance;
REVOKE CONNECT ON DATABASE tomopedidos_local FROM tomopedidos_session_maintenance;
REVOKE USAGE ON SCHEMA identity FROM tomopedidos_session_maintenance;
SET LOCAL tomopedidos.e_stage TO 'dormant';
\ir b2a-cleanup-assert.sql
COMMIT;
