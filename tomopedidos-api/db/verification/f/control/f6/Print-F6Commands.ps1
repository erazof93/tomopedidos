# Pure preview. Never invokes Docker, psql, Goose or a child process.
$ErrorActionPreference='Stop'
$f=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$prefix='docker --context default compose --env-file "D:\tomopedidos\.local\b2a-f\r01.private.env" --env-file "D:\tomopedidos\.local\b2a-f\r01.tools.private.env" -f "'+(Join-Path $f 'compose.f.yaml')+'" -f "'+(Join-Path $f 'compose.tools.yaml')+'" -p tp-b2a-f-20261014-r01 --profile tools'
function Psql([string]$file,[string]$actor='tomopedidos_bootstrap',[string]$vars='') {
 Write-Output '# FUTURE ONLY: fresh F snapshot + bootstrap system-ID preflight first; separate invocation'
 Write-Output ('docker --context default exec -it tp-b2a-f-20261014-r01-pg psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U '+$actor+' -W -v f_actor='+$actor+' -v f_system_id=7696590721605967915 '+$vars+' -f '+$file)
}
Write-Output '# PROPOSAL: approval required; do not execute all printed lines as a batch'
Psql '/f/control/f6/dependency_inventory.sql'
Psql '/f/control/f6/check_transition.sql' 'tomopedidos_bootstrap' '-v f_version=4 -v f_c=enabled -v f_e=enabled'
foreach($file in @('/f/staged/administration/retention/b2a-cleanup-disable-v1.sql','/f/staged/administration/retention/b2a-session-cleanup-down-v1.sql','/f/staged/administration/b2a-auth-disable-v1.sql','/f/staged/administration/b2a-auth-ungrant-v1.sql','/f/control/003_c_down.sql')) {Psql $file;Write-Output '# Stop: post-transition assertion from README must PASS before next mutation'}
foreach($v in @(3,2,1,0)) {
 Write-Output ($prefix+' run --name tp-b2a-f-20261014-r01-f6-goose-down'+$v+' --no-deps goose -dir /migrations -table migration_meta.goose_db_version down-to '+$v)
 Psql '/f/control/f6/check_transition.sql' 'tomopedidos_bootstrap' ('-v f_version='+$v+' -v f_c=absent -v f_e=absent')
}
Psql '/f/control/002_post_down.sql'
Psql '/f/staged/verification/010_b1_metadata.sql'
foreach($v in @(1,2,3,4)) {
 Write-Output ($prefix+' run --name tp-b2a-f-20261014-r01-f6-goose-up'+$v+' --no-deps goose -dir /migrations -table migration_meta.goose_db_version up-to '+$v)
 Psql '/f/control/f6/check_transition.sql' 'tomopedidos_bootstrap' ('-v f_version='+$v+' -v f_c=absent -v f_e=absent')
}
foreach($file in @('/f/staged/administration/b2a-auth-functions-v1.sql','/f/staged/administration/b2a-auth-grants-v1.sql','/f/staged/administration/b2a-auth-enable-v1.sql','/f/staged/administration/retention/b2a-session-cleanup-v1.sql','/f/staged/administration/retention/b2a-cleanup-enable-v1.sql')) {Psql $file;Write-Output '# Stop: staged assertions/real-login tests from README before next enable'}
Write-Output '# Separate F6-C approval: 090 seed COMMIT, holder acquired barrier, ONE maintenance scenario, reconcile, release holder, exact097 teardown'
Psql '/f/control/fixtures/090_fault_seed.sql'
Psql '/f/control/f6/holder.sql'
foreach($file in @('lock_timeout.sql','statement_timeout.sql','cancel_waiter.sql')) {Psql ('/f/control/f6/'+$file) 'tomopedidos_session_maintenance'}
Psql '/f/control/f6/observe_cancel.sql'
Psql '/f/control/f6/cancel_exact.sql' 'tomopedidos_bootstrap' '-v f_waiter_pid=0 -v f_waiter_start=MISSING -v f_holder_pid=0 -v f_holder_start=MISSING -v f_observed_at=MISSING'
Psql '/f/control/f6/reconcile_timeout.sql'
Psql '/f/control/fixtures/097_fault_teardown.sql'
Psql '/f/control/f5/117_final_fault_state.sql'
