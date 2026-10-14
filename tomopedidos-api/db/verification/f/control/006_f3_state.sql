\set ON_ERROR_STOP on
BEGIN READ ONLY;
\ir /f/control/001_preflight.sql
SELECT :'f_expected_version'::integer AS expected_version \gset
SELECT max(version_id) = :expected_version AS version_ok FROM migration_meta.goose_db_version WHERE is_applied \gset
\if :version_ok
\else
DO $bad$ BEGIN RAISE EXCEPTION 'F3 Goose version mismatch'; END; $bad$;
\endif
DO $acl$
BEGIN
 IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname IN ('identity','migration_meta') AND c.relowner<>(SELECT oid FROM pg_roles WHERE rolname='tp_owner'))
 OR EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='identity' AND (p.proowner<>(SELECT oid FROM pg_roles WHERE rolname='tp_owner') OR p.prosecdef))
 OR EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 CROSS JOIN LATERAL aclexplode(COALESCE(c.relacl,acldefault(CASE WHEN c.relkind='S' THEN 'S'::"char" ELSE 'r'::"char" END,c.relowner))) a
 WHERE n.nspname IN ('identity','migration_meta') AND c.relkind IN ('r','S') AND a.grantee<>c.relowner)
 OR EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 CROSS JOIN LATERAL aclexplode(COALESCE(p.proacl,acldefault('f',p.proowner))) a
 WHERE n.nspname='identity' AND a.grantee<>p.proowner)
 THEN RAISE EXCEPTION 'F3 object ownership/ACL/security drift'; END IF;
END;
$acl$;
SELECT version_id,is_applied FROM migration_meta.goose_db_version ORDER BY id;
SELECT n.nspname,c.relname,c.relkind,pg_get_userbyid(c.relowner) AS owner
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname IN ('identity','migration_meta') ORDER BY 1,2;
SELECT indexname,indexdef FROM pg_indexes WHERE schemaname='identity' ORDER BY indexname;
SELECT p.proname,pg_get_userbyid(p.proowner) AS owner,p.prosecdef,p.proconfig FROM pg_proc p
JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='identity' ORDER BY p.proname;
SELECT 'F3 version and ownership checks passed' AS result;
ROLLBACK;
