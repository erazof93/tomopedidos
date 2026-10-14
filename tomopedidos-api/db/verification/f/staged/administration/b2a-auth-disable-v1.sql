-- F target-only staged copy; original hash is in stage-manifest.json.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
-- D PREPARED ONLY: reverse caller activation, keep executor grants and C definitions.
-- No role drops, membership edits, DROP OWNED or CASCADE; does not cancel active calls.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL search_path TO pg_catalog;
SET LOCAL lock_timeout TO '1s';
SET LOCAL statement_timeout TO '2s';
\ir b2a-role-preflight.sql
SET LOCAL tomopedidos.d_stage TO 'enabled';
\ir b2a-assert-state.sql
REVOKE ALL ON FUNCTION identity.lookup_credential(text, text) FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
REVOKE ALL ON FUNCTION identity.issue_session(uuid, bigint, bigint, bigint, text, uuid, bytea, text, bytea) FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
REVOKE ALL ON FUNCTION identity.validate_session(bytea, text) FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
REVOKE ALL ON FUNCTION identity.record_activity(bytea, text) FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
REVOKE ALL ON FUNCTION identity.revoke_session(bytea, text) FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
REVOKE ALL ON FUNCTION identity.mark_expired(bytea, text) FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
REVOKE ALL ON FUNCTION identity.revoke_audience(bytea, text) FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
REVOKE ALL ON FUNCTION identity.revoke_global(bytea, text) FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
REVOKE ALL ON FUNCTION identity.rehash_conditional(uuid, bigint, text, text) FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
REVOKE CONNECT ON DATABASE tp_b2a_f_20261014_r01 FROM tomopedidos_auth_runtime;
REVOKE USAGE ON SCHEMA identity FROM tomopedidos_auth_runtime;
SET LOCAL tomopedidos.d_stage TO 'executors';
\ir b2a-assert-state.sql
COMMIT;