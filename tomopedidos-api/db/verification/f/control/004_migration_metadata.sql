-- F read-only after Goose Up 4, before C/D/E grants.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
BEGIN READ ONLY;
DO $up$
BEGIN
    IF (SELECT count(*) FROM pg_class AS c JOIN pg_namespace AS n ON n.oid=c.relnamespace
        WHERE n.nspname='identity' AND c.relkind='r'
          AND c.relname IN ('identities','identity_credentials','audience_revocations','sessions')
          AND c.relowner=(SELECT oid FROM pg_roles WHERE rolname='tp_owner'))<>4
        OR (SELECT count(*) FROM pg_trigger AS t JOIN pg_class AS c ON c.oid=t.tgrelid
            JOIN pg_namespace AS n ON n.oid=c.relnamespace WHERE n.nspname='identity' AND NOT t.tgisinternal AND t.tgenabled='O')<>3
        OR (SELECT count(*) FROM pg_index AS ix JOIN pg_class AS c ON c.oid=ix.indexrelid
            WHERE c.oid IN (to_regclass('identity.idx_sessions_identity_audience_created'),
                           to_regclass('identity.idx_sessions_csrf_key_absolute'),
                           to_regclass('identity.idx_sessions_cleanup_terminal')) AND ix.indisvalid AND ix.indisready)<>3
        OR EXISTS (SELECT 1 FROM pg_class AS c JOIN pg_namespace AS n ON n.oid=c.relnamespace
                   WHERE n.nspname='identity' AND c.relkind='r' AND (c.relrowsecurity OR c.relforcerowsecurity))
        OR (SELECT count(*) FROM
            (SELECT DISTINCT ON(version_id) version_id,is_applied FROM migration_meta.goose_db_version
             ORDER BY version_id,id DESC) AS latest WHERE version_id BETWEEN 1 AND 4 AND is_applied)<>4 THEN
        RAISE EXCEPTION 'F Up tables/owners/guards/indexes/Goose states differ';
    END IF;
    RAISE NOTICE 'F Up 4 metadata checks passed';
END;
$up$;
-- Capture metadata for review, no fixture data or credentials/PHC/digests.
SELECT c.relname,a.attname,format_type(a.atttypid,a.atttypmod),a.attnotnull,a.attgenerated,
       pg_get_expr(d.adbin,d.adrelid) AS default_sql
FROM pg_class AS c JOIN pg_namespace AS n ON n.oid=c.relnamespace
JOIN pg_attribute AS a ON a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped
LEFT JOIN pg_attrdef AS d ON d.adrelid=c.oid AND d.adnum=a.attnum
WHERE n.nspname='identity' AND c.relkind='r' ORDER BY c.relname,a.attnum;
SELECT c.relname,k.conname,k.contype,pg_get_constraintdef(k.oid)
FROM pg_constraint AS k JOIN pg_class AS c ON c.oid=k.conrelid
JOIN pg_namespace AS n ON n.oid=c.relnamespace WHERE n.nspname='identity' ORDER BY c.relname,k.conname;
ROLLBACK;
