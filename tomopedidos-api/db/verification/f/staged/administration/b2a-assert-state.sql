-- D read-only assertions; included by installer/verifiers inside a transaction.
-- Stage must be explicitly selected by the including script: c, executors, enabled.
DO $state$
DECLARE
    v_stage text := pg_catalog.current_setting('tomopedidos.d_stage');
    v_expected record;
    v_proc record;
    v_role record;
    v_col record;
    v_priv text;
    v_allowed boolean;
BEGIN
    IF v_stage NOT IN ('c','executors','enabled') THEN RAISE EXCEPTION 'Unknown D stage'; END IF;
    IF (SELECT count(*) FROM pg_catalog.pg_roles WHERE rolname IN
        ('tomopedidos_auth_executor','tomopedidos_auth_revoke_executor','tomopedidos_auth_runtime')) <> 3 THEN
        RAISE EXCEPTION 'D roles missing';
    END IF;
    FOR v_role IN SELECT * FROM pg_catalog.pg_roles WHERE rolname IN
        ('tomopedidos_auth_executor','tomopedidos_auth_revoke_executor','tomopedidos_auth_runtime')
    LOOP
        IF v_role.rolsuper OR v_role.rolcreatedb OR v_role.rolcreaterole OR v_role.rolreplication
            OR v_role.rolbypassrls OR v_role.rolinherit
            OR v_role.rolcanlogin <> (v_role.rolname = 'tomopedidos_auth_runtime')
            OR EXISTS (SELECT 1 FROM pg_catalog.pg_auth_members WHERE member = v_role.oid OR roleid = v_role.oid)
            OR EXISTS (SELECT 1 FROM pg_catalog.pg_db_role_setting WHERE setrole = v_role.oid)
            OR EXISTS (SELECT 1 FROM pg_catalog.pg_shdepend WHERE refclassid = 'pg_authid'::regclass
                       AND refobjid = v_role.oid AND dbid <> 0
                       AND dbid <> (SELECT oid FROM pg_catalog.pg_database WHERE datname = current_database())) THEN
            RAISE EXCEPTION 'D role attributes/membership/settings/other database dependencies differ';
        END IF;
        IF pg_catalog.has_database_privilege(v_role.oid,'tp_b2a_f_20261014_r01','CREATE')
            OR pg_catalog.has_database_privilege(v_role.oid,'tp_b2a_f_20261014_r01','TEMP')
            OR pg_catalog.has_database_privilege(v_role.oid,'tp_b2a_f_20261014_r01','CONNECT WITH GRANT OPTION')
            OR pg_catalog.has_database_privilege(v_role.oid,'tp_b2a_f_20261014_r01','CONNECT') IS DISTINCT FROM
                (v_stage = 'enabled' AND v_role.rolname = 'tomopedidos_auth_runtime') THEN
            RAISE EXCEPTION 'Unexpected effective database permissions';
        END IF;
        IF EXISTS (SELECT 1 FROM pg_catalog.pg_namespace AS n
            WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname <> 'information_schema'
              AND (pg_catalog.has_schema_privilege(v_role.oid,n.oid,'CREATE')
                   OR pg_catalog.has_schema_privilege(v_role.oid,n.oid,'USAGE') IS DISTINCT FROM
                       (n.nspname = 'identity' AND v_stage <> 'c'
                        AND (v_role.rolname <> 'tomopedidos_auth_runtime' OR v_stage = 'enabled')))) THEN
            RAISE EXCEPTION 'Unexpected effective schema permissions';
        END IF;
        IF EXISTS (SELECT 1 FROM pg_catalog.pg_namespace AS n
            WHERE pg_catalog.has_schema_privilege(v_role.oid,n.oid,'CREATE')
               OR pg_catalog.has_schema_privilege(v_role.oid,n.oid,'USAGE WITH GRANT OPTION'))
            OR EXISTS (SELECT 1 FROM pg_catalog.pg_default_acl AS d
                CROSS JOIN LATERAL pg_catalog.aclexplode(d.defaclacl) AS acl
                WHERE d.defaclrole = v_role.oid OR acl.grantee = v_role.oid) THEN
            RAISE EXCEPTION 'Unexpected schema grant option/CREATE/default ACL';
        END IF;
        IF EXISTS (SELECT 1 FROM pg_catalog.pg_shdepend AS d
            WHERE d.refclassid = 'pg_authid'::regclass AND d.refobjid = v_role.oid AND d.deptype = 'o'
              AND NOT (d.dbid = (SELECT oid FROM pg_catalog.pg_database WHERE datname = current_database())
                       AND d.classid = 'pg_proc'::regclass)) THEN
            RAISE EXCEPTION 'D role owns an object other than permitted functions';
        END IF;
        IF EXISTS (SELECT 1 FROM pg_catalog.pg_parameter_acl AS p
            CROSS JOIN LATERAL pg_catalog.aclexplode(p.paracl) AS acl
            WHERE acl.grantee IN (0,v_role.oid)) THEN
            RAISE EXCEPTION 'Unexpected parameter permissions';
        END IF;
    END LOOP;
    IF (SELECT count(*) FROM pg_catalog.pg_class AS c JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
        WHERE n.nspname = 'identity' AND c.relkind = 'r' AND c.relname IN
            ('identities','identity_credentials','audience_revocations','sessions')
          AND c.relowner = (SELECT oid FROM pg_catalog.pg_roles WHERE rolname = 'tp_owner')
          AND NOT c.relrowsecurity AND NOT c.relforcerowsecurity) <> 4 THEN
        RAISE EXCEPTION 'A table ownership/kind/RLS differs';
    END IF;
    IF (SELECT count(*) FROM pg_catalog.pg_proc AS p JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
        WHERE n.nspname = 'identity' AND p.proname IN
            ('lookup_credential','issue_session','validate_session','record_activity','revoke_session',
             'mark_expired','revoke_audience','revoke_global','rehash_conditional')) <> 9
        OR EXISTS (SELECT 1 FROM pg_catalog.pg_proc AS p JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
                   WHERE n.nspname = 'identity' AND p.proname IN ('revoke_audience_privileged','revoke_global_privileged')) THEN
        RAISE EXCEPTION 'C inventory differs or unexpected privileged alias exists';
    END IF;
    FOR v_expected IN SELECT * FROM (VALUES
        ('identity.lookup_credential(text, text)','tomopedidos_auth_executor','F53AB501509EF67AF3325B6AB2FE18B2586995295D3148D394162CEC0728720B',ARRAY['p_email_canonical','p_audience','identity_id','password_hash','credential_revision','identity_epoch','audience_epoch']::text[],ARRAY['text'::regtype::oid,'text'::regtype::oid,'uuid'::regtype::oid,'text'::regtype::oid,'bigint'::regtype::oid,'bigint'::regtype::oid,'bigint'::regtype::oid]::oid[]),
        ('identity.issue_session(uuid, bigint, bigint, bigint, text, uuid, bytea, text, bytea)','tomopedidos_auth_executor','E0E4D81FED4D047BD447F95647DF4517B30B109885E2D9DEA5CF75E69ED4D141',ARRAY['p_identity_id','p_expected_revision','p_expected_identity_epoch','p_expected_audience_epoch','p_audience','p_session_id','p_digest','p_csrf_key_id','p_csrf_salt','result','session_id','created_at','idle_expires_at','absolute_expires_at']::text[],ARRAY['uuid'::regtype::oid,'bigint'::regtype::oid,'bigint'::regtype::oid,'bigint'::regtype::oid,'text'::regtype::oid,'uuid'::regtype::oid,'bytea'::regtype::oid,'text'::regtype::oid,'bytea'::regtype::oid,'text'::regtype::oid,'uuid'::regtype::oid,'timestamptz'::regtype::oid,'timestamptz'::regtype::oid,'timestamptz'::regtype::oid]::oid[]),
        ('identity.validate_session(bytea, text)','tomopedidos_auth_executor','736057B501A47088E7FE8A77AEAD2A19D6AB880AC93877D53B071AE10E3AAC46',ARRAY['p_digest','p_audience','result','session_id','identity_id','audience','authentication_level','csrf_key_id','csrf_generation','csrf_salt','checked_at','idle_expires_at','absolute_expires_at','current_identity_epoch','current_audience_epoch']::text[],ARRAY['bytea'::regtype::oid,'text'::regtype::oid,'text'::regtype::oid,'uuid'::regtype::oid,'uuid'::regtype::oid,'text'::regtype::oid,'text'::regtype::oid,'text'::regtype::oid,'bigint'::regtype::oid,'bytea'::regtype::oid,'timestamptz'::regtype::oid,'timestamptz'::regtype::oid,'timestamptz'::regtype::oid,'bigint'::regtype::oid,'bigint'::regtype::oid]::oid[]),
        ('identity.record_activity(bytea, text)','tomopedidos_auth_executor','C712CB021E5FDF5FF64C96F68EEE4BFA3D9AA54BE2B415D44AC88ED1ED4F7822',ARRAY['p_digest','p_audience','result','session_id','identity_id','audience','authentication_level','csrf_key_id','csrf_generation','csrf_salt','checked_at','idle_expires_at','absolute_expires_at','current_identity_epoch','current_audience_epoch']::text[],ARRAY['bytea'::regtype::oid,'text'::regtype::oid,'text'::regtype::oid,'uuid'::regtype::oid,'uuid'::regtype::oid,'text'::regtype::oid,'text'::regtype::oid,'text'::regtype::oid,'bigint'::regtype::oid,'bytea'::regtype::oid,'timestamptz'::regtype::oid,'timestamptz'::regtype::oid,'timestamptz'::regtype::oid,'bigint'::regtype::oid,'bigint'::regtype::oid]::oid[]),
        ('identity.revoke_session(bytea, text)','tomopedidos_auth_executor','DEC02E132C4EE23000B3047C8EF24A5621730FA300DCB80D1E1C209EE139309F',ARRAY['p_digest','p_audience','result','session_id','identity_id','audience','authentication_level','csrf_key_id','csrf_generation','csrf_salt','checked_at','idle_expires_at','absolute_expires_at','current_identity_epoch','current_audience_epoch']::text[],ARRAY['bytea'::regtype::oid,'text'::regtype::oid,'text'::regtype::oid,'uuid'::regtype::oid,'uuid'::regtype::oid,'text'::regtype::oid,'text'::regtype::oid,'text'::regtype::oid,'bigint'::regtype::oid,'bytea'::regtype::oid,'timestamptz'::regtype::oid,'timestamptz'::regtype::oid,'timestamptz'::regtype::oid,'bigint'::regtype::oid,'bigint'::regtype::oid]::oid[]),
        ('identity.mark_expired(bytea, text)','tomopedidos_auth_executor','9A9800B8D8BE26030B12BD732DE309EB8C8221806D4467272DE86957B3F08220',ARRAY['p_digest','p_audience','result','session_id','identity_id','audience','authentication_level','csrf_key_id','csrf_generation','csrf_salt','checked_at','idle_expires_at','absolute_expires_at','current_identity_epoch','current_audience_epoch']::text[],ARRAY['bytea'::regtype::oid,'text'::regtype::oid,'text'::regtype::oid,'uuid'::regtype::oid,'uuid'::regtype::oid,'text'::regtype::oid,'text'::regtype::oid,'text'::regtype::oid,'bigint'::regtype::oid,'bytea'::regtype::oid,'timestamptz'::regtype::oid,'timestamptz'::regtype::oid,'timestamptz'::regtype::oid,'bigint'::regtype::oid,'bigint'::regtype::oid]::oid[]),
        ('identity.revoke_audience(bytea, text)','tomopedidos_auth_revoke_executor','218EEAA3AE40504F96AEF8A4D63EAAFF32C8485494BEE8ADDF2B1F504CE010C7',ARRAY['p_digest','p_audience','result','session_id','identity_id','audience','authentication_level','csrf_key_id','csrf_generation','csrf_salt','checked_at','idle_expires_at','absolute_expires_at','current_identity_epoch','current_audience_epoch']::text[],ARRAY['bytea'::regtype::oid,'text'::regtype::oid,'text'::regtype::oid,'uuid'::regtype::oid,'uuid'::regtype::oid,'text'::regtype::oid,'text'::regtype::oid,'text'::regtype::oid,'bigint'::regtype::oid,'bytea'::regtype::oid,'timestamptz'::regtype::oid,'timestamptz'::regtype::oid,'timestamptz'::regtype::oid,'bigint'::regtype::oid,'bigint'::regtype::oid]::oid[]),
        ('identity.revoke_global(bytea, text)','tomopedidos_auth_revoke_executor','8FB466B18A96BD91ECC3FB0012D2CA91126E73C2067E13B51D001BD6E394E49F',ARRAY['p_digest','p_audience','result','session_id','identity_id','audience','authentication_level','csrf_key_id','csrf_generation','csrf_salt','checked_at','idle_expires_at','absolute_expires_at','current_identity_epoch','current_audience_epoch']::text[],ARRAY['bytea'::regtype::oid,'text'::regtype::oid,'text'::regtype::oid,'uuid'::regtype::oid,'uuid'::regtype::oid,'text'::regtype::oid,'text'::regtype::oid,'text'::regtype::oid,'bigint'::regtype::oid,'bytea'::regtype::oid,'timestamptz'::regtype::oid,'timestamptz'::regtype::oid,'timestamptz'::regtype::oid,'bigint'::regtype::oid,'bigint'::regtype::oid]::oid[]),
        ('identity.rehash_conditional(uuid, bigint, text, text)','tomopedidos_auth_executor','7AA63818771E50B4641091A2AA61D2CABF9865A1F486862A8057A28AF39AAE91',ARRAY['p_identity_id','p_expected_revision','p_expected_hash','p_new_hash','result','credential_revision']::text[],ARRAY['uuid'::regtype::oid,'bigint'::regtype::oid,'text'::regtype::oid,'text'::regtype::oid,'text'::regtype::oid,'bigint'::regtype::oid]::oid[])
    ) AS expected(signature,owner_name,hash,arg_names,arg_types)
    LOOP
        SELECT p.* INTO STRICT v_proc FROM pg_catalog.pg_proc AS p WHERE p.oid = pg_catalog.to_regprocedure(v_expected.signature);
        IF v_proc.proowner <> (SELECT oid FROM pg_catalog.pg_roles WHERE rolname = v_expected.owner_name)
            OR NOT v_proc.prosecdef OR v_proc.provolatile <> 'v' OR v_proc.proparallel <> 'u'
            OR v_proc.proleakproof OR v_proc.prokind <> 'f' OR v_proc.prorettype <> 'record'::regtype OR NOT v_proc.proretset
            OR v_proc.proisstrict OR v_proc.pronargdefaults <> 0 OR v_proc.provariadic <> 0
            OR v_proc.prolang <> (SELECT oid FROM pg_catalog.pg_language WHERE lanname = 'plpgsql')
            OR v_proc.proconfig IS DISTINCT FROM ARRAY['search_path=pg_catalog, pg_temp']::text[]
            OR v_proc.proargnames IS DISTINCT FROM v_expected.arg_names
            OR v_proc.proallargtypes IS DISTINCT FROM v_expected.arg_types
            OR cardinality(v_proc.proargmodes) IS DISTINCT FROM cardinality(v_expected.arg_names)
            OR EXISTS (SELECT 1 FROM unnest(v_proc.proargmodes) WITH ORDINALITY AS m(mode,arg_index)
                       WHERE m.mode <> CASE WHEN m.arg_index <= v_proc.pronargs THEN 'i'::"char" ELSE 't'::"char" END)
            OR pg_catalog.upper(pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(
                pg_catalog.replace(v_proc.prosrc,E'\r\n',E'\n'),'UTF8')),'hex')) <> v_expected.hash THEN
            RAISE EXCEPTION 'C signature/source/owner/properties drift';
        END IF;
        IF EXISTS (SELECT 1 FROM pg_catalog.aclexplode(COALESCE(v_proc.proacl,
            pg_catalog.acldefault('f',v_proc.proowner))) AS acl
            WHERE acl.privilege_type <> 'EXECUTE' OR acl.is_grantable
              OR NOT (acl.grantee = v_proc.proowner OR (v_stage = 'enabled'
                  AND v_expected.owner_name = 'tomopedidos_auth_executor'
                  AND acl.grantee = (SELECT oid FROM pg_catalog.pg_roles WHERE rolname = 'tomopedidos_auth_runtime')))) THEN
            RAISE EXCEPTION 'C unexpected ACL recipient/grant option';
        END IF;
        IF NOT pg_catalog.has_function_privilege(v_proc.proowner,v_proc.oid,'EXECUTE')
            OR pg_catalog.has_function_privilege('tomopedidos_auth_runtime',v_proc.oid,'EXECUTE') IS DISTINCT FROM
                (v_stage = 'enabled' AND v_expected.owner_name = 'tomopedidos_auth_executor')
            OR pg_catalog.has_function_privilege('tomopedidos_runtime',v_proc.oid,'EXECUTE')
            OR pg_catalog.has_function_privilege('tomopedidos_migrator',v_proc.oid,'EXECUTE') THEN
            RAISE EXCEPTION 'C effective EXECUTE differs';
        END IF;
    END LOOP;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_proc AS p
        JOIN pg_catalog.pg_roles AS r ON r.oid = p.proowner
        JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
        WHERE r.rolname IN ('tomopedidos_auth_executor','tomopedidos_auth_revoke_executor','tomopedidos_auth_runtime')
          AND NOT (n.nspname = 'identity' AND
              ((r.rolname = 'tomopedidos_auth_executor' AND p.proname IN
                  ('lookup_credential','issue_session','validate_session','record_activity','revoke_session','mark_expired','rehash_conditional'))
               OR (r.rolname = 'tomopedidos_auth_revoke_executor' AND p.proname IN ('revoke_audience','revoke_global'))))) THEN
        RAISE EXCEPTION 'Unexpected function ownership';
    END IF;
    -- Check every user relation/column, including unexpected relations: no broad rights.
    FOR v_col IN SELECT c.oid AS table_oid,n.nspname,c.relname,a.attname,a.attnum,c.relowner,c.relacl,a.attacl
        FROM pg_catalog.pg_class AS c JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
        JOIN pg_catalog.pg_attribute AS a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
        WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname <> 'information_schema' AND c.relkind IN ('r','p','v','m','f')
    LOOP
        IF v_col.nspname = 'identity' AND (EXISTS (SELECT 1 FROM pg_catalog.aclexplode(COALESCE(v_col.relacl,
            pg_catalog.acldefault('r',v_col.relowner))) AS acl WHERE acl.grantee = 0)
            OR EXISTS (SELECT 1 FROM pg_catalog.aclexplode(v_col.attacl) AS acl WHERE acl.grantee = 0)) THEN
            RAISE EXCEPTION 'PUBLIC has identity relation/column rights';
        END IF;
        FOR v_role IN SELECT * FROM pg_catalog.pg_roles WHERE rolname IN
            ('tomopedidos_auth_executor','tomopedidos_auth_revoke_executor','tomopedidos_auth_runtime','tomopedidos_runtime')
        LOOP
            IF v_role.rolname = 'tomopedidos_runtime' AND v_col.nspname <> 'identity' THEN CONTINUE; END IF;
            IF pg_catalog.has_table_privilege(v_role.oid,v_col.table_oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER,MAINTAIN') THEN
                RAISE EXCEPTION 'Unexpected table-level privilege';
            END IF;
            FOREACH v_priv IN ARRAY ARRAY['SELECT','INSERT','UPDATE','REFERENCES'] LOOP
                SELECT EXISTS (SELECT 1 FROM (VALUES
                    ('tomopedidos_auth_executor','identities','SELECT',string_to_array('id,email_canonical,status,email_verified_at,auth_epoch,credential_revision,created_at',',')),
        ('tomopedidos_auth_executor','identities','UPDATE',string_to_array('credential_revision',',')),
        ('tomopedidos_auth_executor','identity_credentials','SELECT',string_to_array('identity_id,password_hash',',')),
        ('tomopedidos_auth_executor','identity_credentials','UPDATE',string_to_array('password_hash,changed_at',',')),
        ('tomopedidos_auth_executor','audience_revocations','SELECT',string_to_array('identity_id,audience,auth_epoch',',')),
        ('tomopedidos_auth_executor','audience_revocations','UPDATE',string_to_array('audience',',')),
        ('tomopedidos_auth_executor','sessions','SELECT',string_to_array('session_id,identity_id,audience,token_hash,identity_epoch,audience_epoch,authentication_level,csrf_key_id,csrf_generation,csrf_salt,created_at,last_activity_at,idle_expires_at,absolute_expires_at,revoked_at,expired_at',',')),
        ('tomopedidos_auth_executor','sessions','INSERT',string_to_array('session_id,identity_id,audience,token_hash,identity_epoch,audience_epoch,authentication_level,csrf_key_id,csrf_generation,csrf_salt,created_at,last_activity_at,idle_expires_at,absolute_expires_at',',')),
        ('tomopedidos_auth_executor','sessions','UPDATE',string_to_array('last_activity_at,idle_expires_at,revoked_at,expired_at',',')),
        ('tomopedidos_auth_revoke_executor','identities','SELECT',string_to_array('id,status,email_verified_at,auth_epoch,credential_revision,created_at',',')),
        ('tomopedidos_auth_revoke_executor','identities','UPDATE',string_to_array('auth_epoch',',')),
        ('tomopedidos_auth_revoke_executor','audience_revocations','SELECT',string_to_array('identity_id,audience,auth_epoch',',')),
        ('tomopedidos_auth_revoke_executor','audience_revocations','UPDATE',string_to_array('auth_epoch',',')),
        ('tomopedidos_auth_revoke_executor','sessions','SELECT',string_to_array('session_id,identity_id,audience,token_hash,identity_epoch,audience_epoch,authentication_level,csrf_key_id,csrf_generation,csrf_salt,created_at,last_activity_at,idle_expires_at,absolute_expires_at,revoked_at,expired_at',',')),
        ('tomopedidos_auth_revoke_executor','sessions','UPDATE',string_to_array('expired_at',','))
                ) AS rights(role_name,table_name,privilege,columns)
                WHERE v_stage <> 'c' AND v_col.nspname = 'identity'
                  AND rights.role_name = v_role.rolname AND rights.table_name = v_col.relname
                  AND rights.privilege = v_priv AND v_col.attname = ANY(rights.columns)) INTO v_allowed;
                IF pg_catalog.has_column_privilege(v_role.oid,v_col.table_oid,v_col.attnum,v_priv) IS DISTINCT FROM v_allowed
                    OR pg_catalog.has_column_privilege(v_role.oid,v_col.table_oid,v_col.attnum,v_priv || ' WITH GRANT OPTION') THEN
                    RAISE EXCEPTION 'Effective column permission differs';
                END IF;
            END LOOP;
        END LOOP;
    END LOOP;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_class AS c JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
        CROSS JOIN pg_catalog.pg_roles AS r WHERE c.relkind = 'S' AND n.nspname NOT LIKE 'pg_%'
          AND r.rolname IN ('tomopedidos_auth_executor','tomopedidos_auth_revoke_executor','tomopedidos_auth_runtime')
          AND pg_catalog.has_sequence_privilege(r.oid,c.oid,'USAGE,SELECT,UPDATE')) THEN
        RAISE EXCEPTION 'Unexpected sequence privileges';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_proc AS p JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
        CROSS JOIN pg_catalog.pg_roles AS r
        WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname <> 'information_schema'
          AND r.rolname IN ('tomopedidos_auth_executor','tomopedidos_auth_revoke_executor','tomopedidos_auth_runtime')
          AND pg_catalog.has_function_privilege(r.oid,p.oid,'EXECUTE')
          AND NOT (p.proowner = r.oid OR (v_stage = 'enabled' AND r.rolname = 'tomopedidos_auth_runtime'
              AND n.nspname = 'identity' AND p.proname IN
                ('lookup_credential','issue_session','validate_session','record_activity','revoke_session','mark_expired','rehash_conditional')))) THEN
        RAISE EXCEPTION 'Unexpected user function execution route';
    END IF;
    RAISE NOTICE 'D metadata and effective privilege assertions passed: %',v_stage;
END;
$state$;
