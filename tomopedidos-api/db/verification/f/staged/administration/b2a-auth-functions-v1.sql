-- F target-only staged copy; original hash is in stage-manifest.json.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
-- B2-A delivery C / administrative package v1, INITIAL INSTALL ONLY.
-- NOT a Goose migration. NOT applied or verified by writing this file.
-- Requires separate authorization, local administrator, A/B applied and the
-- separately provisioned roles in the manifest. No role provisioning or GRANT.
-- D enables callers only after independent ownership/ACL/isolation verification.
-- Never use function arguments/results in logs: PHCs/digests are sensitive.
BEGIN;
SET LOCAL search_path TO pg_catalog;
SET LOCAL lock_timeout TO '1s';
SET LOCAL statement_timeout TO '2s';
SET LOCAL idle_in_transaction_session_timeout TO '1s';

DO $preflight$
DECLARE
    v_role record;
BEGIN
    IF pg_catalog.current_database() <> 'tp_b2a_f_20261014_r01'
        OR session_user <> 'tomopedidos_bootstrap'
        OR current_user <> session_user
        OR pg_catalog.current_setting('server_version_num')::integer / 100 <> 1800
        OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles AS r
                       WHERE r.rolname = session_user AND r.rolsuper) THEN
        RAISE EXCEPTION 'C v1 requires the explicitly authorized local administrator';
    END IF;
    IF pg_catalog.current_setting('transaction_isolation') <> 'read committed' THEN
        RAISE EXCEPTION 'C v1 requires READ COMMITTED';
    END IF;
    IF pg_catalog.to_regclass('identity.identities') IS NULL
        OR pg_catalog.to_regclass('identity.identity_credentials') IS NULL
        OR pg_catalog.to_regclass('identity.audience_revocations') IS NULL
        OR pg_catalog.to_regclass('identity.sessions') IS NULL THEN
        RAISE EXCEPTION 'A tables are missing';
    END IF;
    IF (SELECT pg_catalog.count(*) FROM pg_catalog.pg_class AS c
        JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
        JOIN pg_catalog.pg_roles AS r ON r.oid = c.relowner
        WHERE n.nspname = 'identity' AND c.relname IN
            ('identities','identity_credentials','audience_revocations','sessions')
          AND c.relkind = 'r' AND r.rolname = 'tp_owner') <> 4 THEN
        RAISE EXCEPTION 'Unexpected table ownership or relation kind';
    END IF;
    IF (SELECT pg_catalog.count(*) FROM pg_catalog.pg_trigger AS t
        JOIN pg_catalog.pg_class AS c ON c.oid = t.tgrelid
        JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
        WHERE n.nspname = 'identity' AND NOT t.tgisinternal AND t.tgenabled = 'O'
          AND ((c.relname = 'identities' AND t.tgname = 'trg_identities_update_guard')
            OR (c.relname = 'audience_revocations'
                AND t.tgname = 'trg_audience_revocations_update_guard')
            OR (c.relname = 'sessions' AND t.tgname = 'trg_sessions_update_guard'))) <> 3 THEN
        RAISE EXCEPTION 'B guards are missing or disabled';
    END IF;
    FOR v_role IN SELECT expected.name, expected.login, r.*
        FROM (VALUES ('tomopedidos_auth_executor', false),
                     ('tomopedidos_auth_revoke_executor', false),
                     ('tomopedidos_auth_runtime', true)) AS expected(name, login)
        LEFT JOIN pg_catalog.pg_roles AS r ON r.rolname = expected.name
    LOOP
        IF v_role.oid IS NULL OR v_role.rolcanlogin IS DISTINCT FROM v_role.login
            OR v_role.rolsuper OR v_role.rolcreatedb OR v_role.rolcreaterole
            OR v_role.rolreplication OR v_role.rolbypassrls OR v_role.rolinherit THEN
            RAISE EXCEPTION 'C role prerequisites are not satisfied';
        END IF;
        IF EXISTS (SELECT 1 FROM pg_catalog.pg_auth_members AS m
                   WHERE m.member = v_role.oid OR m.roleid = v_role.oid)
            OR pg_catalog.has_schema_privilege(v_role.oid, 'identity', 'CREATE') THEN
            RAISE EXCEPTION 'C roles must have no memberships or schema CREATE';
        END IF;
    END LOOP;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_proc AS p
               JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
               WHERE n.nspname = 'identity' AND p.proname IN (
                   'lookup_credential', 'issue_session', 'validate_session', 'record_activity', 'revoke_session', 'mark_expired', 'revoke_audience', 'revoke_global', 'rehash_conditional')) THEN
        RAISE EXCEPTION 'Initial install refuses existing names/overloads; use reviewed upgrade package';
    END IF;
END;
$preflight$;

-- Internal PHC/evidence only; no authentication decision or external response.
CREATE FUNCTION identity.lookup_credential(
    p_email_canonical text,
    p_audience text
)
RETURNS TABLE (identity_id uuid, password_hash text, credential_revision bigint,
    identity_epoch bigint, audience_epoch bigint)
LANGUAGE plpgsql
VOLATILE
PARALLEL UNSAFE
SECURITY DEFINER
SET search_path TO pg_catalog, pg_temp
AS $function$
BEGIN
    IF pg_catalog.current_setting('transaction_isolation') <> 'read committed' THEN
        RAISE EXCEPTION USING ERRCODE = '25000', MESSAGE = 'READ COMMITTED is required';
    END IF;
    IF p_email_canonical IS NULL OR p_audience IS NULL
        OR p_audience NOT IN ('admin', 'platform') THEN RETURN; END IF;
    RETURN QUERY
    SELECT i.id, c.password_hash, i.credential_revision, i.auth_epoch, a.auth_epoch
    FROM identity.identities AS i
    JOIN identity.identity_credentials AS c ON c.identity_id = i.id
    JOIN identity.audience_revocations AS a
      ON a.identity_id = i.id AND a.audience = p_audience
    WHERE i.email_canonical = p_email_canonical COLLATE "C"
      AND i.status = 'active' AND i.email_verified_at IS NOT NULL
      AND EXISTS (SELECT 1 FROM identity.audience_revocations AS ar
                  WHERE ar.identity_id = i.id AND ar.audience = 'admin')
      AND EXISTS (SELECT 1 FROM identity.audience_revocations AS ar
                  WHERE ar.identity_id = i.id AND ar.audience = 'platform');
