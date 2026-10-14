# F6-C transcript — stopped before timeout/cancel tests

## Invocation 1 — exit 0

```text
docker --context default inspect tp-b2a-f-20261014-r01-pg --format '{{json .Id}}{{println}}{{json .Name}}{{println}}{{json .Config.Image}}{{println}}{{json .Config.Labels}}{{println}}{{json .State}}{{println}}{{json .HostConfig.NetworkMode}}{{println}}{{json .HostConfig.Privileged}}{{println}}{{json .HostConfig.PublishAllPorts}}{{println}}{{json .HostConfig.PortBindings}}{{println}}{{json .NetworkSettings.Networks}}{{println}}{{json .Mounts}}{{println}}{{json .Image}}' > .local/b2a-f/f6b-container-fields.jsonl

```

## Invocation 2 — exit 0

```text
docker --context default network inspect tp-b2a-f-20261014-r01-net --format '{{json .}}' > .local/b2a-f/f6b-network.json

```

## Invocation 3 — exit 0

```text
docker --context default volume inspect tp-b2a-f-20261014-r01-data --format '{{json .}}' > .local/b2a-f/f6b-volume-raw.json

```

## Invocation 4 — exit 0

```text
docker --context default image inspect postgres:18.6-bookworm@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c --format '{{json .Id}}{{println}}{{json .RepoDigests}}' > .local/b2a-f/f6b-image.jsonl

```

## Invocation 5 — exit 0

```text
& ./tomopedidos-api/db/verification/f/control/f6/Convert-DockerCapture.ps1 -Fields .local/b2a-f/f6b-container-fields.jsonl -Volume .local/b2a-f/f6b-volume-raw.json -ContainerOut .local/b2a-f/f6b-container.json -VolumeOut .local/b2a-f/f6b-volume.json
& ./tomopedidos-api/db/verification/f/Assert-FDockerSnapshot.ps1 -ContainerJson .local/b2a-f/f6b-container.json -NetworkJson .local/b2a-f/f6b-network.json -VolumeJson .local/b2a-f/f6b-volume.json
$c=Get-Content .local/b2a-f/f6b-container.json -Raw|ConvertFrom-Json
$i=@(Get-Content .local/b2a-f/f6b-image.jsonl)
if(($i[0]|ConvertFrom-Json)-cne $c.Image -or -not ($i[1]|ConvertFrom-Json|Where-Object {$_ -ceq 'postgres@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c'})){throw 'Image content/digest mismatch'}
'PASS actual image digest'
PASS twelve JSON values parsed and selectively serialized; no Docker invoked
PASS saved F Docker identity/ports/network/mount snapshot; refresh live evidence before each future operation. No Docker invoked.
PASS actual image digest

```

## Invocation 6 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/control/000_identify.sql'
BEGIN
DO
  system_identifier  |   current_database    |    current_setting    | current_setting | inet_server_addr | inet_server_port 
---------------------+-----------------------+-----------------------+-----------------+------------------+------------------
 7696590721605967915 | tp_b2a_f_20261014_r01 | tp-b2a-f-20261014-r01 | 180006          | 127.0.0.1        |             5432
(1 row)

ROLLBACK

```

## Invocation 7 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=4 -v f_c=enabled -v f_e=enabled -f /f/control/f6/check_transition.sql'
BEGIN
SET
SET
SET
DO
SET
DO
psql:/f/staged/administration/b2a-assert-state.sql:199: NOTICE:  D metadata and effective privilege assertions passed: enabled
DO
SET
psql:/f/staged/administration/retention/b2a-cleanup-assert.sql:146: NOTICE:  E metadata/privilege assertions passed: enabled
DO
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## Invocation 8 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v e_stage=enabled -f /f/staged/verification/052_b2a_cleanup_metadata.sql'
BEGIN
SET
DO
SET
psql:/f/staged/administration/b2a-assert-state.sql:199: NOTICE:  D metadata and effective privilege assertions passed: enabled
DO
SET
psql:/f/staged/administration/retention/b2a-cleanup-assert.sql:146: NOTICE:  E metadata/privilege assertions passed: enabled
DO
ROLLBACK

```

## Invocation 9 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/control/f5/117_final_fault_state.sql'
BEGIN
DO
  system_identifier  |   current_database    | current_setting 
---------------------+-----------------------+-----------------
 7696590721605967915 | tp_b2a_f_20261014_r01 | 180006
