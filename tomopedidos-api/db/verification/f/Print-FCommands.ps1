# Prints proposed commands ONLY. Does not invoke Docker, Goose, SQL or processes.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$t=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'target.json') -Raw | ConvertFrom-Json
$sid=if ($null-eq $t.system_identifier) {'SYSTEM_ID_PENDING'} else {[string]$t.system_identifier}
$compose=Join-Path $PSScriptRoot 'compose.f.yaml'
$private='D:\tomopedidos\.local\b2a-f\r01.private.env'
$composeArgs='docker --context default compose --env-file "'+$private+'" -f "'+$compose+'" -p '+$t.compose_project
$toolsArgs=$composeArgs+' -f "'+(Join-Path $PSScriptRoot 'compose.tools.yaml')+'"'
function Print-Psql([string]$label,[string]$actor,[string]$file,[string]$vars='') {
    if ($actor-cne $t.bootstrap) { Print-Psql 'Fresh bootstrap system-ID preflight before independent role login' $t.bootstrap '/f/control/001_preflight.sql' }
    Write-Output ('# '+$label+' -- future separate exec_command invocation, approval required')
    Write-Output ('docker --context default exec -it '+$t.container+' psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d '+$t.database+' -U '+$actor+' -W -v f_actor='+$actor+' -v f_system_id='+$sid+' '+$vars+' -f '+$file)
}
function Print-Goose([string]$action) {
    Write-Output '# Fresh Docker snapshot + bootstrap system-ID preflight required BEFORE this separate invocation'
    Print-Psql 'Fresh bootstrap system-ID preflight before Goose' $t.bootstrap '/f/control/001_preflight.sql'
    Write-Output ($toolsArgs+' --profile tools run --rm --no-deps goose -dir /migrations -table migration_meta.goose_db_version '+$action)
}
Write-Output '# PROPOSAL ONLY. Credentials/system ID/execution approvals are not present.'
Write-Output '# Each Docker command must be a separate call; stop on first failure. No shell chaining.'
Write-Output '# Before provision: inspect exactly the F resource names; existing resources require review, never automatic adoption.'
Write-Output ('docker --context default version')
$containerFormat='{"Id":{{json .Id}},"Name":{{json .Name}},"State":{{json .State}},"Config":{"Image":{{json .Config.Image}},"Labels":{{json .Config.Labels}}},"HostConfig":{"PortBindings":{{json .HostConfig.PortBindings}},"NetworkMode":{{json .HostConfig.NetworkMode}},"Privileged":{{json .HostConfig.Privileged}},"PublishAllPorts":{{json .HostConfig.PublishAllPorts}}},"Mounts":{{json .Mounts}},"NetworkSettings":{"Networks":{{json .NetworkSettings.Networks}}}}'
Write-Output ('docker --context default inspect --format '+"'"+$containerFormat+"' "+$t.container)
Write-Output ('docker --context default network inspect '+$t.network)
Write-Output ('docker --context default volume inspect --format '+"'"+'{"Name":{{json .Name}},"Driver":{{json .Driver}},"Labels":{{json .Labels}},"OptionsCount":{{len .Options}}}'+"' "+$t.volume)
Write-Output '# Before creation, not-found for those exact F names is expected evidence; requires explicit creation approval.'
Write-Output ($composeArgs+' up -d --no-deps postgres')
Print-Psql 'Enrollment READ ONLY; record/review control identity before pinning' $t.bootstrap '/f/control/000_identify.sql'
Print-Psql 'Pinned preflight (SYSTEM_ID_PENDING must fail)' $t.bootstrap '/f/control/001_preflight.sql'
Print-Psql 'Baseline B1 equivalent in F ONLY, first run only' $t.bootstrap '/f/staged/bootstrap/001_roles.sql'
Print-Psql 'Baseline schemas/defaults in F ONLY, first run only' $t.bootstrap '/f/staged/bootstrap/002_schema_privileges.sql'
Print-Psql 'Baseline B1 metadata BEFORE A-D' $t.bootstrap '/f/staged/verification/010_b1_metadata.sql'
Print-Psql 'Baseline B1 transactional privilege probes' $t.bootstrap '/f/staged/verification/020_b1_effective_privileges.sql'
Write-Output '# MANUAL GATE: new private migrator/tenant passwords via prompted psql \password, then real TCP evidence. Never reuse root .env.'
Write-Output ($toolsArgs+' --profile tools build goose')
Print-Goose '-version'
Print-Goose 'validate'
Print-Goose 'up-to 1'
Print-Goose 'version'
Print-Goose 'up-to 2'
Print-Goose 'version'
Print-Goose 'up-to 3'
Print-Goose 'version'
Print-Goose 'up-to 4'
Print-Goose 'version'
Print-Psql 'A/B/E-index metadata after Up4' $t.bootstrap '/f/control/004_migration_metadata.sql'
Print-Psql 'F constraints/guards fixtures, final ROLLBACK' $t.bootstrap '/f/control/fixtures/030_integrity.sql'
Print-Psql 'D role provisioning, separated from B1' $t.bootstrap '/f/staged/administration/b2a-role-provision-v1.sql'
Print-Psql 'C initial administrative install' $t.bootstrap '/f/staged/administration/b2a-auth-functions-v1.sql'
Print-Psql 'D executors only' $t.bootstrap '/f/staged/administration/b2a-auth-grants-v1.sql'
Print-Psql 'D isolation before caller enable' $t.bootstrap '/f/staged/verification/040_b2a_role_isolation.sql' '-v d_stage=executors'
Write-Output '# MANUAL GATE: authorize synthetic-fixture caller enable, not API/production enable.'
Print-Psql 'D enable in F' $t.bootstrap '/f/staged/administration/b2a-auth-enable-v1.sql'
Print-Psql 'D isolation post-enable, fresh connection' $t.bootstrap '/f/staged/verification/040_b2a_role_isolation.sql' '-v d_stage=enabled'
Print-Psql 'F nine primitive paths, ROLLBACK' $t.bootstrap '/f/control/fixtures/060_auth_primitives.sql'
Print-Psql 'F state/digest/audience/overflow/CAS fail-closed fixtures' $t.bootstrap '/f/control/fixtures/061_fail_closed.sql'
Write-Output '# MANUAL GATE: auth private credential/authentication provision, no passwords in commands.'
Print-Psql 'Auth real login' 'tomopedidos_auth_runtime' '/f/control/fixtures/070_real_login.sql'
Print-Psql 'Tenant real login' 'tomopedidos_runtime' '/f/control/fixtures/070_real_login.sql'
Print-Psql 'Migrator real login, no startup SET ROLE for this context check' 'tomopedidos_migrator' '/f/control/fixtures/070_real_login.sql'
Print-Psql 'Auth real negatives (26)' 'tomopedidos_auth_runtime' '/f/staged/verification/041_b2a_caller_negatives.sql'
Print-Psql 'Tenant real negatives (33)' 'tomopedidos_runtime' '/f/staged/verification/041_b2a_caller_negatives.sql'
Print-Psql 'E proposed actors, separately authorized' $t.bootstrap '/f/staged/administration/retention/b2a-cleanup-role-provision-v1.sql'
Print-Psql 'E dormant initial install' $t.bootstrap '/f/staged/administration/retention/b2a-session-cleanup-v1.sql'
Print-Psql 'E dormant metadata' $t.bootstrap '/f/staged/verification/052_b2a_cleanup_metadata.sql' '-v e_stage=dormant'
Print-Psql 'E enable for isolated fixtures only' $t.bootstrap '/f/staged/administration/retention/b2a-cleanup-enable-v1.sql'
Print-Psql 'E post-enable metadata' $t.bootstrap '/f/staged/verification/052_b2a_cleanup_metadata.sql' '-v e_stage=enabled'
Write-Output '# MANUAL GATE: maintenance private credential/authentication provision.'
Print-Psql 'Maintenance real TCP login' 'tomopedidos_session_maintenance' '/f/control/fixtures/070_real_login.sql'
Print-Psql 'Maintenance real negatives (12)' 'tomopedidos_session_maintenance' '/f/control/fixtures/071_maintenance_negatives.sql'
Print-Psql 'E retention fixtures ROLLBACK' $t.bootstrap '/f/staged/verification/050_b2a_retention_concurrency.sql'
Print-Psql 'E failure fixtures ROLLBACK' $t.bootstrap '/f/staged/verification/051_b2a_cleanup_failures.sql'
Write-Output '# MANUAL GATE: reviewed PostgreSQL18 isolationtester, native spec enrolled ID, capture/review expected results; no automatic tool installation.'
Write-Output '# MANUAL GATE: fault/ambiguous-commit harness, IDs/credentials/backend reviewed before injection.'
Print-Psql 'MANUAL: seed committed fault fixtures, empty dedicated F only' $t.bootstrap '/f/control/fixtures/090_fault_seed.sql'
Print-Psql 'MANUAL A: holder blocks until operator releases; separate interactive connection' $t.bootstrap '/f/control/fixtures/091_fault_holder.sql'
Print-Psql 'MANUAL B: expected 55P03 while A is holding' 'tomopedidos_session_maintenance' '/f/control/fixtures/092_lock_timeout.sql'
Print-Psql 'MANUAL B: cancel fixture, expose only F PID, requires A holder' 'tomopedidos_session_maintenance' '/f/control/fixtures/093_cancelled_batch.sql'
Print-Psql 'MANUAL C: CANCEL only approved captured F PID; default0 refuses' $t.bootstrap '/f/control/fixtures/094_cancel_backend.sql' '-v f_cancel_pid=0'
Print-Psql 'MANUAL B: harness-controlled ACK loss, NOT automatic injection' 'tomopedidos_session_maintenance' '/f/control/fixtures/095_ambiguous_batch.sql'
Print-Psql 'MANUAL fresh connection: reconcile observed rows, no retry' $t.bootstrap '/f/control/fixtures/096_reconcile_fault.sql'
Print-Psql 'MANUAL authorized exact fixture teardown, after evidence' $t.bootstrap '/f/control/fixtures/097_fault_teardown.sql'
Write-Output '# FULL DOWN: stop/drain all F callers; no fixtures or active transactions; approval required.'
Print-Psql 'E disable' $t.bootstrap '/f/staged/administration/retention/b2a-cleanup-disable-v1.sql'
Print-Psql 'E administrative Down, no data recovery' $t.bootstrap '/f/staged/administration/retention/b2a-session-cleanup-down-v1.sql'
Print-Psql 'D disable' $t.bootstrap '/f/staged/administration/b2a-auth-disable-v1.sql'
Print-Psql 'D ungrant executors' $t.bootstrap '/f/staged/administration/b2a-auth-ungrant-v1.sql'
Print-Psql 'F C administrative Down, verified exact nine functions' $t.bootstrap '/f/control/003_c_down.sql'
Print-Goose 'down-to 3'
Print-Goose 'version'
Print-Goose 'down-to 2'
Print-Goose 'version'
Print-Goose 'down-to 1'
Print-Goose 'version'
Print-Goose 'down-to 0'
Print-Goose 'version'
Print-Psql 'Post Down0' $t.bootstrap '/f/control/002_post_down.sql'
Print-Psql 'B1 metadata after D/E/C removed, never B1 reapply' $t.bootstrap '/f/staged/verification/010_b1_metadata.sql'
Write-Output '# RE-UP: Goose up-to 4, Up metadata/integrity; skip existing role provisioning and B1. Reinstall C/D/E only after drift review.'
Write-Output '# Cleanup of container/volume is another destructive permission gate; no down --volumes command emitted.'
