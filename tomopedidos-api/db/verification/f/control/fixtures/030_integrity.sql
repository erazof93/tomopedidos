-- F synthetic fixtures, admin only, always ROLLBACK. No external DB data.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
BEGIN;
SET LOCAL search_path TO pg_catalog;
SET LOCAL TIME ZONE 'UTC';
DO $context$
BEGIN
    IF session_user <> 'tomopedidos_bootstrap' OR current_user <> session_user
        OR EXISTS (SELECT 1 FROM identity.identities)
        OR EXISTS (SELECT 1 FROM identity.sessions) THEN
        RAISE EXCEPTION 'F integrity requires bootstrap and empty isolated fixture tables';
    END IF;
END;
$context$;
CREATE TEMP TABLE f_assertions (name text PRIMARY KEY, expected_state text);
CREATE FUNCTION pg_temp.expect_rejection(p_name text,p_sql text,p_state text) RETURNS void
LANGUAGE plpgsql SECURITY INVOKER AS $expect$
DECLARE v_state text;
BEGIN
    BEGIN
        EXECUTE p_sql;
        RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='F negative unexpectedly accepted';
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE;
        IF v_state <> p_state THEN
            RAISE EXCEPTION 'F case % expected %, observed %',p_name,p_state,v_state;
        END IF;
    END;
    INSERT INTO pg_temp.f_assertions VALUES(p_name,p_state);
END;
$expect$;
INSERT INTO identity.identities(id,email_original,status,email_verified_at,credential_revision)
VALUES('f0000000-0000-4000-8000-000000000001','Case+Tag@example.invalid','active',clock_timestamp(),1);
INSERT INTO identity.audience_revocations(identity_id,audience)
SELECT 'f0000000-0000-4000-8000-000000000001'::uuid,a FROM unnest(ARRAY['admin','platform']) AS a;
INSERT INTO identity.identity_credentials(identity_id,password_hash,changed_at)
VALUES('f0000000-0000-4000-8000-000000000001',
 '$argon2id$v=19$m=19456,t=2,p=1$AAAAAAAAAAAAAAAAAAAAAA$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',clock_timestamp());
-- Accepted simultaneous boundaries: local64, label63 and total254, plus dot/+ preservation.
INSERT INTO identity.identities(id,email_original)
SELECT ('f0000000-0000-4000-8000-'||lpad((100+ord)::text,12,'0'))::uuid,email
FROM unnest(ARRAY[repeat('a',64)||'@example.invalid','x@'||repeat('b',63)||'.invalid',
    repeat('a',64)||'@'||repeat('b',63)||'.'||repeat('c',63)||'.'||repeat('d',61),
    'a.b+tag@example.invalid']) WITH ORDINALITY AS accepted(email,ord);
WITH t AS (SELECT clock_timestamp() AS n)
INSERT INTO identity.sessions(session_id,identity_id,audience,token_hash,identity_epoch,audience_epoch,
    authentication_level,csrf_key_id,csrf_salt,created_at,last_activity_at,idle_expires_at,absolute_expires_at)
SELECT 'f1000000-0000-4000-8000-000000000001','f0000000-0000-4000-8000-000000000001','admin',
    sha256(convert_to('F integrity synthetic','UTF8')),0,0,'password','f-test',decode(repeat('00',32),'hex'),
    n,n,n+interval '43200 seconds',n+interval '604800 seconds' FROM t;
-- Email corpus: controls, non-ASCII, numeric domain, dots, labels and local length.
DO $emails$
DECLARE v_email text; v_n integer := 0;
BEGIN
    FOREACH v_email IN ARRAY ARRAY['two@@example.invalid','a..b@example.invalid','a@123.456',
        'a@-bad.invalid','a@example.invalid.','a@single',' a@example.invalid','a@example.invalid ',
        'a b@example.invalid',E'a\t@example.invalid','aé@example.invalid',
        repeat('a',65)||'@example.invalid','a@'||repeat('b',64)||'.invalid',
        repeat('a',64)||'@'||repeat('b',63)||'.'||repeat('c',63)||'.'||repeat('d',62)] LOOP
        v_n := v_n+1;
        PERFORM pg_temp.expect_rejection('email_'||v_n,format(
            'INSERT INTO identity.identities(id,email_original) VALUES (%L,%L)',
            'f0000000-0000-4000-8000-000000000099',v_email),'23514');
    END LOOP;
