-- Catalog graph is evidence only; PL/pgSQL string-body references may not be catalog dependencies.
\set ON_ERROR_STOP on
BEGIN READ ONLY;
\ir /f/control/001_preflight.sql
SELECT pg_describe_object(d.classid,d.objid,d.objsubid) AS dependent,
 pg_describe_object(d.refclassid,d.refobjid,d.refobjsubid) AS referenced,d.deptype
FROM pg_depend d
WHERE(d.refclassid='pg_class'::regclass AND d.refobjid IN(SELECT c.oid FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='identity'))
 OR(d.refclassid='pg_proc'::regclass AND d.refobjid IN(SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='identity'))
ORDER BY referenced,dependent;
SELECT n.nspname,c.relname,c.relkind,pg_get_userbyid(c.relowner) AS owner FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN('identity','migration_meta') ORDER BY 1,2;
ROLLBACK;
