-- Manual connection A. Authorized F backend only; keep open until B test completes.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
BEGIN;
SET LOCAL application_name TO 'tp-b2a-f-20261014-r01:fault-holder';
SELECT id FROM identity.identities WHERE id='f3000000-0000-4000-8000-000000000001' FOR UPDATE \gset f_holder_
SELECT pg_backend_pid() AS holder_pid;
\prompt 'F holder: release ONLY after B outcome recorded; press enter: ' f_release
ROLLBACK;
