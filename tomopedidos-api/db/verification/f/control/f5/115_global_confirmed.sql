-- Administrative synthetic revocation only; no operational caller grant.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
BEGIN;
DO $global$ DECLARE r record; BEGIN
 SELECT * INTO STRICT r FROM identity.revoke_global(sha256(convert_to('F5C postrevoke synthetic','UTF8')),'admin');
 IF r.result<>'global_revoked' OR r.current_identity_epoch<>1 THEN RAISE EXCEPTION 'Expected global epoch1'; END IF;
END; $global$;
COMMIT;
\echo 'F5C_GLOBAL_COMMIT_CONFIRMED'