END;
$emails$;
SELECT pg_temp.expect_rejection('canonical_unique',
 $$INSERT INTO identity.identities(id,email_original) VALUES('f0000000-0000-4000-8000-000000000002','case+tag@EXAMPLE.invalid')$$,'23505');
SELECT pg_temp.expect_rejection('identity_uuid',
 $$INSERT INTO identity.identities(id,email_original) VALUES('f0000000-0000-1000-8000-000000000002','uuid@example.invalid')$$,'23514');
SELECT pg_temp.expect_rejection('active_unverified',
 $$INSERT INTO identity.identities(id,email_original,status) VALUES('f0000000-0000-4000-8000-000000000002','verify@example.invalid','active')$$,'23514');
SELECT pg_temp.expect_rejection('null_email',
 $$INSERT INTO identity.identities(id,email_original) VALUES('f0000000-0000-4000-8000-000000000002',NULL)$$,'23502');
SELECT pg_temp.expect_rejection('identity_epoch_decrease',
 $$UPDATE identity.identities SET auth_epoch=-1 WHERE id='f0000000-0000-4000-8000-000000000001'$$,'23514');
SELECT pg_temp.expect_rejection('revision_decrease',
 $$UPDATE identity.identities SET credential_revision=0 WHERE id='f0000000-0000-4000-8000-000000000001'$$,'23514');
SELECT pg_temp.expect_rejection('identity_key_immutable',
 $$UPDATE identity.identities SET id='f0000000-0000-4000-8000-000000000009' WHERE id='f0000000-0000-4000-8000-000000000001'$$,'23514');
SELECT pg_temp.expect_rejection('identity_created_immutable',
 $$UPDATE identity.identities SET created_at=created_at-interval '1 second' WHERE id='f0000000-0000-4000-8000-000000000001'$$,'23514');
SELECT pg_temp.expect_rejection('credential_phc',
 $$UPDATE identity.identity_credentials SET password_hash='not-a-PHC' WHERE identity_id='f0000000-0000-4000-8000-000000000001'$$,'23514');
SELECT pg_temp.expect_rejection('credential_fk',
 $$INSERT INTO identity.identity_credentials VALUES('f0000000-0000-4000-8000-000000000009','$argon2id$v=19$m=19456,t=2,p=1$AAAAAAAAAAAAAAAAAAAAAA$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',clock_timestamp())$$,'23503');
SELECT pg_temp.expect_rejection('identity_restrict_delete',
 $$DELETE FROM identity.identities WHERE id='f0000000-0000-4000-8000-000000000001'$$,'23001');
SELECT pg_temp.expect_rejection('audience_epoch_negative',
 $$UPDATE identity.audience_revocations SET auth_epoch=-1 WHERE identity_id='f0000000-0000-4000-8000-000000000001' AND audience='admin'$$,'23514');
SELECT pg_temp.expect_rejection('audience_key_immutable',
 $$UPDATE identity.audience_revocations SET audience='other' WHERE identity_id='f0000000-0000-4000-8000-000000000001' AND audience='admin'$$,'23514');
