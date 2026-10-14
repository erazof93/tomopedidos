-- D PREPARED ONLY. Separate authorization after executor/isolation test evidence.
-- Never combine blindly with grants/install; trusted Go and credentials remain separate.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL search_path TO pg_catalog;
SET LOCAL lock_timeout TO '1s';
SET LOCAL statement_timeout TO '2s';
\ir b2a-role-preflight.sql
SET LOCAL tomopedidos.d_stage TO 'executors';
\ir b2a-assert-state.sql
GRANT CONNECT ON DATABASE tomopedidos_local TO tomopedidos_auth_runtime;
GRANT USAGE ON SCHEMA identity TO tomopedidos_auth_runtime;
REVOKE ALL ON FUNCTION identity.lookup_credential(text, text) FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
REVOKE ALL ON FUNCTION identity.issue_session(uuid, bigint, bigint, bigint, text, uuid, bytea, text, bytea) FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
REVOKE ALL ON FUNCTION identity.validate_session(bytea, text) FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
REVOKE ALL ON FUNCTION identity.record_activity(bytea, text) FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
REVOKE ALL ON FUNCTION identity.revoke_session(bytea, text) FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
REVOKE ALL ON FUNCTION identity.mark_expired(bytea, text) FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
REVOKE ALL ON FUNCTION identity.revoke_audience(bytea, text) FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
REVOKE ALL ON FUNCTION identity.revoke_global(bytea, text) FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
REVOKE ALL ON FUNCTION identity.rehash_conditional(uuid, bigint, text, text) FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
GRANT EXECUTE ON FUNCTION identity.lookup_credential(text, text) TO tomopedidos_auth_runtime;
GRANT EXECUTE ON FUNCTION identity.issue_session(uuid, bigint, bigint, bigint, text, uuid, bytea, text, bytea) TO tomopedidos_auth_runtime;
GRANT EXECUTE ON FUNCTION identity.validate_session(bytea, text) TO tomopedidos_auth_runtime;
GRANT EXECUTE ON FUNCTION identity.record_activity(bytea, text) TO tomopedidos_auth_runtime;
GRANT EXECUTE ON FUNCTION identity.revoke_session(bytea, text) TO tomopedidos_auth_runtime;
GRANT EXECUTE ON FUNCTION identity.mark_expired(bytea, text) TO tomopedidos_auth_runtime;
GRANT EXECUTE ON FUNCTION identity.rehash_conditional(uuid, bigint, text, text) TO tomopedidos_auth_runtime;
SET LOCAL tomopedidos.d_stage TO 'enabled';
\ir b2a-assert-state.sql
COMMIT;