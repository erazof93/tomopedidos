-- E initial administrative install only, outside Goose. PREPARED, NOT EXECUTED.
-- Roles provisioned separately; index 00004 and A-D certified before application.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL search_path TO pg_catalog;
SET LOCAL lock_timeout TO '1s';
SET LOCAL statement_timeout TO '2s';
\ir ../b2a-role-preflight.sql
SET LOCAL tomopedidos.d_stage TO 'enabled';
\ir ../b2a-assert-state.sql
DO $initial$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_proc AS p JOIN pg_namespace AS n ON n.oid = p.pronamespace
               WHERE n.nspname = 'identity' AND p.proname = 'cleanup_sessions') THEN
        RAISE EXCEPTION 'Initial E install refuses existing names/overloads';
    END IF;
    IF (SELECT count(*) FROM pg_roles WHERE rolname IN
        ('tomopedidos_cleanup_executor','tomopedidos_session_maintenance')
        AND NOT rolsuper AND NOT rolcreatedb AND NOT rolcreaterole AND NOT rolreplication
        AND NOT rolbypassrls AND NOT rolinherit
        AND rolcanlogin = (rolname = 'tomopedidos_session_maintenance')) <> 2
        OR EXISTS (SELECT 1 FROM pg_auth_members AS m JOIN pg_roles AS r ON r.oid IN (m.member,m.roleid)
                   WHERE r.rolname IN ('tomopedidos_cleanup_executor','tomopedidos_session_maintenance')) THEN
        RAISE EXCEPTION 'E roles must be separately provisioned minimal roles without memberships';
    END IF;
END;
$initial$;

CREATE FUNCTION identity.cleanup_sessions(p_batch_size integer DEFAULT 100)
RETURNS TABLE (examined integer, deleted integer, skipped integer, checked_at timestamptz)
LANGUAGE plpgsql
VOLATILE
PARALLEL UNSAFE
SECURITY DEFINER
SET search_path TO pg_catalog, pg_temp
AS $cleanup$
DECLARE
    v_ids uuid[];
    v_locked_identities uuid[] := ARRAY[]::uuid[];
    v_locked_audiences text[] := ARRAY[]::text[];
    v_parent record;
    v_s record;
    v_discovery_now timestamptz;
    v_now timestamptz;
    v_clock_floor timestamptz;
    v_count integer;