END;
$function$;
REVOKE ALL ON FUNCTION identity.lookup_credential(text, text)
FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
ALTER FUNCTION identity.lookup_credential(text, text) OWNER TO tomopedidos_auth_executor;

-- Opaque bytes generated/digested in Go; no secret returned, even on success.
CREATE FUNCTION identity.issue_session(
    p_identity_id uuid,
    p_expected_revision bigint,
    p_expected_identity_epoch bigint,
    p_expected_audience_epoch bigint,
    p_audience text,
    p_session_id uuid,
    p_digest bytea,
    p_csrf_key_id text,
    p_csrf_salt bytea
)
RETURNS TABLE (result text, session_id uuid, created_at timestamptz,
    idle_expires_at timestamptz, absolute_expires_at timestamptz)
LANGUAGE plpgsql
VOLATILE
PARALLEL UNSAFE
SECURITY DEFINER
SET search_path TO pg_catalog, pg_temp
AS $function$
DECLARE
    v_i identity.identities%ROWTYPE;
    v_a identity.audience_revocations%ROWTYPE;
    v_now timestamptz;
BEGIN
    IF pg_catalog.current_setting('transaction_isolation') <> 'read committed' THEN
        RAISE EXCEPTION USING ERRCODE = '25000', MESSAGE = 'READ COMMITTED is required';
    END IF;
    -- The caller verified Argon2id outside this transaction. No MFA issuer in B2.
    IF p_identity_id IS NULL OR p_expected_revision IS NULL
        OR p_expected_identity_epoch IS NULL OR p_expected_audience_epoch IS NULL
        OR p_audience IS DISTINCT FROM 'admin' THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;
    IF p_session_id IS NULL OR p_digest IS NULL
        OR pg_catalog.octet_length(p_digest) <> 32 OR p_csrf_salt IS NULL
        OR pg_catalog.octet_length(p_csrf_salt) <> 32 OR p_csrf_key_id IS NULL
        OR pg_catalog.octet_length(p_csrf_key_id) NOT BETWEEN 1 AND 32
        OR p_csrf_key_id COLLATE "C" !~ $key$\A[A-Za-z0-9_-]+\Z$key$
        OR pg_catalog.substr(p_session_id::text, 15, 1) <> '4'
        OR pg_catalog.substr(p_session_id::text, 20, 1) NOT IN ('8','9','a','b') THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;
    SELECT i.id, i.status, i.email_verified_at, i.auth_epoch,
           i.credential_revision, i.created_at
    INTO v_i.id, v_i.status, v_i.email_verified_at, v_i.auth_epoch,
         v_i.credential_revision, v_i.created_at
    FROM identity.identities AS i WHERE i.id = p_identity_id FOR SHARE;
    IF NOT FOUND THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;
    SELECT a.* INTO v_a FROM identity.audience_revocations AS a
    WHERE a.identity_id = v_i.id AND a.audience = p_audience FOR SHARE;
    IF NOT FOUND THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;
    v_now := pg_catalog.clock_timestamp();
    IF v_now < v_i.created_at THEN
        result := 'clock_anomaly'; RETURN NEXT; RETURN;
    END IF;
    IF v_i.status <> 'active' OR v_i.email_verified_at IS NULL
        OR v_i.credential_revision <> p_expected_revision
        OR v_i.auth_epoch <> p_expected_identity_epoch
        OR v_a.auth_epoch <> p_expected_audience_epoch
        OR NOT EXISTS (SELECT 1 FROM identity.identity_credentials AS c
                       WHERE c.identity_id = v_i.id)
        OR NOT EXISTS (SELECT 1 FROM identity.audience_revocations AS a
                       WHERE a.identity_id = v_i.id AND a.audience = 'platform') THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;
    INSERT INTO identity.sessions (
        session_id, identity_id, audience, token_hash, identity_epoch, audience_epoch,
        authentication_level, csrf_key_id, csrf_generation, csrf_salt, created_at,
        last_activity_at, idle_expires_at, absolute_expires_at
    ) VALUES (
        p_session_id, v_i.id, p_audience, p_digest, v_i.auth_epoch, v_a.auth_epoch,
        'password', p_csrf_key_id, 1, p_csrf_salt, v_now, v_now,
        v_now + INTERVAL '43200 seconds', v_now + INTERVAL '604800 seconds'
    );
    result := 'issued'; session_id := p_session_id; created_at := v_now;
    idle_expires_at := v_now + INTERVAL '43200 seconds';
    absolute_expires_at := v_now + INTERVAL '604800 seconds';
    RETURN NEXT;
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION USING ERRCODE = '23505', MESSAGE = 'Session insertion conflict';
    WHEN check_violation OR not_null_violation OR foreign_key_violation THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Session insertion rejected';
END;
$function$;
REVOKE ALL ON FUNCTION identity.issue_session(uuid, bigint, bigint, bigint, text, uuid, bytea, text, bytea)
FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
ALTER FUNCTION identity.issue_session(uuid, bigint, bigint, bigint, text, uuid, bytea, text, bytea) OWNER TO tomopedidos_auth_executor;

-- One operation per short transaction; any result is provisional until COMMIT.
CREATE FUNCTION identity.validate_session(
    p_digest bytea,
    p_audience text
)
RETURNS TABLE (
    result text, session_id uuid, identity_id uuid, audience text,
    authentication_level text, csrf_key_id text, csrf_generation bigint,
    csrf_salt bytea, checked_at timestamptz, idle_expires_at timestamptz,
    absolute_expires_at timestamptz, current_identity_epoch bigint,
    current_audience_epoch bigint
)
LANGUAGE plpgsql
VOLATILE
PARALLEL UNSAFE
SECURITY DEFINER
SET search_path TO pg_catalog, pg_temp
AS $function$
DECLARE
    v_discovery_identity uuid;
    v_discovery_session uuid;
    v_i identity.identities%ROWTYPE;
    v_a identity.audience_revocations%ROWTYPE;
    v_s identity.sessions%ROWTYPE;
    v_now timestamptz;
