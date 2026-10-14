\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
BEGIN;
DO $negative$
DECLARE s text; denied integer:=0;
BEGIN
 IF session_user<>'tomopedidos_runtime' OR current_user<>session_user THEN RAISE EXCEPTION 'Wrong real runtime actor'; END IF;
 FOREACH s IN ARRAY ARRAY[
 'SELECT * FROM identity.identities',
 'CREATE TABLE identity.__f3_forbidden (x integer)',
 'CREATE TABLE public.__f3_forbidden (x integer)',
 'CREATE TEMP TABLE __f3_forbidden (x integer)',
 'CREATE SCHEMA __f3_forbidden',
 'SET ROLE tp_owner',
 'SET ROLE tomopedidos_migrator',
 'CREATE ROLE __f3_forbidden NOLOGIN',
 'ALTER ROLE tp_owner LOGIN',
 'SELECT * FROM migration_meta.goose_db_version'
 ] LOOP
  BEGIN
   EXECUTE s;
   RAISE EXCEPTION 'F3 runtime operation unexpectedly accepted';
  EXCEPTION WHEN insufficient_privilege THEN denied:=denied+1;
  END;
 END LOOP;
 IF denied<>10 THEN RAISE EXCEPTION 'F3 expected ten runtime denials'; END IF;
 RAISE NOTICE 'F3 real runtime: ten administrative/DDL/data denials passed';
END;
$negative$;
ROLLBACK;