BEGIN
    IF pg_catalog.current_setting('transaction_isolation') <> 'read committed' THEN
        RAISE EXCEPTION USING ERRCODE = '25000', MESSAGE = 'Cleanup requires READ COMMITTED';
    END IF;
    IF p_batch_size IS NULL OR p_batch_size NOT BETWEEN 1 AND 100 THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Cleanup batch must be between 1 and 100';
    END IF;
    -- One cleanup call per transaction. This marker is a misuse guard, not authority.
    IF pg_catalog.current_setting('tomopedidos.cleanup_called', true) = 'yes' THEN
        RAISE EXCEPTION USING ERRCODE = '25000', MESSAGE = 'Cleanup requires a new transaction per batch';
    END IF;
    PERFORM pg_catalog.set_config('tomopedidos.cleanup_called', 'yes', true);
    v_discovery_now := pg_catalog.clock_timestamp();
    v_clock_floor := v_discovery_now;
    -- Bounded discovery, no row locks and no authorization to delete.
    -- No epoch-derived timestamp; optional marks do not postpone natural expiry.
    v_ids := ARRAY(
        SELECT s.session_id FROM identity.sessions AS s
        WHERE LEAST(s.idle_expires_at, s.absolute_expires_at, s.revoked_at, s.expired_at)
            <= v_discovery_now - INTERVAL '2592000 seconds'
        ORDER BY LEAST(s.idle_expires_at, s.absolute_expires_at, s.revoked_at, s.expired_at), s.session_id
        LIMIT p_batch_size
    );
    examined := pg_catalog.cardinality(v_ids);
    deleted := 0;
    -- Global phases, not Identity->audience->session repeated per candidate:
    -- no new parent locks after a session lock. UUID/text ordering is stable.
    FOR v_parent IN
        SELECT i.id FROM identity.identities AS i
        WHERE i.id IN (SELECT s.identity_id FROM identity.sessions AS s WHERE s.session_id = ANY(v_ids))
        ORDER BY i.id FOR SHARE
    LOOP
        v_locked_identities := pg_catalog.array_append(v_locked_identities, v_parent.id);
    END LOOP;
    FOR v_parent IN
        SELECT a.identity_id, a.audience FROM identity.audience_revocations AS a
        WHERE EXISTS (SELECT 1 FROM identity.sessions AS s WHERE s.session_id = ANY(v_ids)
                      AND s.identity_id = a.identity_id AND s.audience = a.audience)
        ORDER BY a.identity_id, a.audience COLLATE "C" FOR SHARE
    LOOP
        v_locked_audiences := pg_catalog.array_append(v_locked_audiences,
            v_parent.identity_id::text || '/' || v_parent.audience);
    END LOOP;
    FOR v_s IN
        SELECT s.session_id, s.identity_id, s.audience, s.created_at, s.last_activity_at,
               s.idle_expires_at, s.absolute_expires_at, s.revoked_at, s.expired_at
        FROM identity.sessions AS s WHERE s.session_id = ANY(v_ids)
        ORDER BY s.session_id FOR UPDATE
    LOOP
        IF NOT (v_s.identity_id = ANY(v_locked_identities))
            OR NOT ((v_s.identity_id::text || '/' || v_s.audience) = ANY(v_locked_audiences)) THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Cleanup parent lock evidence missing';
        END IF;
        v_now := pg_catalog.clock_timestamp();
        IF v_now < v_clock_floor OR v_now < v_s.created_at OR v_now < v_s.last_activity_at
            OR (v_s.revoked_at IS NOT NULL AND v_now < v_s.revoked_at)
            OR (v_s.expired_at IS NOT NULL AND v_now < v_s.expired_at) THEN
            RAISE EXCEPTION USING ERRCODE = '22008', MESSAGE = 'Cleanup clock anomaly';
        END IF;
        v_clock_floor := v_now;
        -- Re-read values after waits. A legitimate prior renewal changes this test.
        IF LEAST(v_s.idle_expires_at, v_s.absolute_expires_at, v_s.revoked_at, v_s.expired_at)
            <= v_now - INTERVAL '2592000 seconds' THEN
            DELETE FROM identity.sessions AS s
            WHERE s.session_id = v_s.session_id
              AND s.identity_id = v_s.identity_id AND s.audience = v_s.audience
              AND LEAST(s.idle_expires_at, s.absolute_expires_at, s.revoked_at, s.expired_at)
                    <= v_now - INTERVAL '2592000 seconds';
            GET DIAGNOSTICS v_count = ROW_COUNT;
            deleted := deleted + v_count;
        END IF;
    END LOOP;
    skipped := examined - deleted;
    checked_at := pg_catalog.clock_timestamp();
    IF checked_at < v_clock_floor THEN
        RAISE EXCEPTION USING ERRCODE = '22008', MESSAGE = 'Cleanup clock anomaly';
    END IF;
    RETURN NEXT;
    -- No exception swallowing/retries. Any error rolls back the entire call.
    -- Caller reports counts only after confirmed COMMIT, never after ambiguous commit.
END;
$cleanup$;
REVOKE ALL ON FUNCTION identity.cleanup_sessions(integer)
FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator,
    tomopedidos_session_maintenance;
ALTER FUNCTION identity.cleanup_sessions(integer) OWNER TO tomopedidos_cleanup_executor;

GRANT USAGE ON SCHEMA identity TO tomopedidos_cleanup_executor;
GRANT SELECT (id), UPDATE (id) ON TABLE identity.identities TO tomopedidos_cleanup_executor;
GRANT SELECT (identity_id,audience), UPDATE (audience)
ON TABLE identity.audience_revocations TO tomopedidos_cleanup_executor;
GRANT SELECT (session_id,identity_id,audience,created_at,last_activity_at,idle_expires_at,absolute_expires_at,revoked_at,expired_at),
    UPDATE (session_id), DELETE ON TABLE identity.sessions TO tomopedidos_cleanup_executor;
-- UPDATE keys only supports row locks; B guards prohibit changing keys.
-- No credential/PHC/token_hash/CSRF/epoch SELECT or UPDATE; no data UPDATE in function.
SET LOCAL tomopedidos.e_stage TO 'dormant';
\ir b2a-cleanup-assert.sql
\ir ../b2a-assert-state.sql
COMMIT;
