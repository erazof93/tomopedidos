-- F-only COMMITTED synthetic fixtures for separately authorized fault injection.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
BEGIN;
SET LOCAL search_path TO pg_catalog;
SET LOCAL TIME ZONE 'UTC';
DO $empty$ BEGIN
    IF session_user<>'tomopedidos_bootstrap' OR current_user<>session_user
        OR EXISTS (SELECT 1 FROM identity.identities) OR EXISTS (SELECT 1 FROM identity.sessions) THEN
        RAISE EXCEPTION 'Fault fixture requires empty dedicated F database';
    END IF;
END; $empty$;
INSERT INTO identity.identities(id,email_original,created_at)
VALUES('f3000000-0000-4000-8000-000000000001','fault-f@example.invalid',clock_timestamp()-interval '60 days');
INSERT INTO identity.audience_revocations(identity_id,audience)
SELECT 'f3000000-0000-4000-8000-000000000001'::uuid,a FROM unnest(ARRAY['admin','platform']) AS a;
WITH t AS (SELECT clock_timestamp() AS n)
INSERT INTO identity.sessions(session_id,identity_id,audience,token_hash,identity_epoch,audience_epoch,
    authentication_level,csrf_key_id,csrf_salt,created_at,last_activity_at,idle_expires_at,absolute_expires_at)
SELECT ('f3100000-0000-4000-8000-'||lpad(k::text,12,'0'))::uuid,
    'f3000000-0000-4000-8000-000000000001','admin',sha256(convert_to('F fault fixture '||k,'UTF8')),
    0,0,'password','f-test',decode(repeat('00',32),'hex'),n-interval '41 days',n-interval '41 days',
    n-interval '40 days 12 hours',n-interval '34 days' FROM t CROSS JOIN generate_series(1,2) AS k;
COMMIT;
