-- Synthetic 101 eligible sessions; all changes including DELETE are rolled back.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
BEGIN;
DO $empty$ BEGIN
 IF EXISTS(SELECT 1 FROM identity.sessions) OR EXISTS(SELECT 1 FROM identity.identities) THEN RAISE EXCEPTION 'Full batch requires empty F'; END IF;
END; $empty$;
INSERT INTO identity.identities(id,email_original,status,email_verified_at,created_at)
VALUES('e3000000-0000-4000-8000-000000000001','fullbatch@example.invalid','active',clock_timestamp()-interval '60 days',clock_timestamp()-interval '60 days');
INSERT INTO identity.audience_revocations(identity_id,audience)
VALUES('e3000000-0000-4000-8000-000000000001','admin');
INSERT INTO identity.identity_credentials(identity_id,password_hash,changed_at)
VALUES('e3000000-0000-4000-8000-000000000001','$argon2id$v=19$m=19456,t=2,p=1$AAAAAAAAAAAAAAAAAAAAAA$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',clock_timestamp()-interval '60 days');
WITH t AS(SELECT clock_timestamp() AS n)
INSERT INTO identity.sessions(session_id,identity_id,audience,token_hash,identity_epoch,audience_epoch,authentication_level,csrf_key_id,csrf_salt,created_at,last_activity_at,idle_expires_at,absolute_expires_at)
SELECT ('e3100000-0000-4000-8000-'||lpad(k::text,12,'0'))::uuid,'e3000000-0000-4000-8000-000000000001','admin',sha256(convert_to('fullbatch '||k,'UTF8')),0,0,'password','f-batch',decode(repeat('00',32),'hex'),n-interval '41 days',n-interval '41 days',n-interval '40 days 12 hours',n-interval '34 days'
FROM t CROSS JOIN generate_series(1,101) k;
SET LOCAL ROLE tomopedidos_session_maintenance;
DO $batch$ DECLARE v record; BEGIN
 SELECT * INTO STRICT v FROM identity.cleanup_sessions(100);
 IF v.examined<>100 OR v.deleted<>100 OR v.skipped<>0 THEN RAISE EXCEPTION 'Full100 cap/result failed'; END IF;
END; $batch$;
RESET ROLE;
DO $survivors$ BEGIN
 IF (SELECT count(*) FROM identity.sessions)<>1
 OR (SELECT count(*) FROM identity.identities)<>1 OR (SELECT auth_epoch FROM identity.identities)<>0
 OR (SELECT count(*) FROM identity.identity_credentials)<>1 OR (SELECT count(*) FROM identity.audience_revocations)<>1
 OR (SELECT auth_epoch FROM identity.audience_revocations)<>0
 THEN RAISE EXCEPTION 'Cleanup damaged parents/credentials/epochs or batch survivor'; END IF;
 RAISE NOTICE 'F full100 batch passed: 100 deleted, 1 retained; parents/credential/epochs intact';
END; $survivors$;
ROLLBACK;