BEGIN
    IF pg_catalog.current_setting('transaction_isolation') <> 'read committed' THEN
        RAISE EXCEPTION USING ERRCODE = '25000', MESSAGE = 'READ COMMITTED is required';
    END IF;
    IF p_digest IS NULL OR pg_catalog.octet_length(p_digest) <> 32
        OR p_audience IS NULL OR p_audience NOT IN ('admin', 'platform') THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    -- Discovery grants no authority; recheck after all ordered locks.
    SELECT s.identity_id, s.session_id INTO v_discovery_identity, v_discovery_session
    FROM identity.sessions AS s
    WHERE s.token_hash = p_digest AND s.audience = p_audience;
    IF NOT FOUND THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    SELECT i.id, i.status, i.email_verified_at, i.auth_epoch,
           i.credential_revision, i.created_at
    INTO v_i.id, v_i.status, v_i.email_verified_at, v_i.auth_epoch,
         v_i.credential_revision, v_i.created_at
    FROM identity.identities AS i WHERE i.id = v_discovery_identity
    FOR SHARE;
    IF NOT FOUND THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    SELECT a.* INTO v_a FROM identity.audience_revocations AS a
    WHERE a.identity_id = v_i.id AND a.audience = p_audience
    FOR SHARE;
    IF NOT FOUND THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    SELECT s.* INTO v_s FROM identity.sessions AS s
    WHERE s.session_id = v_discovery_session FOR UPDATE;
    IF NOT FOUND THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;
    IF v_s.identity_id IS DISTINCT FROM v_i.id
        OR v_s.audience IS DISTINCT FROM p_audience
        OR v_s.token_hash IS DISTINCT FROM p_digest THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    v_now := pg_catalog.clock_timestamp();
    IF v_now < v_i.created_at OR v_now < v_s.created_at
        OR v_now < v_s.last_activity_at THEN
        result := 'clock_anomaly'; RETURN NEXT; RETURN;
    END IF;
    IF v_s.revoked_at IS NOT NULL OR v_s.expired_at IS NOT NULL THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;
    IF v_now >= v_s.idle_expires_at OR v_now >= v_s.absolute_expires_at THEN
        UPDATE identity.sessions AS s SET expired_at = v_now
        WHERE s.session_id = v_s.session_id;
        -- Caller must COMMIT this terminal detection before reporting it.
        result := 'expired'; RETURN NEXT; RETURN;
    END IF;
    IF v_i.status <> 'active' OR v_i.email_verified_at IS NULL
        OR v_s.identity_epoch <> v_i.auth_epoch
        OR v_s.audience_epoch <> v_a.auth_epoch
        OR NOT EXISTS (
            SELECT 1 FROM identity.audience_revocations AS a
            WHERE a.identity_id = v_i.id AND a.audience = 'admin'
        ) OR NOT EXISTS (
            SELECT 1 FROM identity.audience_revocations AS a
            WHERE a.identity_id = v_i.id AND a.audience = 'platform'
        ) THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;
    result := 'valid';
    session_id := v_s.session_id;
    identity_id := v_i.id;
    audience := v_s.audience;
    authentication_level := v_s.authentication_level;
    csrf_key_id := v_s.csrf_key_id;
    csrf_generation := v_s.csrf_generation;
    csrf_salt := v_s.csrf_salt;
    checked_at := v_now;
    idle_expires_at := v_s.idle_expires_at;
    absolute_expires_at := v_s.absolute_expires_at;
    current_identity_epoch := v_i.auth_epoch;
    current_audience_epoch := v_a.auth_epoch;
    RETURN NEXT;
END;
$function$;
REVOKE ALL ON FUNCTION identity.validate_session(bytea, text)
FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
ALTER FUNCTION identity.validate_session(bytea, text) OWNER TO tomopedidos_auth_executor;

-- One operation per short transaction; any result is provisional until COMMIT.
CREATE FUNCTION identity.record_activity(
    p_digest bytea,
    p_audience text
)
RETURNS TABLE (
    result text, session_id uuid, identity_id uuid, audience text,
    authentication_level text, csrf_key_id text, csrf_generation bigint,
    csrf_salt bytea, checked_at timestamptz, idle_expires_at timestamptz,
    absolute_expires_at timestamptz, current_identity_epoch bigint,
    current_audience_epoch bigint
)
LANGUAGE plpgsql
VOLATILE
PARALLEL UNSAFE
SECURITY DEFINER
SET search_path TO pg_catalog, pg_temp
AS $function$
DECLARE
    v_discovery_identity uuid;
    v_discovery_session uuid;
    v_i identity.identities%ROWTYPE;
    v_a identity.audience_revocations%ROWTYPE;
    v_s identity.sessions%ROWTYPE;
    v_now timestamptz;
