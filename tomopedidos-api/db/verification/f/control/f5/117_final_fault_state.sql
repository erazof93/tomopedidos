\set ON_ERROR_STOP on
BEGIN READ ONLY;
\ir /f/control/001_preflight.sql
DO $final$
BEGIN
 IF EXISTS(SELECT 1 FROM identity.identities) OR EXISTS(SELECT 1 FROM identity.identity_credentials)
 OR EXISTS(SELECT 1 FROM identity.audience_revocations) OR EXISTS(SELECT 1 FROM identity.sessions)
 OR (SELECT max(version_id) FROM migration_meta.goose_db_version WHERE is_applied)<>4
 OR EXISTS(SELECT 1 FROM pg_stat_activity WHERE datname=current_database() AND application_name LIKE 'tp-b2a-f-20261014-r01:%')
 OR EXISTS(SELECT 1 FROM pg_prepared_xacts WHERE database=current_database())
 THEN RAISE EXCEPTION 'F5C final state contains rows, actors, prepared transactions or version drift'; END IF;
END; $final$;
SELECT system_identifier::text,current_database(),current_setting('server_version_num') FROM pg_control_system();
SELECT 'F5C final state passed: empty tables, Goose4, no test connections/prepared transactions' AS result;
ROLLBACK;