(1 row)

                                         result                                          
-----------------------------------------------------------------------------------------
 F5C final state passed: empty tables, Goose4, no test connections/prepared transactions
(1 row)

ROLLBACK

```

## Invocation 10 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/control/fixtures/090_fault_seed.sql'
BEGIN
SET
SET
DO
INSERT 0 1
INSERT 0 2
INSERT 0 2
COMMIT

```

## Invocation 11 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/control/f6/reconcile_timeout.sql'
BEGIN
DO
 pid | backend_start | application_name | state | wait_event_type | pg_blocking_pids 
-----+---------------+------------------+-------+-----------------+------------------
(0 rows)

ROLLBACK

```

## Holder invocation (after seed, before diagnostic reconciliation)

```text
docker --context default exec -i tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/control/f6/holder.sql'
BEGIN
SET
 holder_pid |         backend_start         
------------+-------------------------------
       2527 | 2026-10-14 23:06:49.522673+00
(1 row)

F6_HOLDER_LOCK_ACQUIRED
Release only after failed-operation rollback evidence, then enter: psql:/f/control/f6/holder.sql:9: error: \prompt: could not read value for variable

exit=1
```


# F6-C controlled holder transport recovery — PASS — 2026-10-14

Original prepared SQL unchanged; new named-pipe holder transport offline-tested before live use. Entries below are separate exec_command invocations, including holder session completions. Reused exact previous seed, no090 repeat. Expected SQL errors captured by original scripts; operation failure not interpreted as commit success.

## Recovery 1 — exit 0

```text
docker --context default inspect tp-b2a-f-20261014-r01-pg --format '{{json .Id}}{{println}}{{json .Name}}{{println}}{{json .Config.Image}}{{println}}{{json .Config.Labels}}{{println}}{{json .State}}{{println}}{{json .HostConfig.NetworkMode}}{{println}}{{json .HostConfig.Privileged}}{{println}}{{json .HostConfig.PublishAllPorts}}{{println}}{{json .HostConfig.PortBindings}}{{println}}{{json .NetworkSettings.Networks}}{{println}}{{json .Mounts}}{{println}}{{json .Image}}' > .local/b2a-f/f6b-container-fields.jsonl

```

## Recovery 2 — exit 0

```text
docker --context default network inspect tp-b2a-f-20261014-r01-net --format '{{json .}}' > .local/b2a-f/f6b-network.json

```

## Recovery 3 — exit 0

```text
docker --context default volume inspect tp-b2a-f-20261014-r01-data --format '{{json .}}' > .local/b2a-f/f6b-volume-raw.json

```

## Recovery 4 — exit 0

```text
docker --context default image inspect postgres:18.6-bookworm@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c --format '{{json .Id}}{{println}}{{json .RepoDigests}}' > .local/b2a-f/f6b-image.jsonl

```

## Recovery 5 — exit 0

```text
& ./tomopedidos-api/db/verification/f/control/f6/Convert-DockerCapture.ps1 -Fields .local/b2a-f/f6b-container-fields.jsonl -Volume .local/b2a-f/f6b-volume-raw.json -ContainerOut .local/b2a-f/f6b-container.json -VolumeOut .local/b2a-f/f6b-volume.json
& ./tomopedidos-api/db/verification/f/Assert-FDockerSnapshot.ps1 -ContainerJson .local/b2a-f/f6b-container.json -NetworkJson .local/b2a-f/f6b-network.json -VolumeJson .local/b2a-f/f6b-volume.json
$c=Get-Content .local/b2a-f/f6b-container.json -Raw|ConvertFrom-Json
$i=@(Get-Content .local/b2a-f/f6b-image.jsonl)
if(($i[0]|ConvertFrom-Json)-cne $c.Image -or -not ($i[1]|ConvertFrom-Json|Where-Object {$_ -ceq 'postgres@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c'})){throw 'Image content/digest mismatch'}
'PASS actual image digest'
PASS twelve JSON values parsed and selectively serialized; no Docker invoked
PASS saved F Docker identity/ports/network/mount snapshot; refresh live evidence before each future operation. No Docker invoked.
PASS actual image digest