BEGIN
    IF pg_catalog.current_setting('transaction_isolation') <> 'read committed' THEN
        RAISE EXCEPTION USING ERRCODE = '25000', MESSAGE = 'READ COMMITTED is required';
    END IF;
    IF p_digest IS NULL OR pg_catalog.octet_length(p_digest) <> 32
        OR p_audience IS NULL OR p_audience NOT IN ('admin', 'platform') THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    -- Discovery grants no authority; recheck after all ordered locks.
    SELECT s.identity_id, s.session_id INTO v_discovery_identity, v_discovery_session
    FROM identity.sessions AS s
    WHERE s.token_hash = p_digest AND s.audience = p_audience;
    IF NOT FOUND THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    SELECT i.id, i.status, i.email_verified_at, i.auth_epoch,
           i.credential_revision, i.created_at
    INTO v_i.id, v_i.status, v_i.email_verified_at, v_i.auth_epoch,
         v_i.credential_revision, v_i.created_at
    FROM identity.identities AS i WHERE i.id = v_discovery_identity
    FOR SHARE;
    IF NOT FOUND THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    SELECT a.* INTO v_a FROM identity.audience_revocations AS a
    WHERE a.identity_id = v_i.id AND a.audience = p_audience
    FOR SHARE;
    IF NOT FOUND THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    SELECT s.* INTO v_s FROM identity.sessions AS s
    WHERE s.session_id = v_discovery_session FOR UPDATE;
    IF NOT FOUND THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;
    IF v_s.identity_id IS DISTINCT FROM v_i.id
        OR v_s.audience IS DISTINCT FROM p_audience
        OR v_s.token_hash IS DISTINCT FROM p_digest THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    v_now := pg_catalog.clock_timestamp();
    IF v_now < v_i.created_at OR v_now < v_s.created_at
        OR v_now < v_s.last_activity_at THEN
        result := 'clock_anomaly'; RETURN NEXT; RETURN;
    END IF;
    IF v_s.revoked_at IS NOT NULL OR v_s.expired_at IS NOT NULL THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;
    IF v_now >= v_s.idle_expires_at OR v_now >= v_s.absolute_expires_at THEN
        UPDATE identity.sessions AS s SET expired_at = v_now
        WHERE s.session_id = v_s.session_id;
        -- Caller must COMMIT this terminal detection before reporting it.
        result := 'expired'; RETURN NEXT; RETURN;
    END IF;
    IF v_i.status <> 'active' OR v_i.email_verified_at IS NULL
        OR v_s.identity_epoch <> v_i.auth_epoch
        OR v_s.audience_epoch <> v_a.auth_epoch
        OR NOT EXISTS (
            SELECT 1 FROM identity.audience_revocations AS a
            WHERE a.identity_id = v_i.id AND a.audience = 'admin'
        ) OR NOT EXISTS (
            SELECT 1 FROM identity.audience_revocations AS a
            WHERE a.identity_id = v_i.id AND a.audience = 'platform'
        ) THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;
    -- Caller has already established an authorized interactive action.
    v_s.last_activity_at := GREATEST(v_s.last_activity_at, v_now);
    v_s.idle_expires_at := LEAST(v_s.absolute_expires_at,
        GREATEST(v_s.idle_expires_at, v_now + CASE v_s.audience
            WHEN 'admin' THEN INTERVAL '43200 seconds'
            WHEN 'platform' THEN INTERVAL '900 seconds' END));
    UPDATE identity.sessions AS s
    SET last_activity_at = v_s.last_activity_at, idle_expires_at = v_s.idle_expires_at
    WHERE s.session_id = v_s.session_id;
    result := 'activity_recorded';
    session_id := v_s.session_id;
    identity_id := v_i.id;
    audience := v_s.audience;
    authentication_level := v_s.authentication_level;
    csrf_key_id := v_s.csrf_key_id;
    csrf_generation := v_s.csrf_generation;
    csrf_salt := v_s.csrf_salt;
    checked_at := v_now;
    idle_expires_at := v_s.idle_expires_at;
    absolute_expires_at := v_s.absolute_expires_at;
    current_identity_epoch := v_i.auth_epoch;
    current_audience_epoch := v_a.auth_epoch;
    RETURN NEXT;
END;
$function$;
REVOKE ALL ON FUNCTION identity.record_activity(bytea, text)
FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
ALTER FUNCTION identity.record_activity(bytea, text) OWNER TO tomopedidos_auth_executor;

-- One operation per short transaction; any result is provisional until COMMIT.
CREATE FUNCTION identity.revoke_session(
    p_digest bytea,
    p_audience text
)
RETURNS TABLE (
    result text, session_id uuid, identity_id uuid, audience text,
    authentication_level text, csrf_key_id text, csrf_generation bigint,
    csrf_salt bytea, checked_at timestamptz, idle_expires_at timestamptz,
    absolute_expires_at timestamptz, current_identity_epoch bigint,
    current_audience_epoch bigint
)
LANGUAGE plpgsql
VOLATILE
PARALLEL UNSAFE
SECURITY DEFINER
SET search_path TO pg_catalog, pg_temp
AS $function$
DECLARE
    v_discovery_identity uuid;
    v_discovery_session uuid;
    v_i identity.identities%ROWTYPE;
    v_a identity.audience_revocations%ROWTYPE;
    v_s identity.sessions%ROWTYPE;
    v_now timestamptz;
BEGIN
    IF pg_catalog.current_setting('transaction_isolation') <> 'read committed' THEN
        RAISE EXCEPTION USING ERRCODE = '25000', MESSAGE = 'READ COMMITTED is required';
    END IF;
    IF p_digest IS NULL OR pg_catalog.octet_length(p_digest) <> 32
        OR p_audience IS NULL OR p_audience NOT IN ('admin', 'platform') THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    -- Discovery grants no authority; recheck after all ordered locks.
    SELECT s.identity_id, s.session_id INTO v_discovery_identity, v_discovery_session
    FROM identity.sessions AS s
    WHERE s.token_hash = p_digest AND s.audience = p_audience;
    IF NOT FOUND THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    SELECT i.id, i.status, i.email_verified_at, i.auth_epoch,
           i.credential_revision, i.created_at
    INTO v_i.id, v_i.status, v_i.email_verified_at, v_i.auth_epoch,
         v_i.credential_revision, v_i.created_at
    FROM identity.identities AS i WHERE i.id = v_discovery_identity
    FOR SHARE;
    IF NOT FOUND THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    SELECT a.* INTO v_a FROM identity.audience_revocations AS a
    WHERE a.identity_id = v_i.id AND a.audience = p_audience
    FOR SHARE;
    IF NOT FOUND THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    SELECT s.* INTO v_s FROM identity.sessions AS s
    WHERE s.session_id = v_discovery_session FOR UPDATE;
    IF NOT FOUND THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;
    IF v_s.identity_id IS DISTINCT FROM v_i.id
        OR v_s.audience IS DISTINCT FROM p_audience
        OR v_s.token_hash IS DISTINCT FROM p_digest THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    v_now := pg_catalog.clock_timestamp();
    IF v_now < v_i.created_at OR v_now < v_s.created_at
        OR v_now < v_s.last_activity_at THEN
        result := 'clock_anomaly'; RETURN NEXT; RETURN;
    END IF;
    IF v_s.revoked_at IS NOT NULL OR v_s.expired_at IS NOT NULL THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;
    IF v_now >= v_s.idle_expires_at OR v_now >= v_s.absolute_expires_at THEN
        UPDATE identity.sessions AS s SET expired_at = v_now
        WHERE s.session_id = v_s.session_id;
        -- Caller must COMMIT this terminal detection before reporting it.
        result := 'expired'; RETURN NEXT; RETURN;
    END IF;
    IF v_i.status <> 'active' OR v_i.email_verified_at IS NULL
        OR v_s.identity_epoch <> v_i.auth_epoch
        OR v_s.audience_epoch <> v_a.auth_epoch
        OR NOT EXISTS (
            SELECT 1 FROM identity.audience_revocations AS a
            WHERE a.identity_id = v_i.id AND a.audience = 'admin'
        ) OR NOT EXISTS (
            SELECT 1 FROM identity.audience_revocations AS a
            WHERE a.identity_id = v_i.id AND a.audience = 'platform'
        ) THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;
    -- Digest possession/authority is established by trusted Go, never by this SQL.
    UPDATE identity.sessions AS s SET revoked_at = v_now
    WHERE s.session_id = v_s.session_id;
    result := 'revoked';
    session_id := v_s.session_id;
    identity_id := v_i.id;
    audience := v_s.audience;
    authentication_level := v_s.authentication_level;
    csrf_key_id := v_s.csrf_key_id;
    csrf_generation := v_s.csrf_generation;
    csrf_salt := v_s.csrf_salt;
    checked_at := v_now;
    idle_expires_at := v_s.idle_expires_at;
    absolute_expires_at := v_s.absolute_expires_at;
    current_identity_epoch := v_i.auth_epoch;
    current_audience_epoch := v_a.auth_epoch;
    RETURN NEXT;