-- Session static CHECKs (INSERT clone so UPDATE guards cannot mask CHECK coverage).
DO $session_checks$
DECLARE v record; v_columns text; v_select text;
BEGIN
    v_columns := 'session_id,identity_id,audience,token_hash,identity_epoch,audience_epoch,authentication_level,csrf_key_id,csrf_generation,csrf_salt,created_at,last_activity_at,idle_expires_at,absolute_expires_at';
    FOR v IN SELECT * FROM (VALUES
        ('digest31','token_hash', $$decode(repeat('00',31),'hex')$$,'23514'),
        ('snapshot_negative','identity_epoch','-1','23514'),
        ('csrf_key','csrf_key_id', $$'bad key'$$,'23514'),
        ('csrf_generation','csrf_generation','0','23514'),
        ('csrf_salt','csrf_salt', $$decode(repeat('00',31),'hex')$$,'23514'),
        ('session_uuid','session_id', $$'f1000000-0000-1000-8000-000000000002'::uuid$$,'23514'),
        ('session_level','authentication_level', $$'unknown'$$,'23514'),
        ('platform_password','audience', $$'platform'$$,'23514'),
        ('session_infinite','last_activity_at', $$'infinity'::timestamptz$$,'23514'),
        ('absolute_duration','absolute_expires_at', $$absolute_expires_at+interval '1 second'$$,'23514'),
        ('idle_duration','idle_expires_at', $$created_at+interval '43201 seconds'$$,'23514'),
        ('session_null','token_hash','NULL::bytea','23502'),
        ('session_fk','identity_id', $$'f0000000-0000-4000-8000-000000000009'::uuid$$,'23503')
    ) AS cases(name,column_name,expression,state) LOOP
        SELECT string_agg(CASE WHEN c=v.column_name THEN v.expression
            WHEN c='session_id' THEN $$'f1000000-0000-4000-8000-000000000002'::uuid$$
            WHEN c='token_hash' THEN $$sha256(convert_to('F unique clone','UTF8'))$$ ELSE c END,',' ORDER BY ord)
        INTO v_select FROM unnest(string_to_array(v_columns,',')) WITH ORDINALITY AS cols(c,ord);
        PERFORM pg_temp.expect_rejection(v.name,'INSERT INTO identity.sessions('||v_columns||') SELECT '||
            v_select||$$ FROM identity.sessions WHERE session_id='f1000000-0000-4000-8000-000000000001'$$,v.state);
    END LOOP;
END;
$session_checks$;
SELECT pg_temp.expect_rejection('session_digest_immutable',
 $$UPDATE identity.sessions SET token_hash=sha256(convert_to('different','UTF8'))$$,'23514');
SELECT pg_temp.expect_rejection('session_snapshot_immutable',
 $$UPDATE identity.sessions SET identity_epoch=1$$,'23514');
SELECT pg_temp.expect_rejection('session_absolute_immutable',
 $$UPDATE identity.sessions SET absolute_expires_at=absolute_expires_at+interval '1 second'$$,'23514');
SELECT pg_temp.expect_rejection('csrf_binding_immutable',
 $$UPDATE identity.sessions SET csrf_generation=2$$,'23514');
UPDATE identity.sessions SET revoked_at=clock_timestamp();
SELECT pg_temp.expect_rejection('revocation_terminal', $$UPDATE identity.sessions SET revoked_at=NULL$$,'23514');
SELECT pg_temp.expect_rejection('terminal_activity', $$UPDATE identity.sessions SET last_activity_at=last_activity_at+interval '1 second'$$,'23514');
UPDATE identity.sessions SET expired_at=clock_timestamp();
SELECT pg_temp.expect_rejection('expiry_terminal', $$UPDATE identity.sessions SET expired_at=NULL$$,'23514');
DO $positive$
BEGIN
    IF (SELECT email_canonical FROM identity.identities WHERE id='f0000000-0000-4000-8000-000000000001') <> 'case+tag@example.invalid'
        OR (SELECT count(*) FROM pg_temp.f_assertions) <> 47 THEN
        RAISE EXCEPTION 'F integrity positive/corpus count differs';
    END IF;
    RAISE NOTICE 'F integrity corpus and guard checks passed';
END;
$positive$;
ROLLBACK;
