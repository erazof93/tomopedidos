-- B2-A / delivery A: static table constraints only. Not executed by this change.
-- Prerequisite: approved B1 schema/roles/default privileges already present.
-- Goose must use its default transaction; tp_owner is the object creator so B1
-- default privileges apply. SET LOCAL changes only this transaction's context,
-- not role attributes, memberships or persistent configuration.
-- Dynamic guards and coordinated credential/epoch writes belong to later deliveries.

-- +goose Up
SET LOCAL ROLE tp_owner;
SET LOCAL search_path TO pg_catalog;

CREATE TABLE identity.identities (
    id uuid NOT NULL,
    email_original text NOT NULL,
    email_canonical text COLLATE "C"
        GENERATED ALWAYS AS (
            pg_catalog.translate(
                email_original,
                'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
                'abcdefghijklmnopqrstuvwxyz'
            )
        ) STORED NOT NULL,
    status text NOT NULL DEFAULT 'pending',
    email_verified_at timestamptz,
    auth_epoch bigint NOT NULL DEFAULT 0,
    credential_revision bigint NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT pg_catalog.clock_timestamp(),

    CONSTRAINT pk_identities PRIMARY KEY (id),
    CONSTRAINT uq_identities_email_canonical UNIQUE (email_canonical),
    CONSTRAINT ck_identities_uuid_v4 CHECK (
        pg_catalog.substr(id::text, 15, 1) = '4'
        AND pg_catalog.substr(id::text, 20, 1) IN ('8', '9', 'a', 'b')
    ),
    CONSTRAINT ck_identities_email_grammar CHECK (
        email_original COLLATE "C" ~
        $email$\A[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+(\.[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+)*@[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+\Z$email$
    ),
    CONSTRAINT ck_identities_email_length CHECK (
        pg_catalog.octet_length(email_original) BETWEEN 3 AND 254
        AND pg_catalog.octet_length(
            pg_catalog.split_part(email_original, '@', 1)
        ) BETWEEN 1 AND 64
        AND pg_catalog.octet_length(
            pg_catalog.split_part(email_original, '@', 2)
        ) BETWEEN 1 AND 253
    ),
    CONSTRAINT ck_identities_email_domain_not_numeric CHECK (
        pg_catalog.split_part(email_original, '@', 2) COLLATE "C"
            !~ $domain$\A[0-9.]+\Z$domain$
    ),
    CONSTRAINT ck_identities_status CHECK (
        status IN ('pending', 'active', 'disabled')
    ),
    CONSTRAINT ck_identities_active_verified CHECK (
        status <> 'active' OR email_verified_at IS NOT NULL
    ),
    CONSTRAINT ck_identities_auth_epoch CHECK (auth_epoch >= 0),
    CONSTRAINT ck_identities_credential_revision CHECK (credential_revision >= 0),
    CONSTRAINT ck_identities_created_at_finite CHECK (
        pg_catalog.isfinite(created_at)
    ),
    CONSTRAINT ck_identities_verified_at_finite CHECK (
        email_verified_at IS NULL OR pg_catalog.isfinite(email_verified_at)
    )
);

CREATE TABLE identity.identity_credentials (
    identity_id uuid NOT NULL,
    password_hash text NOT NULL,
    changed_at timestamptz NOT NULL,

    CONSTRAINT pk_identity_credentials PRIMARY KEY (identity_id),
    CONSTRAINT fk_identity_credentials_identity FOREIGN KEY (identity_id)
        REFERENCES identity.identities (id)
        ON UPDATE RESTRICT ON DELETE RESTRICT NOT DEFERRABLE,
    CONSTRAINT ck_identity_credentials_phc_length CHECK (
        pg_catalog.octet_length(password_hash) BETWEEN 1 AND 256
    ),
    -- Lexical PHC only: standard base64, not the session token's base64url.
    -- Decoding/canonicality, allowed parameter profiles and resource ceilings
    -- still require the approved Go verifier; this CHECK proves no password.
    CONSTRAINT ck_identity_credentials_phc_format CHECK (
        password_hash COLLATE "C" ~
        $phc$\A\$argon2id\$v=19\$m=[1-9][0-9]*,t=[1-9][0-9]*,p=[1-9][0-9]*\$[A-Za-z0-9+/]{22}\$[A-Za-z0-9+/]{43}\Z$phc$
    ),
    CONSTRAINT ck_identity_credentials_changed_at_finite CHECK (
        pg_catalog.isfinite(changed_at)
    )
);

-- +goose Down
-- Destructive rollback: only test in an explicitly authorized disposable DB.
-- Undo 00002 first. No CASCADE, schema drops or changes to B1 bootstrap resources.
SET LOCAL ROLE tp_owner;
SET LOCAL search_path TO pg_catalog;

DROP TABLE identity.identity_credentials;
DROP TABLE identity.identities;
