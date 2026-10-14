-- B2-A / delivery A: depends on 00001 and the existing approved B1 schema.
-- Static constraints only. Atomic audience initialization, epoch coordination,
-- terminality and immutability guards belong to subsequent deliveries.
-- No grants, roles, extra indexes, helper functions or application queries.

-- +goose Up
SET LOCAL ROLE tp_owner;
SET LOCAL search_path TO pg_catalog;

CREATE TABLE identity.audience_revocations (
    identity_id uuid NOT NULL,
    audience text NOT NULL,
    auth_epoch bigint NOT NULL DEFAULT 0,

    CONSTRAINT pk_audience_revocations PRIMARY KEY (identity_id, audience),
    CONSTRAINT fk_audience_revocations_identity FOREIGN KEY (identity_id)
        REFERENCES identity.identities (id)
        ON UPDATE RESTRICT ON DELETE RESTRICT NOT DEFERRABLE,
    CONSTRAINT ck_audience_revocations_audience CHECK (
        audience IN ('admin', 'platform')
    ),
    CONSTRAINT ck_audience_revocations_auth_epoch CHECK (auth_epoch >= 0)
);

CREATE TABLE identity.sessions (
    session_id uuid NOT NULL,
    identity_id uuid NOT NULL,
    audience text NOT NULL,
    token_hash bytea NOT NULL,
    identity_epoch bigint NOT NULL,
    audience_epoch bigint NOT NULL,
    authentication_level text NOT NULL,
    csrf_key_id text COLLATE "C" NOT NULL,
    csrf_generation bigint NOT NULL DEFAULT 1,
    csrf_salt bytea NOT NULL,
    created_at timestamptz NOT NULL,
    last_activity_at timestamptz NOT NULL,
    idle_expires_at timestamptz NOT NULL,
    absolute_expires_at timestamptz NOT NULL,
    revoked_at timestamptz,
    expired_at timestamptz,

    CONSTRAINT pk_sessions PRIMARY KEY (session_id),
    CONSTRAINT uq_sessions_token_hash UNIQUE (token_hash),
    CONSTRAINT fk_sessions_identity FOREIGN KEY (identity_id)
        REFERENCES identity.identities (id)
        ON UPDATE RESTRICT ON DELETE RESTRICT NOT DEFERRABLE,
    CONSTRAINT fk_sessions_audience FOREIGN KEY (identity_id, audience)
        REFERENCES identity.audience_revocations (identity_id, audience)
        ON UPDATE RESTRICT ON DELETE RESTRICT NOT DEFERRABLE,
    CONSTRAINT ck_sessions_uuid_v4 CHECK (
        pg_catalog.substr(session_id::text, 15, 1) = '4'
        AND pg_catalog.substr(session_id::text, 20, 1) IN ('8', '9', 'a', 'b')
    ),
    CONSTRAINT ck_sessions_audience CHECK (audience IN ('admin', 'platform')),
    CONSTRAINT ck_sessions_token_hash_length CHECK (
        pg_catalog.octet_length(token_hash) = 32
    ),
    CONSTRAINT ck_sessions_identity_epoch CHECK (identity_epoch >= 0),
    CONSTRAINT ck_sessions_audience_epoch CHECK (audience_epoch >= 0),
    CONSTRAINT ck_sessions_authentication_level CHECK (
        authentication_level IN ('password', 'mfa')
    ),
    -- This constrains the stored label; it does not establish that MFA occurred.
    CONSTRAINT ck_sessions_platform_mfa CHECK (
        audience <> 'platform' OR authentication_level = 'mfa'
    ),
    CONSTRAINT ck_sessions_csrf_key_id CHECK (
        pg_catalog.octet_length(csrf_key_id) BETWEEN 1 AND 32
        AND csrf_key_id COLLATE "C" ~ $key$\A[A-Za-z0-9_-]+\Z$key$
    ),
    CONSTRAINT ck_sessions_csrf_generation CHECK (csrf_generation >= 1),
    CONSTRAINT ck_sessions_csrf_salt_length CHECK (
        pg_catalog.octet_length(csrf_salt) = 32
    ),
    CONSTRAINT ck_sessions_required_times_finite CHECK (
        pg_catalog.isfinite(created_at)
        AND pg_catalog.isfinite(last_activity_at)
        AND pg_catalog.isfinite(idle_expires_at)
        AND pg_catalog.isfinite(absolute_expires_at)
    ),
    CONSTRAINT ck_sessions_revoked_at_finite CHECK (
        revoked_at IS NULL OR pg_catalog.isfinite(revoked_at)
    ),
    CONSTRAINT ck_sessions_expired_at_finite CHECK (
        expired_at IS NULL OR pg_catalog.isfinite(expired_at)
    ),
    CONSTRAINT ck_sessions_time_order CHECK (
        created_at <= last_activity_at
        AND last_activity_at < idle_expires_at
        AND idle_expires_at <= absolute_expires_at
    ),
    -- Seconds, not calendar days: these durations do not depend on DST/timezone.
    CONSTRAINT ck_sessions_absolute_duration CHECK (
        absolute_expires_at = created_at + CASE audience
            WHEN 'admin' THEN INTERVAL '604800 seconds'
            WHEN 'platform' THEN INTERVAL '28800 seconds'
        END
    ),
    CONSTRAINT ck_sessions_idle_duration CHECK (
        idle_expires_at <= last_activity_at + CASE audience
            WHEN 'admin' THEN INTERVAL '43200 seconds'
            WHEN 'platform' THEN INTERVAL '900 seconds'
        END
    )
);

-- +goose Down
-- Destructive rollback: only test in an explicitly authorized disposable DB.
-- Drop dependents first; preserve the identity schema and every B1 resource.
-- No CASCADE: later delivery dependencies must be rolled back separately first.
SET LOCAL ROLE tp_owner;
SET LOCAL search_path TO pg_catalog;

DROP TABLE identity.sessions;
DROP TABLE identity.audience_revocations;