END;
$function$;
REVOKE ALL ON FUNCTION identity.revoke_session(bytea, text)
FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
ALTER FUNCTION identity.revoke_session(bytea, text) OWNER TO tomopedidos_auth_executor;

-- One operation per short transaction; any result is provisional until COMMIT.
CREATE FUNCTION identity.mark_expired(
    p_digest bytea,
    p_audience text
)
RETURNS TABLE (
    result text, session_id uuid, identity_id uuid, audience text,
    authentication_level text, csrf_key_id text, csrf_generation bigint,
    csrf_salt bytea, checked_at timestamptz, idle_expires_at timestamptz,
    absolute_expires_at timestamptz, current_identity_epoch bigint,
    current_audience_epoch bigint
)
LANGUAGE plpgsql
VOLATILE
PARALLEL UNSAFE
SECURITY DEFINER
SET search_path TO pg_catalog, pg_temp
AS $function$
DECLARE
    v_discovery_identity uuid;
    v_discovery_session uuid;
    v_i identity.identities%ROWTYPE;
    v_a identity.audience_revocations%ROWTYPE;
    v_s identity.sessions%ROWTYPE;
    v_now timestamptz;
BEGIN
    IF pg_catalog.current_setting('transaction_isolation') <> 'read committed' THEN
        RAISE EXCEPTION USING ERRCODE = '25000', MESSAGE = 'READ COMMITTED is required';
    END IF;
    IF p_digest IS NULL OR pg_catalog.octet_length(p_digest) <> 32
        OR p_audience IS NULL OR p_audience NOT IN ('admin', 'platform') THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    -- Discovery grants no authority; recheck after all ordered locks.
    SELECT s.identity_id, s.session_id INTO v_discovery_identity, v_discovery_session
    FROM identity.sessions AS s
    WHERE s.token_hash = p_digest AND s.audience = p_audience;
    IF NOT FOUND THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    SELECT i.id, i.status, i.email_verified_at, i.auth_epoch,
           i.credential_revision, i.created_at
    INTO v_i.id, v_i.status, v_i.email_verified_at, v_i.auth_epoch,
         v_i.credential_revision, v_i.created_at
    FROM identity.identities AS i WHERE i.id = v_discovery_identity
    FOR SHARE;
    IF NOT FOUND THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    SELECT a.* INTO v_a FROM identity.audience_revocations AS a
    WHERE a.identity_id = v_i.id AND a.audience = p_audience
    FOR SHARE;
    IF NOT FOUND THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    SELECT s.* INTO v_s FROM identity.sessions AS s
    WHERE s.session_id = v_discovery_session FOR UPDATE;
    IF NOT FOUND THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;
    IF v_s.identity_id IS DISTINCT FROM v_i.id
        OR v_s.audience IS DISTINCT FROM p_audience
        OR v_s.token_hash IS DISTINCT FROM p_digest THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    v_now := pg_catalog.clock_timestamp();
    IF v_now < v_i.created_at OR v_now < v_s.created_at
        OR v_now < v_s.last_activity_at THEN
        result := 'clock_anomaly'; RETURN NEXT; RETURN;
    END IF;
    IF v_s.revoked_at IS NOT NULL OR v_s.expired_at IS NOT NULL THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;
    IF v_now >= v_s.idle_expires_at OR v_now >= v_s.absolute_expires_at THEN
        UPDATE identity.sessions AS s SET expired_at = v_now
        WHERE s.session_id = v_s.session_id;
        -- Caller must COMMIT this terminal detection before reporting it.
        result := 'expired'; RETURN NEXT; RETURN;
    END IF;
    IF v_i.status <> 'active' OR v_i.email_verified_at IS NULL
        OR v_s.identity_epoch <> v_i.auth_epoch
        OR v_s.audience_epoch <> v_a.auth_epoch
        OR NOT EXISTS (
            SELECT 1 FROM identity.audience_revocations AS a
            WHERE a.identity_id = v_i.id AND a.audience = 'admin'
        ) OR NOT EXISTS (
            SELECT 1 FROM identity.audience_revocations AS a
            WHERE a.identity_id = v_i.id AND a.audience = 'platform'
        ) THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;
    result := 'not_expired';
    session_id := v_s.session_id;
    identity_id := v_i.id;
    audience := v_s.audience;
    authentication_level := v_s.authentication_level;
    csrf_key_id := v_s.csrf_key_id;
    csrf_generation := v_s.csrf_generation;
    csrf_salt := v_s.csrf_salt;
    checked_at := v_now;
    idle_expires_at := v_s.idle_expires_at;
    absolute_expires_at := v_s.absolute_expires_at;
    current_identity_epoch := v_i.auth_epoch;
    current_audience_epoch := v_a.auth_epoch;
    RETURN NEXT;