```

## Recovery 6 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/control/000_identify.sql'
BEGIN
DO
  system_identifier  |   current_database    |    current_setting    | current_setting | inet_server_addr | inet_server_port 
---------------------+-----------------------+-----------------------+-----------------+------------------+------------------
 7696590721605967915 | tp_b2a_f_20261014_r01 | tp-b2a-f-20261014-r01 | 180006          | 127.0.0.1        |             5432
(1 row)

ROLLBACK

```

## Recovery 7 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v e_stage=enabled -f /f/staged/verification/052_b2a_cleanup_metadata.sql'
BEGIN
SET
DO
SET
psql:/f/staged/administration/b2a-assert-state.sql:199: NOTICE:  D metadata and effective privilege assertions passed: enabled
DO
SET
psql:/f/staged/administration/retention/b2a-cleanup-assert.sql:146: NOTICE:  E metadata/privilege assertions passed: enabled
DO
ROLLBACK

```

## Recovery 8 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/control/f6/reconcile_existing.sql'
BEGIN
DO
                                                           result                                                            
-----------------------------------------------------------------------------------------------------------------------------
 F6 exact retained fixtures reusable: identity1 credentials0 audiences2 sessions2; no test connections/prepared transactions
(1 row)

ROLLBACK

```

## Recovery 9 — running session 28022

```text
& ./tomopedidos-api/db/verification/f/control/f6/Start-F6Holder.ps1
BEGIN
SET
 holder_pid |         backend_start         
------------+-------------------------------
       2572 | 2026-10-14 23:10:11.465787+00
(1 row)

F6_HOLDER_LOCK_ACQUIRED
F6_HOLDER_CONTROL_READY

```

## Recovery 10 — exit 0

```text
& ./.local/b2a-f/Invoke-F6Maintenance.ps1 -Case lock_timeout
BEGIN
SET
SET
SET
DO
 waiter_pid |         backend_start         
------------+-------------------------------
       2580 | 2026-10-14 23:10:24.954065+00
(1 row)

ROLLBACK
BEGIN
 recovered_pid 
---------------
          2580
(1 row)

             classification              
-----------------------------------------
 F6_CONNECTION_RECOVERED_OPERATION_ERROR
(1 row)

COMMIT

psql:/f/control/f6/lock_timeout.sql:14: ERROR:  55P03

DockerExit=0

```

## Recovery 11 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/control/f6/reconcile_timeout.sql'
BEGIN
DO
 pid  |         backend_start         |        application_name         |        state        | wait_event_type | pg_blocking_pids 
------+-------------------------------+---------------------------------+---------------------+-----------------+------------------
 2572 | 2026-10-14 23:10:11.465787+00 | tp-b2a-f-20261014-r01:f6-holder | idle in transaction | Client          | {}
(1 row)

ROLLBACK

```

## Recovery 12 — exit 0

```text
& ./tomopedidos-api/db/verification/f/control/f6/Release-F6Holder.ps1
F6_HOLDER_RELEASE_REQUEST_SENT

```

## Recovery 13 — exit 0

```text
holder session28022 completion after explicit release
Release only after failed-operation rollback evidence, then enter: ROLLBACK


F6_HOLDER_RELEASED_ROLLBACK_CONFIRMED

```

## Recovery 14 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/control/f6/reconcile_existing.sql'
BEGIN
DO
                                                           result                                                            
-----------------------------------------------------------------------------------------------------------------------------
 F6 exact retained fixtures reusable: identity1 credentials0 audiences2 sessions2; no test connections/prepared transactions
(1 row)

ROLLBACK

```

## Recovery 15 — running session 85741

```text
& ./tomopedidos-api/db/verification/f/control/f6/Start-F6Holder.ps1
BEGIN
SET
 holder_pid |         backend_start         
------------+-------------------------------
       2602 | 2026-10-14 23:10:44.991314+00
(1 row)

F6_HOLDER_LOCK_ACQUIRED
F6_HOLDER_CONTROL_READY

```

## Recovery 16 — exit 0

```text
& ./.local/b2a-f/Invoke-F6Maintenance.ps1 -Case statement_timeout
BEGIN
SET
SET
SET
DO
 waiter_pid |         backend_start         
------------+-------------------------------
       2610 | 2026-10-14 23:10:59.191829+00
(1 row)

ROLLBACK
BEGIN
 recovered_pid 
---------------
          2610
(1 row)

             classification              
-----------------------------------------
 F6_CONNECTION_RECOVERED_OPERATION_ERROR
(1 row)

COMMIT

psql:/f/control/f6/statement_timeout.sql:14: ERROR:  57014

DockerExit=0

```

