-- F target-only staged copy; original hash is in stage-manifest.json.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
-- PREPARED ONLY. Administrative Down, not a Goose Down or data restoration.
-- Requires disabled/drained job. Preserve roles and A-D/B1, no CASCADE.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL search_path TO pg_catalog;
\ir ../b2a-role-preflight.sql
SET LOCAL tomopedidos.e_stage TO 'dormant';
\ir b2a-cleanup-assert.sql
DROP FUNCTION identity.cleanup_sessions(integer);
REVOKE SELECT (id), UPDATE (id) ON TABLE identity.identities FROM tomopedidos_cleanup_executor;
REVOKE SELECT (identity_id,audience), UPDATE (audience)
ON TABLE identity.audience_revocations FROM tomopedidos_cleanup_executor;
REVOKE SELECT (session_id,identity_id,audience,created_at,last_activity_at,idle_expires_at,absolute_expires_at,revoked_at,expired_at),
    UPDATE (session_id), DELETE ON TABLE identity.sessions FROM tomopedidos_cleanup_executor;
REVOKE USAGE ON SCHEMA identity FROM tomopedidos_cleanup_executor;
DO $down$
BEGIN
    IF to_regprocedure('identity.cleanup_sessions(integer)') IS NOT NULL
        OR has_schema_privilege('tomopedidos_cleanup_executor','identity','USAGE')
        OR has_table_privilege('tomopedidos_cleanup_executor','identity.sessions','DELETE')
        OR has_any_column_privilege('tomopedidos_cleanup_executor','identity.sessions','SELECT,INSERT,UPDATE,REFERENCES')
        OR has_any_column_privilege('tomopedidos_cleanup_executor','identity.identities','SELECT,INSERT,UPDATE,REFERENCES')
        OR has_any_column_privilege('tomopedidos_cleanup_executor','identity.audience_revocations','SELECT,INSERT,UPDATE,REFERENCES') THEN
        RAISE EXCEPTION 'E Down left unexpected privileges/function';
    END IF;
END;
$down$;
-- Then 00004 Down separately, when authorized. Role removal requires cluster inventory.
COMMIT;
