-- Expected SQL22023; ON_ERROR_STOP closes and rolls back, no success marker.
\set ON_ERROR_STOP on
\set VERBOSITY verbose
\ir /f/control/001_preflight.sql
BEGIN;
SELECT examined,deleted,skipped FROM identity.cleanup_sessions(0);
COMMIT;
\echo 'CLIENT_COMMIT_CONFIRMED'