END;
$function$;
REVOKE ALL ON FUNCTION identity.mark_expired(bytea, text)
FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
ALTER FUNCTION identity.mark_expired(bytea, text) OWNER TO tomopedidos_auth_executor;

-- Dormant privileged function: no operational EXECUTE caller, including auth.
CREATE FUNCTION identity.revoke_audience(
    p_digest bytea,
    p_audience text
)
RETURNS TABLE (
    result text, session_id uuid, identity_id uuid, audience text,
    authentication_level text, csrf_key_id text, csrf_generation bigint,
    csrf_salt bytea, checked_at timestamptz, idle_expires_at timestamptz,
    absolute_expires_at timestamptz, current_identity_epoch bigint,
    current_audience_epoch bigint
)
LANGUAGE plpgsql
VOLATILE
PARALLEL UNSAFE
SECURITY DEFINER
SET search_path TO pg_catalog, pg_temp
AS $function$
DECLARE
    v_discovery_identity uuid;
    v_discovery_session uuid;
    v_i identity.identities%ROWTYPE;
    v_a identity.audience_revocations%ROWTYPE;
    v_s identity.sessions%ROWTYPE;
    v_now timestamptz;
BEGIN
    IF pg_catalog.current_setting('transaction_isolation') <> 'read committed' THEN
        RAISE EXCEPTION USING ERRCODE = '25000', MESSAGE = 'READ COMMITTED is required';
    END IF;
    IF p_digest IS NULL OR pg_catalog.octet_length(p_digest) <> 32
        OR p_audience IS NULL OR p_audience NOT IN ('admin', 'platform') THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    -- Discovery grants no authority; recheck after all ordered locks.
    SELECT s.identity_id, s.session_id INTO v_discovery_identity, v_discovery_session
    FROM identity.sessions AS s
    WHERE s.token_hash = p_digest AND s.audience = p_audience;
    IF NOT FOUND THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    SELECT i.id, i.status, i.email_verified_at, i.auth_epoch,
           i.credential_revision, i.created_at
    INTO v_i.id, v_i.status, v_i.email_verified_at, v_i.auth_epoch,
         v_i.credential_revision, v_i.created_at
    FROM identity.identities AS i WHERE i.id = v_discovery_identity
    FOR SHARE;
    IF NOT FOUND THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    SELECT a.* INTO v_a FROM identity.audience_revocations AS a
    WHERE a.identity_id = v_i.id AND a.audience = p_audience
    FOR UPDATE;
    IF NOT FOUND THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    SELECT s.* INTO v_s FROM identity.sessions AS s
    WHERE s.session_id = v_discovery_session FOR UPDATE;
    IF NOT FOUND THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;
    IF v_s.identity_id IS DISTINCT FROM v_i.id
        OR v_s.audience IS DISTINCT FROM p_audience
        OR v_s.token_hash IS DISTINCT FROM p_digest THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    v_now := pg_catalog.clock_timestamp();
    IF v_now < v_i.created_at OR v_now < v_s.created_at
        OR v_now < v_s.last_activity_at THEN
        result := 'clock_anomaly'; RETURN NEXT; RETURN;
    END IF;
    IF v_s.revoked_at IS NOT NULL OR v_s.expired_at IS NOT NULL THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;
    IF v_now >= v_s.idle_expires_at OR v_now >= v_s.absolute_expires_at THEN
        UPDATE identity.sessions AS s SET expired_at = v_now
        WHERE s.session_id = v_s.session_id;
        -- Caller must COMMIT this terminal detection before reporting it.
        result := 'expired'; RETURN NEXT; RETURN;
    END IF;
    IF v_i.status <> 'active' OR v_i.email_verified_at IS NULL
        OR v_s.identity_epoch <> v_i.auth_epoch
        OR v_s.audience_epoch <> v_a.auth_epoch
        OR NOT EXISTS (
            SELECT 1 FROM identity.audience_revocations AS a
            WHERE a.identity_id = v_i.id AND a.audience = 'admin'
        ) OR NOT EXISTS (
            SELECT 1 FROM identity.audience_revocations AS a
            WHERE a.identity_id = v_i.id AND a.audience = 'platform'
        ) THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;
    -- Revoke only the audience of the validated authorizing session.
    IF v_a.auth_epoch = 9223372036854775807 THEN
        RAISE EXCEPTION USING ERRCODE = '22003', MESSAGE = 'Audience epoch exhausted';
    END IF;
    v_a.auth_epoch := v_a.auth_epoch + 1;
    UPDATE identity.audience_revocations AS a SET auth_epoch = v_a.auth_epoch
    WHERE a.identity_id = v_i.id AND a.audience = p_audience;
    result := 'audience_revoked';
    session_id := v_s.session_id;
    identity_id := v_i.id;
    audience := v_s.audience;
    authentication_level := v_s.authentication_level;
    csrf_key_id := v_s.csrf_key_id;
    csrf_generation := v_s.csrf_generation;
    csrf_salt := v_s.csrf_salt;
    checked_at := v_now;
    idle_expires_at := v_s.idle_expires_at;
    absolute_expires_at := v_s.absolute_expires_at;
    current_identity_epoch := v_i.auth_epoch;
    current_audience_epoch := v_a.auth_epoch;
    RETURN NEXT;
END;
$function$;
REVOKE ALL ON FUNCTION identity.revoke_audience(bytea, text)
FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
ALTER FUNCTION identity.revoke_audience(bytea, text) OWNER TO tomopedidos_auth_revoke_executor;

-- Dormant privileged function: no operational EXECUTE caller, including auth.
CREATE FUNCTION identity.revoke_global(
    p_digest bytea,
    p_audience text
)
RETURNS TABLE (
    result text, session_id uuid, identity_id uuid, audience text,
    authentication_level text, csrf_key_id text, csrf_generation bigint,
    csrf_salt bytea, checked_at timestamptz, idle_expires_at timestamptz,
    absolute_expires_at timestamptz, current_identity_epoch bigint,
    current_audience_epoch bigint
)
LANGUAGE plpgsql
VOLATILE
PARALLEL UNSAFE
SECURITY DEFINER
SET search_path TO pg_catalog, pg_temp
AS $function$
DECLARE
    v_discovery_identity uuid;
    v_discovery_session uuid;
    v_i identity.identities%ROWTYPE;
    v_a identity.audience_revocations%ROWTYPE;
    v_s identity.sessions%ROWTYPE;
    v_now timestamptz;
