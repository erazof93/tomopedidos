\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
BEGIN READ ONLY;
DO $final$ DECLARE s identity.sessions%ROWTYPE; BEGIN
 SELECT * INTO STRICT s FROM identity.sessions WHERE session_id='f6100000-0000-4000-8000-000000000001';
 IF s.revoked_at IS NULL OR s.expired_at IS NOT NULL OR s.revoked_at<s.created_at
 OR s.last_activity_at IS DISTINCT FROM s.created_at
 OR s.idle_expires_at IS DISTINCT FROM s.created_at+interval '12 hours'
 OR s.absolute_expires_at IS DISTINCT FROM s.created_at+interval '7 days'
 OR s.identity_epoch<>0 OR s.audience_epoch<>0
 OR (SELECT auth_epoch FROM identity.identities WHERE id=s.identity_id)<>0
 OR (SELECT credential_revision FROM identity.identities WHERE id=s.identity_id)<>1
 OR EXISTS(SELECT 1 FROM identity.audience_revocations WHERE identity_id=s.identity_id AND auth_epoch<>0)
 THEN RAISE EXCEPTION 'Revocation/renewal altered terminal, timestamps or epochs'; END IF;
END; $final$;
SELECT 'F5C committed revocation survived: no activity/deadline/epoch changes' AS result;
ROLLBACK;
