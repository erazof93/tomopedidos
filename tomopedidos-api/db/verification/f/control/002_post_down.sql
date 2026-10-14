-- F bootstrap read-only assertion after administrative Down and Goose down-to 0.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
BEGIN READ ONLY;
DO $down$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_class AS c JOIN pg_namespace AS n ON n.oid=c.relnamespace
        WHERE n.nspname='identity' AND c.relkind IN ('r','p','i','S','v','m'))
        OR EXISTS (SELECT 1 FROM pg_proc AS p JOIN pg_namespace AS n ON n.oid=p.pronamespace
                   WHERE n.nspname='identity')
        OR (SELECT count(*) FROM pg_namespace AS n JOIN pg_roles AS r ON r.oid=n.nspowner
            WHERE n.nspname IN ('identity','tenancy','authorization','audit','migration_meta') AND r.rolname='tp_owner') <> 5
        OR NOT EXISTS (SELECT 1 FROM migration_meta.goose_db_version WHERE version_id=0 AND is_applied)
        OR EXISTS (SELECT 1 FROM
            (SELECT DISTINCT ON (version_id) version_id,is_applied FROM migration_meta.goose_db_version
             ORDER BY version_id,id DESC) AS latest WHERE version_id > 0 AND is_applied) THEN
        RAISE EXCEPTION 'F Down did not restore expected B1 schemas/Goose baseline';
    END IF;
    RAISE NOTICE 'F post-Down metadata checks passed; roles and Goose metadata intentionally retained';
END;
$down$;
ROLLBACK;
