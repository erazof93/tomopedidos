-- Separately authorized removal of EXACT synthetic F fixtures, never real data.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
BEGIN;
DELETE FROM identity.sessions WHERE identity_id='f3000000-0000-4000-8000-000000000001';
DELETE FROM identity.audience_revocations WHERE identity_id='f3000000-0000-4000-8000-000000000001';
DELETE FROM identity.identities WHERE id='f3000000-0000-4000-8000-000000000001';
COMMIT;
