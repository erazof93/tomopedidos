-- Noninteractive replacement for095 transport prompt. Results withheld until COMMIT.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
BEGIN;
SET LOCAL application_name TO 'tp-b2a-f-20261014-r01:ambiguous-cleanup';
SELECT examined,deleted,skipped FROM identity.cleanup_sessions(100) \gset f_pending_
SELECT :f_pending_examined = 2 AND :f_pending_deleted = 2 AND :f_pending_skipped = 0 AS f_batch_ok \gset
\if :f_batch_ok
\else
DO $wrong$ BEGIN RAISE EXCEPTION 'Unexpected synthetic pending batch'; END; $wrong$;
\endif
COMMIT;
\echo 'CLIENT_COMMIT_CONFIRMED'
