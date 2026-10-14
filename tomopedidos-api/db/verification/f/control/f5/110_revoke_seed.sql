\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
BEGIN;
DO $empty$ BEGIN
 IF EXISTS(SELECT 1 FROM identity.identities) OR EXISTS(SELECT 1 FROM identity.sessions) THEN RAISE EXCEPTION 'Revoke fixture needs empty F'; END IF;
END; $empty$;
INSERT INTO identity.identities(id,email_original,status,email_verified_at,credential_revision,created_at)
VALUES('f6000000-0000-4000-8000-000000000001','postrevoke@example.invalid','active',clock_timestamp()-interval '1 hour',1,clock_timestamp()-interval '1 hour');
INSERT INTO identity.audience_revocations(identity_id,audience)
SELECT 'f6000000-0000-4000-8000-000000000001'::uuid,a FROM unnest(ARRAY['admin','platform']) a;
INSERT INTO identity.identity_credentials(identity_id,password_hash,changed_at)
VALUES('f6000000-0000-4000-8000-000000000001','$argon2id$v=19$m=19456,t=2,p=1$AAAAAAAAAAAAAAAAAAAAAA$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',clock_timestamp()-interval '1 hour');
WITH t AS(SELECT clock_timestamp()-interval '1 hour' n)
INSERT INTO identity.sessions(session_id,identity_id,audience,token_hash,identity_epoch,audience_epoch,authentication_level,csrf_key_id,csrf_salt,created_at,last_activity_at,idle_expires_at,absolute_expires_at)
SELECT 'f6100000-0000-4000-8000-000000000001','f6000000-0000-4000-8000-000000000001','admin',sha256(convert_to('F5C postrevoke synthetic','UTF8')),0,0,'password','f-postrevoke',decode(repeat('00',32),'hex'),n,n,n+interval '12 hours',n+interval '7 days' FROM t;
COMMIT;