## Recovery 17 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/control/f6/reconcile_timeout.sql'
BEGIN
DO
 pid  |         backend_start         |        application_name         |        state        | wait_event_type | pg_blocking_pids 
------+-------------------------------+---------------------------------+---------------------+-----------------+------------------
 2602 | 2026-10-14 23:10:44.991314+00 | tp-b2a-f-20261014-r01:f6-holder | idle in transaction | Client          | {}
(1 row)

ROLLBACK

```

## Recovery 18 — exit 0

```text
& ./tomopedidos-api/db/verification/f/control/f6/Release-F6Holder.ps1
F6_HOLDER_RELEASE_REQUEST_SENT

```

## Recovery 19 — exit 0

```text
holder session85741 completion after explicit release
Release only after failed-operation rollback evidence, then enter: ROLLBACK


F6_HOLDER_RELEASED_ROLLBACK_CONFIRMED

```

## Recovery 20 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/control/f6/reconcile_existing.sql'
BEGIN
DO
                                                           result                                                            
-----------------------------------------------------------------------------------------------------------------------------
 F6 exact retained fixtures reusable: identity1 credentials0 audiences2 sessions2; no test connections/prepared transactions
(1 row)

ROLLBACK

```

## Recovery 21 — running session 6441

```text
& ./tomopedidos-api/db/verification/f/control/f6/Start-F6Holder.ps1
BEGIN
SET
 holder_pid |         backend_start         
------------+-------------------------------
       2632 | 2026-10-14 23:11:23.880105+00
(1 row)

F6_HOLDER_LOCK_ACQUIRED
F6_HOLDER_CONTROL_READY

```

## Recovery 22 — running session 48838

```text
& ./.local/b2a-f/Invoke-F6Maintenance.ps1 -Case cancel_waiter

```

## Recovery 23 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -A -t -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/control/f6/observe_cancel.sql'
BEGIN
2640|2026-10-14 23:11:36.893002+00|2632|2026-10-14 23:11:23.880105+00|2026-10-14 23:11:52.707612+00|{2632}
ROLLBACK

```

## Recovery 24 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_waiter_pid=2640 -v f_waiter_start=2026-10-14T23:11:36.893002+00 -v f_holder_pid=2632 -v f_holder_start=2026-10-14T23:11:23.880105+00 -v f_observed_at=2026-10-14T23:11:52.707612+00 -f /f/control/f6/cancel_exact.sql'
F6_CANCEL_SENT_NOT_YET_OBSERVED

```

## Recovery 25 — exit 0

```text
cancel waiter session48838 completion after exact signal
BEGIN
SET
SET
SET
DO
 waiter_pid |         backend_start         
------------+-------------------------------
       2640 | 2026-10-14 23:11:36.893002+00
(1 row)

ROLLBACK
BEGIN
 recovered_pid 
---------------
          2640
(1 row)

             classification              
-----------------------------------------
 F6_CONNECTION_RECOVERED_OPERATION_ERROR
(1 row)

COMMIT

psql:/f/control/f6/cancel_waiter.sql:14: ERROR:  57014

DockerExit=0

```

## Recovery 26 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/control/f6/reconcile_timeout.sql'
BEGIN
DO
 pid  |         backend_start         |        application_name         |        state        | wait_event_type | pg_blocking_pids 
------+-------------------------------+---------------------------------+---------------------+-----------------+------------------
 2632 | 2026-10-14 23:11:23.880105+00 | tp-b2a-f-20261014-r01:f6-holder | idle in transaction | Client          | {}
(1 row)

ROLLBACK

```

## Recovery 27 — exit 0

```text
& ./tomopedidos-api/db/verification/f/control/f6/Release-F6Holder.ps1
F6_HOLDER_RELEASE_REQUEST_SENT

```

## Recovery 28 — exit 0

```text
holder session6441 completion after explicit release
Release only after failed-operation rollback evidence, then enter: ROLLBACK


F6_HOLDER_RELEASED_ROLLBACK_CONFIRMED

```

## Recovery 29 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/control/f6/reconcile_existing.sql'
BEGIN
DO
                                                           result                                                            
-----------------------------------------------------------------------------------------------------------------------------
 F6 exact retained fixtures reusable: identity1 credentials0 audiences2 sessions2; no test connections/prepared transactions
(1 row)

ROLLBACK

```

