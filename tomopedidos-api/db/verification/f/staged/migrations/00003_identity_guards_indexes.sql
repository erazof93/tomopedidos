-- B2-A / delivery B: depends on 00001 and 00002, in that order.
-- Goose must retain its default transaction (no NO TRANSACTION): SET LOCAL
-- ROLE tp_owner establishes ownership and the existing B1 default privileges.
-- The migration caller must already be authorized to SET ROLE tp_owner.
-- No role, membership, grant or B1 bootstrap change is made here.
-- These SECURITY INVOKER helpers compare OLD/NEW only: no cross-table reads,
-- writes or locks. They do not implement authentication or epoch coordination.
-- Actual Goose parsing, ownership/ACL, trigger behavior and index plans require
-- separately authorized execution/tests in a disposable database.

-- +goose Up
SET LOCAL ROLE tp_owner;
SET LOCAL search_path TO pg_catalog;

-- +goose StatementBegin
CREATE FUNCTION identity.guard_identities_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO pg_catalog, pg_temp
AS $guard$
BEGIN
    IF NEW.id IS DISTINCT FROM OLD.id
        OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Identity immutable fields cannot change';
    END IF;

    IF NEW.auth_epoch < OLD.auth_epoch
        OR NEW.credential_revision < OLD.credential_revision THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Identity counters cannot decrease';
    END IF;

    -- Status/email transitions remain subject to A's CHECKs and future authorized
    -- operations. Disabling and semantic credential changes must coordinate epoch
    -- increments transactionally; this guard cannot prove those operations.
    -- Do not inspect the generated email_canonical in a BEFORE trigger.
    RETURN NEW;
END;
$guard$;
-- +goose StatementEnd

CREATE TRIGGER trg_identities_update_guard
BEFORE UPDATE ON identity.identities
FOR EACH ROW EXECUTE FUNCTION identity.guard_identities_update();

-- +goose StatementBegin
CREATE FUNCTION identity.guard_audience_revocations_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO pg_catalog, pg_temp
AS $guard$
BEGIN
    IF NEW.identity_id IS DISTINCT FROM OLD.identity_id
        OR NEW.audience IS DISTINCT FROM OLD.audience THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Audience revocation keys cannot change';
    END IF;

    IF NEW.auth_epoch < OLD.auth_epoch THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Audience epoch cannot decrease';
    END IF;

    RETURN NEW;
END;
$guard$;
-- +goose StatementEnd

CREATE TRIGGER trg_audience_revocations_update_guard
BEFORE UPDATE ON identity.audience_revocations
FOR EACH ROW EXECUTE FUNCTION identity.guard_audience_revocations_update();

-- +goose StatementBegin
CREATE FUNCTION identity.guard_sessions_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO pg_catalog, pg_temp
AS $guard$
BEGIN
    IF NEW.session_id IS DISTINCT FROM OLD.session_id
        OR NEW.identity_id IS DISTINCT FROM OLD.identity_id
        OR NEW.audience IS DISTINCT FROM OLD.audience
        OR NEW.token_hash IS DISTINCT FROM OLD.token_hash
        OR NEW.identity_epoch IS DISTINCT FROM OLD.identity_epoch
        OR NEW.audience_epoch IS DISTINCT FROM OLD.audience_epoch
        OR NEW.created_at IS DISTINCT FROM OLD.created_at
        OR NEW.absolute_expires_at IS DISTINCT FROM OLD.absolute_expires_at THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Session immutable fields cannot change';
    END IF;

    -- No CSRF rotation/update contract is enabled in the initial runtime.
    IF NEW.csrf_key_id IS DISTINCT FROM OLD.csrf_key_id
        OR NEW.csrf_generation IS DISTINCT FROM OLD.csrf_generation
        OR NEW.csrf_salt IS DISTINCT FROM OLD.csrf_salt THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Session CSRF binding cannot change';
    END IF;

    IF OLD.revoked_at IS NOT NULL
        AND NEW.revoked_at IS DISTINCT FROM OLD.revoked_at THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Session revocation is irreversible';
    END IF;

    IF OLD.expired_at IS NOT NULL
        AND NEW.expired_at IS DISTINCT FROM OLD.expired_at THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Session expiration is irreversible';
    END IF;

    IF (OLD.revoked_at IS NOT NULL OR OLD.expired_at IS NOT NULL)
        AND (NEW.last_activity_at IS DISTINCT FROM OLD.last_activity_at
            OR NEW.idle_expires_at IS DISTINCT FROM OLD.idle_expires_at) THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Terminal session activity cannot change';
    END IF;

    IF NEW.last_activity_at < OLD.last_activity_at
        OR NEW.idle_expires_at < OLD.idle_expires_at THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Session activity deadlines cannot decrease';
    END IF;

    -- NULL -> terminal timestamp is allowed, including a second terminal cause.
    -- Existing marks must remain unchanged. Unchanged updates are permitted.
    -- Natural expiration/state/epochs and authorized activity still require the
    -- future functions, time capture and Identity -> audience -> session locks.
    -- This guard does not read the clock or claim that a session is valid.
    RETURN NEW;
END;
$guard$;
-- +goose StatementEnd

CREATE TRIGGER trg_sessions_update_guard
BEFORE UPDATE ON identity.sessions
FOR EACH ROW EXECUTE FUNCTION identity.guard_sessions_update();

-- ListSessionMetadata by identity/audience, ordered by creation and session ID;
-- the leading identity columns also support FK-related lookups.
CREATE INDEX idx_sessions_identity_audience_created
ON identity.sessions (identity_id, audience, created_at DESC, session_id);

-- KeyReferences: conservative CSRF key retirement by key ID/absolute deadline.
CREATE INDEX idx_sessions_csrf_key_absolute
ON identity.sessions (csrf_key_id, absolute_expires_at);

-- No duplicate PK/UNIQUE indexes, epoch sweep or clock-dependent predicate.
-- The terminal-date cleanup expression/index belongs to delivery E.

-- +goose Down
-- Only test rollback in an explicitly authorized disposable database.
-- Remove B's objects before rolling back 00002/00001. Preserve all B1 schemas.
-- No CASCADE: later dependencies must be reviewed/removed separately first.
SET LOCAL ROLE tp_owner;
SET LOCAL search_path TO pg_catalog;

DROP INDEX identity.idx_sessions_csrf_key_absolute;
DROP INDEX identity.idx_sessions_identity_audience_created;

DROP TRIGGER trg_sessions_update_guard ON identity.sessions;
DROP FUNCTION identity.guard_sessions_update();

DROP TRIGGER trg_audience_revocations_update_guard ON identity.audience_revocations;
DROP FUNCTION identity.guard_audience_revocations_update();

DROP TRIGGER trg_identities_update_guard ON identity.identities;
DROP FUNCTION identity.guard_identities_update();
