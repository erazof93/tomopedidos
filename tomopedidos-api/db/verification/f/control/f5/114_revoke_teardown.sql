-- Authorized exact synthetic fixture removal, after113 evidence only.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
BEGIN;
DELETE FROM identity.sessions WHERE session_id='f6100000-0000-4000-8000-000000000001' AND identity_id='f6000000-0000-4000-8000-000000000001';
DELETE FROM identity.identity_credentials WHERE identity_id='f6000000-0000-4000-8000-000000000001';
DELETE FROM identity.audience_revocations WHERE identity_id='f6000000-0000-4000-8000-000000000001';
DELETE FROM identity.identities WHERE id='f6000000-0000-4000-8000-000000000001';
COMMIT;
