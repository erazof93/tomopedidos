-- Real bootstrap fixture-holder, separate from operational maintenance connection.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
BEGIN;
SET LOCAL application_name TO 'tp-b2a-f-20261014-r01:f6-holder';
SELECT id FROM identity.identities WHERE id='f3000000-0000-4000-8000-000000000001' FOR UPDATE \gset f_holder_
SELECT pg_backend_pid() AS holder_pid,backend_start FROM pg_stat_activity WHERE pid=pg_backend_pid();
\echo 'F6_HOLDER_LOCK_ACQUIRED'
\prompt 'Release only after failed-operation rollback evidence, then enter: ' f_release
ROLLBACK;
