-- F-only missing administrative C Down, no original functional file modified.
-- After E Down and D disable/ungrant, while A/B tables still exist.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
BEGIN;
SET LOCAL search_path TO pg_catalog;
\ir /f/staged/administration/b2a-role-preflight.sql
SET LOCAL tomopedidos.d_stage TO 'c';
\ir /f/staged/administration/b2a-assert-state.sql
DROP FUNCTION identity.lookup_credential(text,text);
DROP FUNCTION identity.issue_session(uuid,bigint,bigint,bigint,text,uuid,bytea,text,bytea);
DROP FUNCTION identity.validate_session(bytea,text);
DROP FUNCTION identity.record_activity(bytea,text);
DROP FUNCTION identity.revoke_session(bytea,text);
DROP FUNCTION identity.mark_expired(bytea,text);
DROP FUNCTION identity.revoke_audience(bytea,text);
DROP FUNCTION identity.revoke_global(bytea,text);
DROP FUNCTION identity.rehash_conditional(uuid,bigint,text,text);
DO $gone$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_proc AS p JOIN pg_namespace AS n ON n.oid=p.pronamespace
        WHERE n.nspname='identity' AND p.proname IN
            ('lookup_credential','issue_session','validate_session','record_activity','revoke_session',
             'mark_expired','revoke_audience','revoke_global','rehash_conditional')) THEN
        RAISE EXCEPTION 'F C Down left functions';
    END IF;
END; $gone$;
COMMIT;