## Recovery 30 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/control/fixtures/097_fault_teardown.sql'
BEGIN
DELETE 2
DELETE 2
DELETE 1
COMMIT

```

## Recovery 31 — exit 0

```text
docker --context default inspect tp-b2a-f-20261014-r01-pg --format '{{json .Id}}{{println}}{{json .Name}}{{println}}{{json .Config.Image}}{{println}}{{json .Config.Labels}}{{println}}{{json .State}}{{println}}{{json .HostConfig.NetworkMode}}{{println}}{{json .HostConfig.Privileged}}{{println}}{{json .HostConfig.PublishAllPorts}}{{println}}{{json .HostConfig.PortBindings}}{{println}}{{json .NetworkSettings.Networks}}{{println}}{{json .Mounts}}{{println}}{{json .Image}}' > .local/b2a-f/f6b-container-fields.jsonl

```

## Recovery 32 — exit 0

```text
docker --context default network inspect tp-b2a-f-20261014-r01-net --format '{{json .}}' > .local/b2a-f/f6b-network.json

```

## Recovery 33 — exit 0

```text
docker --context default volume inspect tp-b2a-f-20261014-r01-data --format '{{json .}}' > .local/b2a-f/f6b-volume-raw.json

```

## Recovery 34 — exit 0

```text
docker --context default image inspect postgres:18.6-bookworm@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c --format '{{json .Id}}{{println}}{{json .RepoDigests}}' > .local/b2a-f/f6b-image.jsonl

```

## Recovery 35 — exit 0

```text
& ./tomopedidos-api/db/verification/f/control/f6/Convert-DockerCapture.ps1 -Fields .local/b2a-f/f6b-container-fields.jsonl -Volume .local/b2a-f/f6b-volume-raw.json -ContainerOut .local/b2a-f/f6b-container.json -VolumeOut .local/b2a-f/f6b-volume.json
& ./tomopedidos-api/db/verification/f/Assert-FDockerSnapshot.ps1 -ContainerJson .local/b2a-f/f6b-container.json -NetworkJson .local/b2a-f/f6b-network.json -VolumeJson .local/b2a-f/f6b-volume.json
$c=Get-Content .local/b2a-f/f6b-container.json -Raw|ConvertFrom-Json
$i=@(Get-Content .local/b2a-f/f6b-image.jsonl)
if(($i[0]|ConvertFrom-Json)-cne $c.Image -or -not ($i[1]|ConvertFrom-Json|Where-Object {$_ -ceq 'postgres@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c'})){throw 'Image content/digest mismatch'}
'PASS actual image digest'
PASS twelve JSON values parsed and selectively serialized; no Docker invoked
PASS saved F Docker identity/ports/network/mount snapshot; refresh live evidence before each future operation. No Docker invoked.
PASS actual image digest

```

## Recovery 36 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v e_stage=enabled -f /f/staged/verification/052_b2a_cleanup_metadata.sql'
BEGIN
SET
DO
SET
psql:/f/staged/administration/b2a-assert-state.sql:199: NOTICE:  D metadata and effective privilege assertions passed: enabled
DO
SET
psql:/f/staged/administration/retention/b2a-cleanup-assert.sql:146: NOTICE:  E metadata/privilege assertions passed: enabled
DO
ROLLBACK

```

## Recovery 37 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=4 -v f_c=enabled -v f_e=enabled -f /f/control/f6/check_transition.sql'
BEGIN
SET
SET
SET
DO
SET
DO
DO
psql:/f/staged/administration/b2a-assert-state.sql:199: NOTICE:  D metadata and effective privilege assertions passed: enabled
SET
psql:/f/staged/administration/retention/b2a-cleanup-assert.sql:146: NOTICE:  E metadata/privilege assertions passed: enabled
DO
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## Recovery 38 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/control/f5/117_final_fault_state.sql'
BEGIN
DO
  system_identifier  |   current_database    | current_setting 
---------------------+-----------------------+-----------------
 7696590721605967915 | tp_b2a_f_20261014_r01 | 180006
(1 row)

                                         result                                          
-----------------------------------------------------------------------------------------
 F5C final state passed: empty tables, Goose4, no test connections/prepared transactions
(1 row)

ROLLBACK

```
