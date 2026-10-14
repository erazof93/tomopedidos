-- Read-only F2 inventory; file transport avoids nested -c quoting on Windows.
\set ON_ERROR_STOP on
BEGIN READ ONLY;
\ir /f/control/001_preflight.sql
SELECT version(), system_identifier::text FROM pg_control_system();
SELECT rolname, rolcanlogin, rolinherit, rolsuper, rolcreatedb, rolcreaterole,
       rolreplication, rolbypassrls FROM pg_roles ORDER BY rolname;
SELECT datname, pg_get_userbyid(datdba) AS owner FROM pg_database ORDER BY datname;
SELECT nspname, pg_get_userbyid(nspowner) AS owner, nspacl
FROM pg_namespace ORDER BY nspname;
SELECT n.nspname, c.relname, c.relkind FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname NOT IN ('pg_catalog','information_schema','pg_toast') ORDER BY 1,2;
\if :{?f_require_empty}
DO $empty$
BEGIN
 IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname !~ '^pg_' AND rolname <> 'tomopedidos_bootstrap')
 OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname NOT IN ('pg_catalog','information_schema','pg_toast','public'))
 OR EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
            WHERE n.nspname NOT IN ('pg_catalog','information_schema','pg_toast'))
 OR EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public')
 THEN RAISE EXCEPTION 'F2 baseline requires pristine roles/schemas/relations/functions'; END IF;
END;
$empty$;
\endif
SELECT 'F2 inventory passed' AS result;
ROLLBACK;
