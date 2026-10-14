-- D PREPARED ONLY: executor column permissions; does not enable caller.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL search_path TO pg_catalog;
SET LOCAL lock_timeout TO '1s';
SET LOCAL statement_timeout TO '2s';
\ir b2a-role-preflight.sql
SET LOCAL tomopedidos.d_stage TO 'c';
\ir b2a-assert-state.sql
GRANT USAGE ON SCHEMA identity TO tomopedidos_auth_executor, tomopedidos_auth_revoke_executor;
-- FOR SHARE/UPDATE needs SELECT and UPDATE on at least one column.
-- audience is lock-only: B's guard prevents rekeying. No audience epoch to normal owner.
GRANT SELECT (id,email_canonical,status,email_verified_at,auth_epoch,credential_revision,created_at) ON TABLE identity.identities TO tomopedidos_auth_executor;
GRANT UPDATE (credential_revision) ON TABLE identity.identities TO tomopedidos_auth_executor;
GRANT SELECT (identity_id,password_hash) ON TABLE identity.identity_credentials TO tomopedidos_auth_executor;
GRANT UPDATE (password_hash,changed_at) ON TABLE identity.identity_credentials TO tomopedidos_auth_executor;
GRANT SELECT (identity_id,audience,auth_epoch) ON TABLE identity.audience_revocations TO tomopedidos_auth_executor;
GRANT UPDATE (audience) ON TABLE identity.audience_revocations TO tomopedidos_auth_executor;
GRANT SELECT (session_id,identity_id,audience,token_hash,identity_epoch,audience_epoch,authentication_level,csrf_key_id,csrf_generation,csrf_salt,created_at,last_activity_at,idle_expires_at,absolute_expires_at,revoked_at,expired_at) ON TABLE identity.sessions TO tomopedidos_auth_executor;
GRANT INSERT (session_id,identity_id,audience,token_hash,identity_epoch,audience_epoch,authentication_level,csrf_key_id,csrf_generation,csrf_salt,created_at,last_activity_at,idle_expires_at,absolute_expires_at) ON TABLE identity.sessions TO tomopedidos_auth_executor;
GRANT UPDATE (last_activity_at,idle_expires_at,revoked_at,expired_at) ON TABLE identity.sessions TO tomopedidos_auth_executor;
GRANT SELECT (id,status,email_verified_at,auth_epoch,credential_revision,created_at) ON TABLE identity.identities TO tomopedidos_auth_revoke_executor;
GRANT UPDATE (auth_epoch) ON TABLE identity.identities TO tomopedidos_auth_revoke_executor;
GRANT SELECT (identity_id,audience,auth_epoch) ON TABLE identity.audience_revocations TO tomopedidos_auth_revoke_executor;
GRANT UPDATE (auth_epoch) ON TABLE identity.audience_revocations TO tomopedidos_auth_revoke_executor;
GRANT SELECT (session_id,identity_id,audience,token_hash,identity_epoch,audience_epoch,authentication_level,csrf_key_id,csrf_generation,csrf_salt,created_at,last_activity_at,idle_expires_at,absolute_expires_at,revoked_at,expired_at) ON TABLE identity.sessions TO tomopedidos_auth_revoke_executor;
GRANT UPDATE (expired_at) ON TABLE identity.sessions TO tomopedidos_auth_revoke_executor;
REVOKE ALL ON FUNCTION identity.lookup_credential(text, text) FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
REVOKE ALL ON FUNCTION identity.issue_session(uuid, bigint, bigint, bigint, text, uuid, bytea, text, bytea) FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
REVOKE ALL ON FUNCTION identity.validate_session(bytea, text) FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
REVOKE ALL ON FUNCTION identity.record_activity(bytea, text) FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
REVOKE ALL ON FUNCTION identity.revoke_session(bytea, text) FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
REVOKE ALL ON FUNCTION identity.mark_expired(bytea, text) FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
REVOKE ALL ON FUNCTION identity.revoke_audience(bytea, text) FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
REVOKE ALL ON FUNCTION identity.revoke_global(bytea, text) FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
REVOKE ALL ON FUNCTION identity.rehash_conditional(uuid, bigint, text, text) FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
SET LOCAL tomopedidos.d_stage TO 'executors';
\ir b2a-assert-state.sql
COMMIT;