BEGIN
    IF pg_catalog.current_setting('transaction_isolation') <> 'read committed' THEN
        RAISE EXCEPTION USING ERRCODE = '25000', MESSAGE = 'READ COMMITTED is required';
    END IF;
    IF p_digest IS NULL OR pg_catalog.octet_length(p_digest) <> 32
        OR p_audience IS NULL OR p_audience NOT IN ('admin', 'platform') THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    -- Discovery grants no authority; recheck after all ordered locks.
    SELECT s.identity_id, s.session_id INTO v_discovery_identity, v_discovery_session
    FROM identity.sessions AS s
    WHERE s.token_hash = p_digest AND s.audience = p_audience;
    IF NOT FOUND THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    SELECT i.id, i.status, i.email_verified_at, i.auth_epoch,
           i.credential_revision, i.created_at
    INTO v_i.id, v_i.status, v_i.email_verified_at, v_i.auth_epoch,
         v_i.credential_revision, v_i.created_at
    FROM identity.identities AS i WHERE i.id = v_discovery_identity
    FOR UPDATE;
    IF NOT FOUND THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    SELECT a.* INTO v_a FROM identity.audience_revocations AS a
    WHERE a.identity_id = v_i.id AND a.audience = p_audience
    FOR SHARE;
    IF NOT FOUND THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    SELECT s.* INTO v_s FROM identity.sessions AS s
    WHERE s.session_id = v_discovery_session FOR UPDATE;
    IF NOT FOUND THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;
    IF v_s.identity_id IS DISTINCT FROM v_i.id
        OR v_s.audience IS DISTINCT FROM p_audience
        OR v_s.token_hash IS DISTINCT FROM p_digest THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;

    v_now := pg_catalog.clock_timestamp();
    IF v_now < v_i.created_at OR v_now < v_s.created_at
        OR v_now < v_s.last_activity_at THEN
        result := 'clock_anomaly'; RETURN NEXT; RETURN;
    END IF;
    IF v_s.revoked_at IS NOT NULL OR v_s.expired_at IS NOT NULL THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;
    IF v_now >= v_s.idle_expires_at OR v_now >= v_s.absolute_expires_at THEN
        UPDATE identity.sessions AS s SET expired_at = v_now
        WHERE s.session_id = v_s.session_id;
        -- Caller must COMMIT this terminal detection before reporting it.
        result := 'expired'; RETURN NEXT; RETURN;
    END IF;
    IF v_i.status <> 'active' OR v_i.email_verified_at IS NULL
        OR v_s.identity_epoch <> v_i.auth_epoch
        OR v_s.audience_epoch <> v_a.auth_epoch
        OR NOT EXISTS (
            SELECT 1 FROM identity.audience_revocations AS a
            WHERE a.identity_id = v_i.id AND a.audience = 'admin'
        ) OR NOT EXISTS (
            SELECT 1 FROM identity.audience_revocations AS a
            WHERE a.identity_id = v_i.id AND a.audience = 'platform'
        ) THEN
        result := 'invalid'; RETURN NEXT; RETURN;
    END IF;
    -- No operational caller in B2: freshness/reforcement is not proven by SQL.
    IF v_i.auth_epoch = 9223372036854775807 THEN
        RAISE EXCEPTION USING ERRCODE = '22003', MESSAGE = 'Global epoch exhausted';
    END IF;
    v_i.auth_epoch := v_i.auth_epoch + 1;
    UPDATE identity.identities AS i SET auth_epoch = v_i.auth_epoch WHERE i.id = v_i.id;
    result := 'global_revoked';
    session_id := v_s.session_id;
    identity_id := v_i.id;
    audience := v_s.audience;
    authentication_level := v_s.authentication_level;
    csrf_key_id := v_s.csrf_key_id;
    csrf_generation := v_s.csrf_generation;
    csrf_salt := v_s.csrf_salt;
    checked_at := v_now;
    idle_expires_at := v_s.idle_expires_at;
    absolute_expires_at := v_s.absolute_expires_at;
    current_identity_epoch := v_i.auth_epoch;
    current_audience_epoch := v_a.auth_epoch;
    RETURN NEXT;
END;
$function$;
REVOKE ALL ON FUNCTION identity.revoke_global(bytea, text)
FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
ALTER FUNCTION identity.revoke_global(bytea, text) OWNER TO tomopedidos_auth_revoke_executor;

-- Separate transaction after password verification; CAS, revision +1, no epoch change.
CREATE FUNCTION identity.rehash_conditional(
    p_identity_id uuid,
    p_expected_revision bigint,
    p_expected_hash text,
    p_new_hash text
)
RETURNS TABLE (result text, credential_revision bigint)
LANGUAGE plpgsql
VOLATILE
PARALLEL UNSAFE
SECURITY DEFINER
SET search_path TO pg_catalog, pg_temp
AS $function$
DECLARE
    v_i identity.identities%ROWTYPE;
    v_hash text;
    v_now timestamptz;
