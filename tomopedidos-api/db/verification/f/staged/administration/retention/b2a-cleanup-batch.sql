-- F target-only staged copy; original hash is in stage-manifest.json.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
-- PREPARED ONLY, ACTUAL DELETE if executed. Separate cleanup authorization required.
-- Independent real maintenance login, one invocation/transaction, no looping/retry.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL search_path TO pg_catalog;
SET LOCAL lock_timeout TO '1s';
SET LOCAL statement_timeout TO '2s';
SET LOCAL idle_in_transaction_session_timeout TO '1s';
DO $caller$
BEGIN
    IF current_database() <> 'tp_b2a_f_20261014_r01'
        OR current_setting('server_version_num')::integer / 100 <> 1800
        OR session_user <> 'tomopedidos_session_maintenance' OR current_user <> session_user THEN
        RAISE EXCEPTION 'Use separately authorized local PG18 maintenance login';
    END IF;
END;
$caller$;
SELECT examined,deleted,skipped,checked_at FROM identity.cleanup_sessions(100) \gset e_
COMMIT;
-- No result displayed before confirmed commit. Lost commit response => no claim/retry.
\echo 'E batch committed: examined=' :e_examined 'deleted=' :e_deleted 'skipped=' :e_skipped
