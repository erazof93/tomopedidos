-- REAL maintenance login; only approved harness may disconnect/drop COMMIT ACK.
-- Does NOT inject a failure on its own. No automatic retries/reconnection/secret output.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
BEGIN;
SET LOCAL application_name TO 'tp-b2a-f-20261014-r01:ambiguous-cleanup';
SELECT examined,deleted,skipped FROM identity.cleanup_sessions(100) \gset f_ambiguous_
\prompt 'F harness: disconnect BEFORE COMMIT or arm lost COMMIT ACK; continue only when ready: ' f_continue
COMMIT;
\echo 'Confirmed COMMIT response received; this run is NOT an ambiguous-ACK test.'