BEGIN
    IF pg_catalog.current_setting('transaction_isolation') <> 'read committed' THEN
        RAISE EXCEPTION USING ERRCODE = '25000', MESSAGE = 'READ COMMITTED is required';
    END IF;
    IF p_identity_id IS NULL OR p_expected_revision IS NULL
        OR p_expected_hash IS NULL OR p_new_hash IS NULL THEN
        result := 'not_applied'; RETURN NEXT; RETURN;
    END IF;
    SELECT i.id, i.status, i.email_verified_at, i.credential_revision, i.created_at
    INTO v_i.id, v_i.status, v_i.email_verified_at, v_i.credential_revision, v_i.created_at
    FROM identity.identities AS i WHERE i.id = p_identity_id FOR UPDATE;
    IF NOT FOUND THEN
        result := 'not_applied'; RETURN NEXT; RETURN;
    END IF;
    IF v_i.status <> 'active' OR v_i.email_verified_at IS NULL
        OR v_i.credential_revision <> p_expected_revision THEN
        result := 'not_applied'; RETURN NEXT; RETURN;
    END IF;
    SELECT c.password_hash INTO v_hash FROM identity.identity_credentials AS c
    WHERE c.identity_id = v_i.id FOR UPDATE;
    IF NOT FOUND OR v_hash IS DISTINCT FROM p_expected_hash THEN
        result := 'not_applied'; RETURN NEXT; RETURN;
    END IF;
    v_now := pg_catalog.clock_timestamp();
    IF v_now < v_i.created_at THEN
        result := 'clock_anomaly'; RETURN NEXT; RETURN;
    END IF;
    IF p_new_hash = v_hash THEN
        result := 'unchanged'; credential_revision := v_i.credential_revision;
        RETURN NEXT; RETURN;
    END IF;
    IF v_i.credential_revision = 9223372036854775807 THEN
        RAISE EXCEPTION USING ERRCODE = '22003', MESSAGE = 'Credential revision exhausted';
    END IF;
    -- SQL cannot establish equivalence or non-degradation: verified in trusted Go.
    UPDATE identity.identity_credentials AS c
    SET password_hash = p_new_hash, changed_at = v_now WHERE c.identity_id = v_i.id;
    UPDATE identity.identities AS i
    SET credential_revision = v_i.credential_revision + 1 WHERE i.id = v_i.id;
    result := 'rehashed'; credential_revision := v_i.credential_revision + 1;
    RETURN NEXT;
EXCEPTION
    WHEN check_violation OR not_null_violation THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Credential rehash rejected';
END;
$function$;
REVOKE ALL ON FUNCTION identity.rehash_conditional(uuid, bigint, text, text)
FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;
ALTER FUNCTION identity.rehash_conditional(uuid, bigint, text, text) OWNER TO tomopedidos_auth_executor;

-- Verify exact owners/security properties and owner-only ACL before commit.
-- Unknown default-privilege recipients cause rollback; never silently widen ACL.
DO $verify$
DECLARE
    v_expected record;
    v_proc record;
BEGIN
    FOR v_expected IN SELECT * FROM (VALUES
        ('identity.lookup_credential(text, text)', 'tomopedidos_auth_executor', 'F53AB501509EF67AF3325B6AB2FE18B2586995295D3148D394162CEC0728720B'),
        ('identity.issue_session(uuid, bigint, bigint, bigint, text, uuid, bytea, text, bytea)', 'tomopedidos_auth_executor', 'E0E4D81FED4D047BD447F95647DF4517B30B109885E2D9DEA5CF75E69ED4D141'),
        ('identity.validate_session(bytea, text)', 'tomopedidos_auth_executor', '736057B501A47088E7FE8A77AEAD2A19D6AB880AC93877D53B071AE10E3AAC46'),
        ('identity.record_activity(bytea, text)', 'tomopedidos_auth_executor', 'C712CB021E5FDF5FF64C96F68EEE4BFA3D9AA54BE2B415D44AC88ED1ED4F7822'),
        ('identity.revoke_session(bytea, text)', 'tomopedidos_auth_executor', 'DEC02E132C4EE23000B3047C8EF24A5621730FA300DCB80D1E1C209EE139309F'),
        ('identity.mark_expired(bytea, text)', 'tomopedidos_auth_executor', '9A9800B8D8BE26030B12BD732DE309EB8C8221806D4467272DE86957B3F08220'),
        ('identity.revoke_audience(bytea, text)', 'tomopedidos_auth_revoke_executor', '218EEAA3AE40504F96AEF8A4D63EAAFF32C8485494BEE8ADDF2B1F504CE010C7'),
        ('identity.revoke_global(bytea, text)', 'tomopedidos_auth_revoke_executor', '8FB466B18A96BD91ECC3FB0012D2CA91126E73C2067E13B51D001BD6E394E49F'),
        ('identity.rehash_conditional(uuid, bigint, text, text)', 'tomopedidos_auth_executor', '7AA63818771E50B4641091A2AA61D2CABF9865A1F486862A8057A28AF39AAE91')
    ) AS expected(signature, owner_name, source_sha256_lf)
    LOOP
        SELECT p.* INTO STRICT v_proc FROM pg_catalog.pg_proc AS p
        WHERE p.oid = pg_catalog.to_regprocedure(v_expected.signature);
        IF pg_catalog.upper(pg_catalog.encode(pg_catalog.sha256(
            pg_catalog.convert_to(pg_catalog.replace(v_proc.prosrc, E'\r\n', E'\n'), 'UTF8')
        ), 'hex')) <> v_expected.source_sha256_lf THEN
            RAISE EXCEPTION 'Function source hash assertion failed';
        END IF;
        IF v_proc.proowner <> (SELECT r.oid FROM pg_catalog.pg_roles AS r
                              WHERE r.rolname = v_expected.owner_name)
            OR NOT v_proc.prosecdef OR v_proc.provolatile <> 'v'
            OR v_proc.proparallel <> 'u' OR v_proc.proleakproof
            OR v_proc.prokind <> 'f'
            OR v_proc.prolang <> (SELECT l.oid FROM pg_catalog.pg_language AS l
                                 WHERE l.lanname = 'plpgsql')
            OR v_proc.proconfig IS DISTINCT FROM ARRAY['search_path=pg_catalog, pg_temp']::text[] THEN
            RAISE EXCEPTION 'Function ownership/security assertion failed';
        END IF;
        IF EXISTS (
            SELECT 1 FROM pg_catalog.aclexplode(COALESCE(v_proc.proacl,
                pg_catalog.acldefault('f', v_proc.proowner))) AS acl
            WHERE acl.grantee <> v_proc.proowner OR acl.privilege_type <> 'EXECUTE'
                OR acl.is_grantable
        ) OR NOT pg_catalog.has_function_privilege(v_proc.proowner, v_proc.oid, 'EXECUTE') THEN
            RAISE EXCEPTION 'Function ACL assertion failed';
        END IF;
    END LOOP;
END;
$verify$;
COMMIT;

