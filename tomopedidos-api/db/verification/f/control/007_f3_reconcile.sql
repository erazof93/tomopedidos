-- Read-only reconciliation after stopped fixture; never reruns migration or test.
\set ON_ERROR_STOP on
BEGIN READ ONLY;
\ir /f/control/001_preflight.sql
SELECT max(version_id) AS applied_version FROM migration_meta.goose_db_version WHERE is_applied;
SELECT 'identities' AS relation,count(*) FROM identity.identities
UNION ALL SELECT 'identity_credentials',count(*) FROM identity.identity_credentials
UNION ALL SELECT 'audience_revocations',count(*) FROM identity.audience_revocations
UNION ALL SELECT 'sessions',count(*) FROM identity.sessions;
DO $empty$
BEGIN
 IF EXISTS(SELECT 1 FROM identity.identities) OR EXISTS(SELECT 1 FROM identity.identity_credentials)
 OR EXISTS(SELECT 1 FROM identity.audience_revocations) OR EXISTS(SELECT 1 FROM identity.sessions)
 THEN RAISE EXCEPTION 'F3 aborted fixture left unexpected data'; END IF;
END;
$empty$;
SELECT 'F3 failed fixture rollback: no persistent rows' AS result;
ROLLBACK;
