-- F target-only staged copy; original hash is in stage-manifest.json.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
-- PREPARED ONLY. Transactional infrastructure probes; no application tables.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL search_path TO pg_catalog;
DO $guard$
BEGIN
  IF current_database()<>'tp_b2a_f_20261014_r01' OR session_user<>'tomopedidos_bootstrap'
     OR current_user<>session_user
     OR NOT (SELECT rolsuper FROM pg_roles WHERE rolname=current_user) THEN
    RAISE EXCEPTION 'Wrong B1 probe context';
  END IF;
  IF NOT has_schema_privilege('tomopedidos_runtime','tenancy','USAGE') THEN
    RAISE EXCEPTION 'Runtime lacks expected schema access; negative probes would be misleading';
  END IF;
  IF to_regclass('tenancy.__tp_b1_privilege_probe') IS NOT NULL
     OR to_regclass('tenancy.__tp_b1_privilege_seq') IS NOT NULL
     OR to_regclass('tenancy.__tp_b1_forbidden') IS NOT NULL
     OR to_regprocedure('tenancy.__tp_b1_privilege_func()') IS NOT NULL THEN
    RAISE EXCEPTION 'Probe name collision; no existing object will be modified';
  END IF;
END
$guard$;
-- Permission to SET ROLE is checked against session_user.
SET SESSION AUTHORIZATION tomopedidos_migrator;
SET LOCAL ROLE tp_owner;
CREATE TABLE tenancy.__tp_b1_privilege_probe (value integer);
INSERT INTO tenancy.__tp_b1_privilege_probe VALUES (1);
CREATE SEQUENCE tenancy.__tp_b1_privilege_seq;
CREATE FUNCTION tenancy.__tp_b1_privilege_func() RETURNS integer LANGUAGE sql AS 'SELECT 1';
DO $ownership$
BEGIN
  IF session_user<>'tomopedidos_migrator' OR current_user<>'tp_owner' THEN
    RAISE EXCEPTION 'Unexpected migrator/owner probe identity';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
             WHERE n.nspname='tenancy' AND c.relname IN ('__tp_b1_privilege_probe','__tp_b1_privilege_seq')
               AND c.relowner<>(SELECT oid FROM pg_roles WHERE rolname='tp_owner'))
     OR EXISTS (SELECT 1 FROM pg_proc WHERE oid='tenancy.__tp_b1_privilege_func()'::regprocedure
                AND proowner<>(SELECT oid FROM pg_roles WHERE rolname='tp_owner')) THEN
    RAISE EXCEPTION 'Migrator created objects with incorrect ownership';
  END IF;
END
$ownership$;
SELECT value FROM tenancy.__tp_b1_privilege_probe;
RESET SESSION AUTHORIZATION;
SET SESSION AUTHORIZATION tomopedidos_runtime;
DO $negative$
DECLARE
  statement text;
  denied_count integer := 0;
BEGIN
  IF session_user<>'tomopedidos_runtime' OR current_user<>session_user THEN
    RAISE EXCEPTION 'Unexpected runtime probe identity';
  END IF;
  FOREACH statement IN ARRAY ARRAY[
    'SELECT value FROM tenancy.__tp_b1_privilege_probe',
    'INSERT INTO tenancy.__tp_b1_privilege_probe VALUES (2)',
    'UPDATE tenancy.__tp_b1_privilege_probe SET value=2',
    'DELETE FROM tenancy.__tp_b1_privilege_probe',
    'CREATE TABLE tenancy.__tp_b1_forbidden (value integer)',
    'CREATE TEMP TABLE __tp_b1_forbidden (value integer)',
    'CREATE SCHEMA __tp_b1_forbidden',
    'ALTER TABLE tenancy.__tp_b1_privilege_probe ADD COLUMN forbidden integer',
    'TRUNCATE tenancy.__tp_b1_privilege_probe',
    'SELECT nextval(''tenancy.__tp_b1_privilege_seq'')',
    'SELECT tenancy.__tp_b1_privilege_func()',
    'SET ROLE tp_owner',
    'SET ROLE tomopedidos_migrator',
    'ALTER ROLE tp_owner LOGIN'
  ] LOOP
    BEGIN
      EXECUTE statement;
      RAISE EXCEPTION 'Runtime unexpectedly permitted probe: %', statement
        USING ERRCODE = 'P0001';
    EXCEPTION WHEN insufficient_privilege THEN
      denied_count := denied_count + 1;
    END;
  END LOOP;
  IF denied_count<>14 THEN
    RAISE EXCEPTION 'Expected 14 permission denials, received %', denied_count;
  END IF;
END
$negative$;
ROLLBACK;
-- Check cleanup and role restoration after rollback, using only catalog reads.
DO $cleanup$
BEGIN
  IF session_user<>'tomopedidos_bootstrap' OR current_user<>session_user THEN
    RAISE EXCEPTION 'Session identity was not restored';
  END IF;
  IF to_regclass('tenancy.__tp_b1_privilege_probe') IS NOT NULL
     OR to_regclass('tenancy.__tp_b1_privilege_seq') IS NOT NULL
     OR to_regclass('tenancy.__tp_b1_forbidden') IS NOT NULL
     OR to_regprocedure('tenancy.__tp_b1_privilege_func()') IS NOT NULL THEN
    RAISE EXCEPTION 'Rollback cleanup failed';
  END IF;
END
$cleanup$;
SELECT 'B1 probes passed and rollback cleanup confirmed' AS result;
