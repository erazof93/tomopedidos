-- Read-only exact reconciliation before reusing the previously committed F6 seed.
\set ON_ERROR_STOP on
BEGIN READ ONLY;
\ir /f/control/001_preflight.sql
DO $exact$
BEGIN
 IF (SELECT count(*) FROM identity.identities)<>1
 OR NOT EXISTS(SELECT 1 FROM identity.identities WHERE id='f3000000-0000-4000-8000-000000000001'
 AND email_original='fault-f@example.invalid' AND status='pending' AND auth_epoch=0 AND credential_revision=0)
 OR EXISTS(SELECT 1 FROM identity.identity_credentials)
 OR (SELECT count(*) FROM identity.audience_revocations)<>2
 OR (SELECT count(*) FROM identity.audience_revocations WHERE identity_id='f3000000-0000-4000-8000-000000000001' AND audience IN('admin','platform') AND auth_epoch=0)<>2
 OR (SELECT count(*) FROM identity.sessions)<>2
 OR (SELECT count(*) FROM identity.sessions s WHERE identity_id='f3000000-0000-4000-8000-000000000001'
 AND audience='admin' AND identity_epoch=0 AND audience_epoch=0 AND revoked_at IS NULL AND expired_at IS NULL
 AND authentication_level='password' AND csrf_key_id='f-test' AND csrf_generation=1
 AND csrf_salt=decode(repeat('00',32),'hex')
 AND last_activity_at=created_at AND idle_expires_at=created_at+interval '12 hours'
 AND absolute_expires_at=created_at+interval '7 days'
 AND absolute_expires_at<clock_timestamp()-interval '30 days'
 AND EXISTS(SELECT 1 FROM generate_series(1,2) k
 WHERE s.session_id=('f3100000-0000-4000-'||'8000-'||lpad(k::text,12,'0'))::uuid
 AND s.token_hash=sha256(convert_to('F fault fixture '||k,'UTF8'))))<>2
 OR EXISTS(SELECT 1 FROM pg_stat_activity WHERE datname=current_database() AND application_name LIKE 'tp-b2a-f-20261014-r01:%')
 OR EXISTS(SELECT 1 FROM pg_prepared_xacts WHERE database=current_database())
 OR (SELECT max(version_id) FROM (SELECT DISTINCT ON(version_id) version_id,is_applied FROM migration_meta.goose_db_version ORDER BY version_id,id DESC) x WHERE is_applied)<>4
 THEN RAISE EXCEPTION 'F6 retained fixtures/state differ; no reuse authorized'; END IF;
END; $exact$;
SELECT 'F6 exact retained fixtures reusable: identity1 credentials0 audiences2 sessions2; no test connections/prepared transactions' AS result;
ROLLBACK;
