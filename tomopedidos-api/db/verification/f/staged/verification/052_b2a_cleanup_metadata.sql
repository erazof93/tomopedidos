-- F target-only staged copy; original hash is in stage-manifest.json.
\set ON_ERROR_STOP on
\ir /f/control/001_preflight.sql
-- PREPARED ONLY. Read-only metadata after install/enable on authorized target.
\set ON_ERROR_STOP on
\if :{?e_stage}
\else
\set e_stage missing
\endif
BEGIN READ ONLY;
SET LOCAL search_path TO pg_catalog;
\ir ../administration/b2a-role-preflight.sql
SET LOCAL tomopedidos.d_stage TO 'enabled';
\ir ../administration/b2a-assert-state.sql
SET LOCAL tomopedidos.e_stage TO :'e_stage';
\ir ../administration/retention/b2a-cleanup-assert.sql
ROLLBACK;
