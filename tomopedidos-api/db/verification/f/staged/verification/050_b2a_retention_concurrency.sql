-- F target-only staged copy; original hash is in stage-manifest.json.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
-- PREPARED ONLY, destructive synthetic fixtures in isolated authorized DB; ROLLBACK.
-- Requires A-D/E applied, E enabled; admin session tests behavior, not real login.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL search_path TO pg_catalog;
SET LOCAL TIME ZONE 'UTC';
SET LOCAL lock_timeout TO '1s';
SET LOCAL statement_timeout TO '2s';
\ir ../administration/b2a-role-preflight.sql
SET LOCAL tomopedidos.d_stage TO 'enabled';
\ir ../administration/b2a-assert-state.sql
SET LOCAL tomopedidos.e_stage TO 'enabled';
\ir ../administration/retention/b2a-cleanup-assert.sql
DO $empty$
BEGIN
    IF EXISTS (SELECT 1 FROM identity.sessions) THEN
        RAISE EXCEPTION '050 requires an empty isolated fixture database';
    END IF;
    IF EXISTS (SELECT 1 FROM identity.identities WHERE id = 'e0000000-0000-4000-8000-000000000001') THEN
        RAISE EXCEPTION 'Fixture identity collision';
    END IF;
END;
$empty$;
INSERT INTO identity.identities (id,email_original,status,email_verified_at,created_at,auth_epoch)
VALUES ('e0000000-0000-4000-8000-000000000001','retention-e@example.invalid','active',
    clock_timestamp() - INTERVAL '60 days',clock_timestamp() - INTERVAL '60 days',1);
INSERT INTO identity.audience_revocations (identity_id,audience)
SELECT 'e0000000-0000-4000-8000-000000000001'::uuid,a FROM unnest(ARRAY['admin','platform']) AS a;
CREATE TEMP TABLE e_fixture_clock AS SELECT clock_timestamp() AS t;
INSERT INTO identity.sessions (session_id,identity_id,audience,token_hash,identity_epoch,audience_epoch,
    authentication_level,csrf_key_id,csrf_generation,csrf_salt,created_at,last_activity_at,
    idle_expires_at,absolute_expires_at,revoked_at,expired_at)
SELECT ('e1000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid,
    'e0000000-0000-4000-8000-000000000001'::uuid,'admin',sha256(convert_to('E fixture ' || n,'UTF8')),
    CASE WHEN n IN (4,5) THEN 0 ELSE 1 END,0,'password','e-fixture',1,decode(repeat('00',32),'hex'),
    CASE WHEN n IN (1,5,6,7) THEN t - INTERVAL '41 days'
         WHEN n = 8 THEN t - INTERVAL '31 days'
         WHEN n = 2 THEN t - INTERVAL '2 days' ELSE t END,
    CASE WHEN n IN (1,5,6,7) THEN t - INTERVAL '41 days'
         WHEN n = 8 THEN t - INTERVAL '25 days'
         WHEN n = 2 THEN t - INTERVAL '2 days' ELSE t END,
    CASE WHEN n IN (1,5,6,7) THEN t - INTERVAL '40 days 12 hours'
         WHEN n = 8 THEN t - INTERVAL '24 days 12 hours'
         WHEN n = 2 THEN t - INTERVAL '1 day 12 hours' ELSE t + INTERVAL '12 hours' END,
    CASE WHEN n IN (1,5,6,7) THEN t - INTERVAL '34 days'
         WHEN n = 8 THEN t - INTERVAL '24 days'
         WHEN n = 2 THEN t + INTERVAL '5 days' ELSE t + INTERVAL '7 days' END,
    CASE WHEN n = 7 THEN t - INTERVAL '40 days 18 hours' END,
    CASE WHEN n = 6 THEN t END
FROM generate_series(1,8) AS n CROSS JOIN e_fixture_clock;
-- Epoch-only old (5) deletes naturally; epoch-only unexpired (4) stays.
-- Late detection (6) must not postpone natural terminality. created_at is not anchor (8).
SAVEPOINT e_batch;
SET LOCAL ROLE tomopedidos_session_maintenance;
DO $batch$
DECLARE v record;
BEGIN
    SELECT * INTO STRICT v FROM identity.cleanup_sessions(100);
    IF v.examined <> 4 OR v.deleted <> 4 OR v.skipped <> 0 THEN RAISE EXCEPTION 'E retention counts differ'; END IF;
END;
$batch$;
RESET ROLE;
DO $remaining$
BEGIN
    IF (SELECT count(*) FROM identity.sessions) <> 4
        OR EXISTS (SELECT 1 FROM identity.sessions WHERE session_id IN
            ('e1000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000005',
             'e1000000-0000-4000-8000-000000000006','e1000000-0000-4000-8000-000000000007'))
        OR (SELECT auth_epoch FROM identity.identities WHERE id = 'e0000000-0000-4000-8000-000000000001') <> 1
        OR (SELECT count(*) FROM identity.audience_revocations WHERE identity_id = 'e0000000-0000-4000-8000-000000000001') <> 2 THEN
        RAISE EXCEPTION 'Retention survivors/parents differ';
    END IF;
END;
$remaining$;
ROLLBACK TO SAVEPOINT e_batch;
DO $restored$
BEGIN
    IF (SELECT count(*) FROM identity.sessions) <> 8 THEN RAISE EXCEPTION 'Rollback failed to restore sessions'; END IF;
END;
$restored$;
SAVEPOINT e_limit;
SET LOCAL ROLE tomopedidos_session_maintenance;
DO $limit$
DECLARE v record; v_size integer;
BEGIN
    FOREACH v_size IN ARRAY ARRAY[NULL::integer,0,-1,101] LOOP
        BEGIN
            PERFORM * FROM identity.cleanup_sessions(v_size);
            RAISE EXCEPTION 'Invalid batch accepted';
        EXCEPTION WHEN invalid_parameter_value THEN NULL;
        END;
    END LOOP;
    SELECT * INTO STRICT v FROM identity.cleanup_sessions(1);
    IF v.examined <> 1 OR v.deleted <> 1 THEN RAISE EXCEPTION 'Batch cap failed'; END IF;
    BEGIN
        PERFORM * FROM identity.cleanup_sessions(1);
        RAISE EXCEPTION 'Second call in same transaction accepted';
    EXCEPTION WHEN invalid_transaction_state THEN NULL;
    END;
END;
$limit$;
RESET ROLE;
ROLLBACK TO SAVEPOINT e_limit;
-- Deterministic exact cutoff arithmetic, independent of moving wall clock.
DO $boundary$
DECLARE v_t timestamptz := '2026-01-01 00:00:00+00';
BEGIN
    IF NOT (LEAST(v_t,NULL::timestamptz) <= v_t + INTERVAL '2592000 seconds' - INTERVAL '2592000 seconds')
        OR (v_t + INTERVAL '1 microsecond' <= v_t + INTERVAL '2592000 seconds' - INTERVAL '2592000 seconds') THEN
        RAISE EXCEPTION 'Exact 30d boundary/NULL semantics failed';
    END IF;
    RAISE NOTICE 'E retention fixtures, batch bounds and rollback checks passed';
END;
$boundary$;
ROLLBACK;
