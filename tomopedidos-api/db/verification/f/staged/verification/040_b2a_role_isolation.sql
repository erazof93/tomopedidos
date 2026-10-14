-- F target-only staged copy; original hash is in stage-manifest.json.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
-- PREPARED ONLY: administrative metadata/effective-rights verification, no fixtures.
-- psql -v d_stage=executors OR enabled, with separately authorized connection.
-- Cannot certify actual login permissions or compilation of function bodies.
\set ON_ERROR_STOP on
\if :{?d_stage}
\else
\echo 'Required d_stage: executors or enabled'
\set d_stage missing
\endif
BEGIN READ ONLY;
SET LOCAL search_path TO pg_catalog;
SET LOCAL tomopedidos.d_stage TO :'d_stage';
\ir ../administration/b2a-role-preflight.sql
DO $stage$
BEGIN
    IF current_setting('tomopedidos.d_stage') NOT IN ('executors','enabled') THEN
        RAISE EXCEPTION 'Isolation verifier requires executors or enabled stage';
    END IF;
END;
$stage$;
\ir ../administration/b2a-assert-state.sql
-- PUBLIC is not a login role: explicit PUBLIC ACLs are checked by the assertions.
-- B helpers are invoker trigger functions; neither caller may invoke them directly.
DO $helpers$
DECLARE v_name text; v_oid oid;
BEGIN
    FOREACH v_name IN ARRAY ARRAY['identity.guard_identities_update()',
        'identity.guard_audience_revocations_update()','identity.guard_sessions_update()'] LOOP
        v_oid := to_regprocedure(v_name);
        IF v_oid IS NULL OR has_function_privilege('tomopedidos_auth_runtime',v_oid,'EXECUTE')
            OR has_function_privilege('tomopedidos_runtime',v_oid,'EXECUTE')
            OR EXISTS (SELECT 1 FROM pg_proc AS p CROSS JOIN LATERAL
                aclexplode(COALESCE(p.proacl,acldefault('f',p.proowner))) AS acl
                WHERE p.oid = v_oid AND acl.grantee = 0) THEN
            RAISE EXCEPTION 'B helper isolation differs';
        END IF;
    END LOOP;
    RAISE NOTICE 'D isolation metadata checks passed; real caller negatives remain separate';
END;
$helpers$;
ROLLBACK;
