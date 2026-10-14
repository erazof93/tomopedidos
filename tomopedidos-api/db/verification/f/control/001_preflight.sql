-- Include before every staged psql entry; no mutation. Values supplied by operator.
\set ON_ERROR_STOP on
\if :{?f_system_id}
\else
\set f_system_id MISSING
\endif
\if :{?f_actor}
\else
\set f_actor MISSING
\endif
SELECT current_database() = 'tp_b2a_f_20261014_r01'
   AND current_setting('cluster_name') = 'tp-b2a-f-20261014-r01'
   AND current_setting('server_version_num')::integer = 180006
   AND session_user = :'f_actor' AND current_user = session_user
   AND :'f_actor' IN ('tomopedidos_bootstrap','tomopedidos_migrator','tomopedidos_auth_runtime',
                      'tomopedidos_runtime','tomopedidos_session_maintenance')
   AND inet_server_addr() = '127.0.0.1'::inet AND inet_server_port() = 5432
   AND NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'tomopedidos_local')
   AND NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname <> 'plpgsql')
   AND :'f_system_id' ~ '^[0-9]{19,20}$' AS f_target_ok \gset
\if :f_target_ok
\else
DO $wrong$ BEGIN RAISE EXCEPTION 'F exact target/actor/version/extension preflight failed'; END; $wrong$;
\endif
-- Control identity is checked as bootstrap in same container immediately before
-- each role login. Runtime logins do not receive extra pg_control_system privilege.
SELECT session_user = 'tomopedidos_bootstrap' AS f_is_bootstrap \gset
\if :f_is_bootstrap
SELECT system_identifier::text = :'f_system_id' AS f_control_ok FROM pg_control_system() \gset
\if :f_control_ok
\else
DO $wrong$ BEGIN RAISE EXCEPTION 'F system identifier mismatch'; END; $wrong$;
\endif
\endif
