-- Read-only E assertions; include inside authorized administrative transaction.
DO $assert$
DECLARE v_stage text := current_setting('tomopedidos.e_stage');
    v_proc record; v_role record; v_col record; v_priv text; v_expected boolean;
BEGIN
    IF v_stage NOT IN ('dormant','enabled') THEN RAISE EXCEPTION 'Unknown E state'; END IF;
    IF (SELECT count(*) FROM pg_trigger AS t JOIN pg_class AS c ON c.oid = t.tgrelid
        JOIN pg_namespace AS n ON n.oid = c.relnamespace
        WHERE n.nspname = 'identity' AND NOT t.tgisinternal AND t.tgenabled = 'O'
          AND ((c.relname = 'identities' AND t.tgname = 'trg_identities_update_guard'
                AND t.tgfoid = to_regprocedure('identity.guard_identities_update()'))
            OR (c.relname = 'audience_revocations' AND t.tgname = 'trg_audience_revocations_update_guard'
                AND t.tgfoid = to_regprocedure('identity.guard_audience_revocations_update()'))
            OR (c.relname = 'sessions' AND t.tgname = 'trg_sessions_update_guard'
                AND t.tgfoid = to_regprocedure('identity.guard_sessions_update()')))) <> 3 THEN
        RAISE EXCEPTION 'E requires B guards enabled on the correct tables';
    END IF;
    IF (SELECT count(*) FROM pg_roles WHERE rolname IN
        ('tomopedidos_cleanup_executor','tomopedidos_session_maintenance')) <> 2 THEN
        RAISE EXCEPTION 'E roles missing';
    END IF;
    FOR v_role IN SELECT * FROM pg_roles WHERE rolname IN
        ('tomopedidos_cleanup_executor','tomopedidos_session_maintenance') LOOP
        IF v_role.rolsuper OR v_role.rolcreatedb OR v_role.rolcreaterole OR v_role.rolreplication
            OR v_role.rolbypassrls OR v_role.rolinherit
            OR v_role.rolcanlogin <> (v_role.rolname = 'tomopedidos_session_maintenance')
            OR EXISTS (SELECT 1 FROM pg_auth_members WHERE member = v_role.oid OR roleid = v_role.oid)
            OR EXISTS (SELECT 1 FROM pg_db_role_setting WHERE setrole = v_role.oid)
            OR EXISTS (SELECT 1 FROM pg_shdepend WHERE refclassid = 'pg_authid'::regclass
                       AND refobjid = v_role.oid AND dbid <> 0
                       AND dbid <> (SELECT oid FROM pg_database WHERE datname = current_database())) THEN
            RAISE EXCEPTION 'E role attributes/memberships/settings/dependencies drift';
        END IF;
        IF has_database_privilege(v_role.oid,current_database(),'CREATE,TEMP')
            OR has_database_privilege(v_role.oid,current_database(),'CONNECT WITH GRANT OPTION')
            OR has_database_privilege(v_role.oid,current_database(),'CONNECT') IS DISTINCT FROM
                (v_stage = 'enabled' AND v_role.rolname = 'tomopedidos_session_maintenance') THEN
            RAISE EXCEPTION 'E database rights differ';
        END IF;
        IF EXISTS (SELECT 1 FROM pg_namespace AS n
            WHERE has_schema_privilege(v_role.oid,n.oid,'CREATE')
               OR has_schema_privilege(v_role.oid,n.oid,'USAGE WITH GRANT OPTION')
               OR (n.nspname NOT LIKE 'pg_%' AND n.nspname <> 'information_schema'
                   AND has_schema_privilege(v_role.oid,n.oid,'USAGE') IS DISTINCT FROM
                       (n.nspname = 'identity' AND
                        (v_role.rolname = 'tomopedidos_cleanup_executor' OR v_stage = 'enabled'))))
            OR EXISTS (SELECT 1 FROM pg_default_acl AS d CROSS JOIN LATERAL aclexplode(d.defaclacl) AS acl
                       WHERE d.defaclrole = v_role.oid OR acl.grantee = v_role.oid)
            OR EXISTS (SELECT 1 FROM pg_parameter_acl AS p CROSS JOIN LATERAL aclexplode(p.paracl) AS acl
                       WHERE acl.grantee IN (0,v_role.oid)) THEN
            RAISE EXCEPTION 'E schema/default/parameter rights differ';
        END IF;
        IF EXISTS (SELECT 1 FROM pg_shdepend WHERE refclassid = 'pg_authid'::regclass
            AND refobjid = v_role.oid AND deptype = 'o'
            AND NOT (classid = 'pg_proc'::regclass AND objid = to_regprocedure('identity.cleanup_sessions(integer)')
                     AND dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
                     AND v_role.rolname = 'tomopedidos_cleanup_executor')) THEN
            RAISE EXCEPTION 'Unexpected E ownership';
        END IF;
    END LOOP;
    IF (SELECT count(*) FROM pg_proc AS p JOIN pg_namespace AS n ON n.oid = p.pronamespace
        WHERE n.nspname = 'identity' AND p.proname = 'cleanup_sessions') <> 1 THEN
        RAISE EXCEPTION 'E function inventory drift';
    END IF;
    SELECT * INTO STRICT v_proc FROM pg_proc WHERE oid = to_regprocedure('identity.cleanup_sessions(integer)');
    IF v_proc.proowner <> (SELECT oid FROM pg_roles WHERE rolname = 'tomopedidos_cleanup_executor')
        OR NOT v_proc.prosecdef OR NOT v_proc.proretset OR v_proc.prorettype <> 'record'::regtype
        OR v_proc.prokind <> 'f' OR v_proc.provolatile <> 'v' OR v_proc.proparallel <> 'u'
        OR v_proc.proisstrict OR v_proc.proleakproof OR v_proc.provariadic <> 0
        OR v_proc.prolang <> (SELECT oid FROM pg_language WHERE lanname = 'plpgsql')
        OR v_proc.proconfig IS DISTINCT FROM ARRAY['search_path=pg_catalog, pg_temp']::text[]
        OR v_proc.proargnames IS DISTINCT FROM ARRAY['p_batch_size','examined','deleted','skipped','checked_at']::text[]
        OR v_proc.proallargtypes IS DISTINCT FROM ARRAY['integer'::regtype::oid,'integer'::regtype::oid,
            'integer'::regtype::oid,'integer'::regtype::oid,'timestamptz'::regtype::oid]::oid[]
        OR v_proc.proargmodes IS DISTINCT FROM ARRAY['i','t','t','t','t']::"char"[]
        OR v_proc.pronargdefaults <> 1 OR pg_get_expr(v_proc.proargdefaults,0) <> '100'
        OR upper(encode(sha256(convert_to(replace(v_proc.prosrc,E'\r\n',E'\n'),'UTF8')),'hex')) <> 'D24C85C89BF7227E77192DCB21A207172BFB9BDE4699B39DCF3AC35288F8B9B7' THEN
        RAISE EXCEPTION 'E function contract/source/security drift';
    END IF;
    IF EXISTS (SELECT 1 FROM aclexplode(COALESCE(v_proc.proacl,acldefault('f',v_proc.proowner))) AS acl
        WHERE acl.privilege_type <> 'EXECUTE' OR acl.is_grantable
          OR NOT (acl.grantee = v_proc.proowner OR (v_stage = 'enabled'
              AND acl.grantee = (SELECT oid FROM pg_roles WHERE rolname = 'tomopedidos_session_maintenance'))))
        OR NOT has_function_privilege(v_proc.proowner,v_proc.oid,'EXECUTE')
        OR has_function_privilege('tomopedidos_session_maintenance',v_proc.oid,'EXECUTE') IS DISTINCT FROM (v_stage = 'enabled')
        OR has_function_privilege('tomopedidos_auth_runtime',v_proc.oid,'EXECUTE')
        OR has_function_privilege('tomopedidos_runtime',v_proc.oid,'EXECUTE')
        OR has_function_privilege('tomopedidos_migrator',v_proc.oid,'EXECUTE') THEN
        RAISE EXCEPTION 'E ACL/effective EXECUTE drift';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_index AS ix JOIN pg_class AS c ON c.oid = ix.indexrelid
        JOIN pg_am AS am ON am.oid = c.relam
        WHERE c.oid = to_regclass('identity.idx_sessions_cleanup_terminal')
          AND ix.indrelid = 'identity.sessions'::regclass AND ix.indisvalid AND ix.indisready
          AND NOT ix.indisunique AND ix.indpred IS NULL AND ix.indnkeyatts = 2 AND ix.indnatts = 2
          AND ix.indkey[0] = 0 AND ix.indkey[1] = (SELECT attnum FROM pg_attribute
              WHERE attrelid = 'identity.sessions'::regclass AND attname = 'session_id' AND NOT attisdropped)
          AND am.amname = 'btree' AND c.relowner = (SELECT oid FROM pg_roles WHERE rolname = 'tp_owner')
          AND lower(regexp_replace(pg_get_expr(ix.indexprs,ix.indrelid),'\s','','g')) =
              'least(idle_expires_at,absolute_expires_at,revoked_at,expired_at)') THEN
        RAISE EXCEPTION 'E cleanup index missing or differs';
    END IF;
    FOR v_col IN SELECT c.oid AS relid,n.nspname,c.relname,a.attname,a.attnum
        FROM pg_class AS c JOIN pg_namespace AS n ON n.oid = c.relnamespace
        JOIN pg_attribute AS a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
        WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname <> 'information_schema' AND c.relkind IN ('r','p','v','m','f') LOOP
        FOR v_role IN SELECT * FROM pg_roles WHERE rolname IN
            ('tomopedidos_cleanup_executor','tomopedidos_session_maintenance') LOOP
            IF has_table_privilege(v_role.oid,v_col.relid,'SELECT,INSERT,UPDATE,TRUNCATE,REFERENCES,TRIGGER,MAINTAIN')
                OR has_table_privilege(v_role.oid,v_col.relid,'DELETE') IS DISTINCT FROM
                    (v_role.rolname = 'tomopedidos_cleanup_executor' AND v_col.nspname = 'identity' AND v_col.relname = 'sessions')
                OR has_table_privilege(v_role.oid,v_col.relid,'DELETE WITH GRANT OPTION') THEN
                RAISE EXCEPTION 'E table privileges differ';
            END IF;
            FOREACH v_priv IN ARRAY ARRAY['SELECT','INSERT','UPDATE','REFERENCES'] LOOP
                v_expected := v_role.rolname = 'tomopedidos_cleanup_executor' AND v_col.nspname = 'identity' AND
                    ((v_priv = 'SELECT' AND
                        ((v_col.relname = 'identities' AND v_col.attname = 'id')
                         OR (v_col.relname = 'audience_revocations' AND v_col.attname IN ('identity_id','audience'))
                         OR (v_col.relname = 'sessions' AND v_col.attname IN
                             ('session_id','identity_id','audience','created_at','last_activity_at',
                              'idle_expires_at','absolute_expires_at','revoked_at','expired_at'))))
                     OR (v_priv = 'UPDATE' AND
                        ((v_col.relname = 'identities' AND v_col.attname = 'id')
                         OR (v_col.relname = 'audience_revocations' AND v_col.attname = 'audience')
                         OR (v_col.relname = 'sessions' AND v_col.attname = 'session_id'))));
                IF has_column_privilege(v_role.oid,v_col.relid,v_col.attnum,v_priv) IS DISTINCT FROM v_expected
                    OR has_column_privilege(v_role.oid,v_col.relid,v_col.attnum,v_priv || ' WITH GRANT OPTION') THEN
                    RAISE EXCEPTION 'E column privileges differ';
                END IF;
            END LOOP;
        END LOOP;
    END LOOP;
    IF EXISTS (SELECT 1 FROM pg_proc AS p JOIN pg_namespace AS n ON n.oid = p.pronamespace
        CROSS JOIN pg_roles AS r WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname <> 'information_schema'
          AND r.rolname IN ('tomopedidos_cleanup_executor','tomopedidos_session_maintenance')
          AND p.oid <> v_proc.oid AND has_function_privilege(r.oid,p.oid,'EXECUTE'))
        OR EXISTS (SELECT 1 FROM pg_class AS c JOIN pg_namespace AS n ON n.oid = c.relnamespace
            CROSS JOIN pg_roles AS r WHERE c.relkind = 'S' AND n.nspname NOT LIKE 'pg_%'
              AND r.rolname IN ('tomopedidos_cleanup_executor','tomopedidos_session_maintenance')
              AND has_sequence_privilege(r.oid,c.oid,'USAGE,SELECT,UPDATE')) THEN
        RAISE EXCEPTION 'E indirect function/sequence privileges differ';
    END IF;
    RAISE NOTICE 'E metadata/privilege assertions passed: %',v_stage;
END;
$assert$;
