-- PREPARED ONLY. Reverse executor grants only after caller is disabled and drained.
-- Preserves roles, C functions/ownership and A/B/B1; no destructive object cleanup.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL search_path TO pg_catalog;
SET LOCAL lock_timeout TO '1s';
SET LOCAL statement_timeout TO '2s';
\ir b2a-role-preflight.sql
SET LOCAL tomopedidos.d_stage TO 'executors';
\ir b2a-assert-state.sql
REVOKE SELECT (id,email_canonical,status,email_verified_at,auth_epoch,credential_revision,created_at) ON TABLE identity.identities FROM tomopedidos_auth_executor;
REVOKE UPDATE (credential_revision) ON TABLE identity.identities FROM tomopedidos_auth_executor;
REVOKE SELECT (identity_id,password_hash) ON TABLE identity.identity_credentials FROM tomopedidos_auth_executor;
REVOKE UPDATE (password_hash,changed_at) ON TABLE identity.identity_credentials FROM tomopedidos_auth_executor;
REVOKE SELECT (identity_id,audience,auth_epoch) ON TABLE identity.audience_revocations FROM tomopedidos_auth_executor;
REVOKE UPDATE (audience) ON TABLE identity.audience_revocations FROM tomopedidos_auth_executor;
REVOKE SELECT (session_id,identity_id,audience,token_hash,identity_epoch,audience_epoch,authentication_level,csrf_key_id,csrf_generation,csrf_salt,created_at,last_activity_at,idle_expires_at,absolute_expires_at,revoked_at,expired_at) ON TABLE identity.sessions FROM tomopedidos_auth_executor;
REVOKE INSERT (session_id,identity_id,audience,token_hash,identity_epoch,audience_epoch,authentication_level,csrf_key_id,csrf_generation,csrf_salt,created_at,last_activity_at,idle_expires_at,absolute_expires_at) ON TABLE identity.sessions FROM tomopedidos_auth_executor;
REVOKE UPDATE (last_activity_at,idle_expires_at,revoked_at,expired_at) ON TABLE identity.sessions FROM tomopedidos_auth_executor;
REVOKE SELECT (id,status,email_verified_at,auth_epoch,credential_revision,created_at) ON TABLE identity.identities FROM tomopedidos_auth_revoke_executor;
REVOKE UPDATE (auth_epoch) ON TABLE identity.identities FROM tomopedidos_auth_revoke_executor;
REVOKE SELECT (identity_id,audience,auth_epoch) ON TABLE identity.audience_revocations FROM tomopedidos_auth_revoke_executor;
REVOKE UPDATE (auth_epoch) ON TABLE identity.audience_revocations FROM tomopedidos_auth_revoke_executor;
REVOKE SELECT (session_id,identity_id,audience,token_hash,identity_epoch,audience_epoch,authentication_level,csrf_key_id,csrf_generation,csrf_salt,created_at,last_activity_at,idle_expires_at,absolute_expires_at,revoked_at,expired_at) ON TABLE identity.sessions FROM tomopedidos_auth_revoke_executor;
REVOKE UPDATE (expired_at) ON TABLE identity.sessions FROM tomopedidos_auth_revoke_executor;
REVOKE USAGE ON SCHEMA identity FROM tomopedidos_auth_executor, tomopedidos_auth_revoke_executor;
SET LOCAL tomopedidos.d_stage TO 'c';
\ir b2a-assert-state.sql
COMMIT;