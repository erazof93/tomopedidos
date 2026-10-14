-- F6 future read-only transition assertion; not executed in F6-A.
\set ON_ERROR_STOP on
BEGIN READ ONLY;
\ir /f/control/001_preflight.sql
SET LOCAL tomopedidos.f6_version TO :'f_version';
SET LOCAL tomopedidos.f6_c TO :'f_c';
SET LOCAL tomopedidos.f6_e TO :'f_e';
DO $transition$
DECLARE v integer:=current_setting('tomopedidos.f6_version')::integer;
 c text:=current_setting('tomopedidos.f6_c'); e text:=current_setting('tomopedidos.f6_e');
 actual integer; tabcount integer; idxcount integer; funccount integer; rel record; has_rows boolean;
BEGIN
 IF v NOT BETWEEN 0 AND 4 OR c NOT IN('absent','c','executors','enabled')
 OR e NOT IN('absent','dormant','enabled') OR (v<4 AND(c<>'absent' OR e<>'absent'))
 OR (e<>'absent' AND c<>'enabled') THEN RAISE EXCEPTION 'Invalid F6 expected transition'; END IF;
 SELECT COALESCE(max(version_id),0)::integer INTO actual FROM
 (SELECT DISTINCT ON(version_id) version_id,is_applied FROM migration_meta.goose_db_version ORDER BY version_id,id DESC) latest WHERE is_applied;
 IF NOT EXISTS(SELECT 1 FROM migration_meta.goose_db_version WHERE version_id=0 AND is_applied)
 OR actual<>v OR EXISTS(SELECT 1 FROM
 (SELECT DISTINCT ON(version_id) version_id,is_applied FROM migration_meta.goose_db_version ORDER BY version_id,id DESC) latest
 WHERE version_id BETWEEN 1 AND 4 AND is_applied<>(version_id<=v))
 THEN RAISE EXCEPTION 'F6 latest Goose state differs'; END IF;
 SELECT count(*) INTO tabcount FROM pg_class r JOIN pg_namespace n ON n.oid=r.relnamespace WHERE n.nspname='identity' AND r.relkind IN('r','p');
 SELECT count(*) INTO idxcount FROM pg_class r JOIN pg_namespace n ON n.oid=r.relnamespace WHERE n.nspname='identity' AND r.relkind='i';
 SELECT count(*) INTO funccount FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='identity';
 IF tabcount<>(CASE WHEN v=0 THEN 0 WHEN v=1 THEN 2 ELSE 4 END)
 OR idxcount<>(CASE v WHEN 0 THEN 0 WHEN 1 THEN 3 WHEN 2 THEN 6 WHEN 3 THEN 8 ELSE 9 END)
 OR funccount<>((CASE WHEN v>=3 THEN 3 ELSE 0 END) + (CASE WHEN c='absent' THEN 0 ELSE 9 END) + (CASE WHEN e='absent' THEN 0 ELSE 1 END))
 THEN RAISE EXCEPTION 'F6 object inventory differs'; END IF;
 FOR rel IN SELECT r.relname FROM pg_class r JOIN pg_namespace n ON n.oid=r.relnamespace WHERE n.nspname='identity' AND r.relkind IN('r','p') LOOP
  EXECUTE format('SELECT EXISTS(SELECT 1 FROM %I.%I)','identity',rel.relname) INTO has_rows;
  IF has_rows THEN RAISE EXCEPTION 'F6 cycle refuses nonempty identity tables'; END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM pg_class r JOIN pg_namespace n ON n.oid=r.relnamespace WHERE n.nspname IN('identity','migration_meta') AND r.relowner<>(SELECT oid FROM pg_roles WHERE rolname='tp_owner'))
 OR EXISTS(SELECT 1 FROM pg_class r JOIN pg_namespace n ON n.oid=r.relnamespace WHERE n.nspname='identity' AND r.relkind NOT IN('r','i'))
 OR (SELECT count(*) FROM pg_trigger t JOIN pg_class r ON r.oid=t.tgrelid JOIN pg_namespace n ON n.oid=r.relnamespace WHERE n.nspname='identity' AND NOT t.tgisinternal)<>(CASE WHEN v>=3 THEN 3 ELSE 0 END)
 OR EXISTS(SELECT 1 FROM pg_trigger t JOIN pg_class r ON r.oid=t.tgrelid JOIN pg_namespace n ON n.oid=r.relnamespace WHERE n.nspname='identity' AND NOT t.tgisinternal AND t.tgenabled<>'O')
 THEN RAISE EXCEPTION 'F6 owners/guards differ'; END IF;
 IF (SELECT count(*) FROM pg_namespace n JOIN pg_roles r ON r.oid=n.nspowner WHERE n.nspname IN('identity','tenancy','authorization','audit','migration_meta') AND r.rolname='tp_owner')<>5
 OR (SELECT count(*) FROM pg_roles WHERE rolname IN('tp_owner','tomopedidos_migrator','tomopedidos_runtime','tomopedidos_auth_executor','tomopedidos_auth_revoke_executor','tomopedidos_auth_runtime','tomopedidos_cleanup_executor','tomopedidos_session_maintenance'))<>8
 THEN RAISE EXCEPTION 'F6 retained B1/C/D/E roles/schemas differ'; END IF;
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname IN('tp_owner','tomopedidos_migrator','tomopedidos_runtime','tomopedidos_auth_executor','tomopedidos_auth_revoke_executor','tomopedidos_auth_runtime','tomopedidos_cleanup_executor','tomopedidos_session_maintenance')
 AND(rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls OR rolinherit
 OR rolcanlogin<>(rolname IN('tomopedidos_migrator','tomopedidos_runtime','tomopedidos_auth_runtime','tomopedidos_session_maintenance'))))
 THEN RAISE EXCEPTION 'F6 retained role attributes differ'; END IF;
 IF c='absent' AND(has_database_privilege('tomopedidos_auth_runtime',current_database(),'CONNECT')
 OR has_schema_privilege('tomopedidos_auth_runtime','identity','USAGE')
 OR has_schema_privilege('tomopedidos_auth_executor','identity','USAGE')
 OR has_schema_privilege('tomopedidos_auth_revoke_executor','identity','USAGE'))
 THEN RAISE EXCEPTION 'F6 absent C retained unexpected caller/executor access'; END IF;
 IF e='absent' AND(has_database_privilege('tomopedidos_session_maintenance',current_database(),'CONNECT')
 OR has_schema_privilege('tomopedidos_session_maintenance','identity','USAGE')
 OR has_schema_privilege('tomopedidos_cleanup_executor','identity','USAGE'))
 THEN RAISE EXCEPTION 'F6 absent E retained unexpected caller/executor access'; END IF;
 IF c='absent' AND e='absent' AND(
 EXISTS(SELECT 1 FROM pg_class r JOIN pg_namespace n ON n.oid=r.relnamespace
 CROSS JOIN LATERAL aclexplode(COALESCE(r.relacl,acldefault('r',r.relowner))) a
 WHERE n.nspname='identity' AND r.relkind='r' AND a.grantee<>r.relowner)
 OR EXISTS(SELECT 1 FROM pg_attribute t JOIN pg_class r ON r.oid=t.attrelid JOIN pg_namespace n ON n.oid=r.relnamespace
 CROSS JOIN LATERAL aclexplode(t.attacl) a WHERE n.nspname='identity' AND a.grantee<>r.relowner))
 THEN RAISE EXCEPTION 'F6 removed packages retained table/column grants'; END IF;
 IF EXISTS(SELECT 1 FROM pg_stat_activity WHERE datname=current_database() AND usename IN('tomopedidos_auth_runtime','tomopedidos_session_maintenance') AND pid<>pg_backend_pid())
 OR EXISTS(SELECT 1 FROM pg_prepared_xacts WHERE database=current_database()) THEN RAISE EXCEPTION 'F6 callers not drained'; END IF;
END;
$transition$;
SELECT :'f_c'<>'absent' AS f_has_c, :'f_e'<>'absent' AS f_has_e \gset
\if :f_has_c
SET LOCAL tomopedidos.d_stage TO :'f_c';
\ir /f/staged/administration/b2a-role-preflight.sql
\ir /f/staged/administration/b2a-assert-state.sql
\endif
\if :f_has_e
SET LOCAL tomopedidos.e_stage TO :'f_e';
\ir /f/staged/administration/retention/b2a-cleanup-assert.sql
\endif
SELECT 'F6 transition verified' AS result;
ROLLBACK;
