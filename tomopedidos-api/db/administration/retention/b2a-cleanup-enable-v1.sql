-- PREPARED ONLY. Enable only after authorized fixtures/privilege/concurrency evidence.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL search_path TO pg_catalog;
\ir ../b2a-role-preflight.sql
SET LOCAL tomopedidos.d_stage TO 'enabled';
\ir ../b2a-assert-state.sql
SET LOCAL tomopedidos.e_stage TO 'dormant';
\ir b2a-cleanup-assert.sql
GRANT CONNECT ON DATABASE tomopedidos_local TO tomopedidos_session_maintenance;
GRANT USAGE ON SCHEMA identity TO tomopedidos_session_maintenance;
GRANT EXECUTE ON FUNCTION identity.cleanup_sessions(integer) TO tomopedidos_session_maintenance;
SET LOCAL tomopedidos.e_stage TO 'enabled';
\ir b2a-cleanup-assert.sql
COMMIT;
