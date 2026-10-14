# F6-B execution transcript — 2026-10-14

Individual exec_command calls; no secret values captured. Includes repeated fresh Docker snapshots and assertions. Each mutation executed once. This transcript stops before final maintenance/retention tests because an auxiliary file read failed.

## 1 — exit 0

```text
docker --context default inspect tp-b2a-f-20261014-r01-pg --format '{{json .Id}}{{println}}{{json .Name}}{{println}}{{json .Config.Image}}{{println}}{{json .Config.Labels}}{{println}}{{json .State}}{{println}}{{json .HostConfig.NetworkMode}}{{println}}{{json .HostConfig.Privileged}}{{println}}{{json .HostConfig.PublishAllPorts}}{{println}}{{json .HostConfig.PortBindings}}{{println}}{{json .NetworkSettings.Networks}}{{println}}{{json .Mounts}}{{println}}{{json .Image}}' > .local/b2a-f/f6b-container-fields.jsonl
```

```text

```

## 2 — exit 0

```text
docker --context default network inspect tp-b2a-f-20261014-r01-net --format '{{json .}}' > .local/b2a-f/f6b-network.json
```

```text

```

## 3 — exit 0

```text
docker --context default volume inspect tp-b2a-f-20261014-r01-data --format '{{json .}}' > .local/b2a-f/f6b-volume-raw.json
```

```text

```

## 4 — exit 0

```text
docker --context default image inspect postgres:18.6-bookworm@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c --format '{{json .Id}}{{println}}{{json .RepoDigests}}' > .local/b2a-f/f6b-image.jsonl
```

```text

```

## 5 — exit 0

```text
& ./tomopedidos-api/db/verification/f/control/f6/Convert-DockerCapture.ps1 -Fields .local/b2a-f/f6b-container-fields.jsonl -Volume .local/b2a-f/f6b-volume-raw.json -ContainerOut .local/b2a-f/f6b-container.json -VolumeOut .local/b2a-f/f6b-volume.json
& ./tomopedidos-api/db/verification/f/Assert-FDockerSnapshot.ps1 -ContainerJson .local/b2a-f/f6b-container.json -NetworkJson .local/b2a-f/f6b-network.json -VolumeJson .local/b2a-f/f6b-volume.json
$c=Get-Content .local/b2a-f/f6b-container.json -Raw|ConvertFrom-Json
$i=@(Get-Content .local/b2a-f/f6b-image.jsonl)
if(($i[0]|ConvertFrom-Json)-cne $c.Image -or -not ($i[1]|ConvertFrom-Json|Where-Object {$_ -ceq 'postgres@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c'})){throw 'Image content/digest mismatch'}
'PASS actual image digest'
```

```text
PASS twelve JSON values parsed and selectively serialized; no Docker invoked
PASS saved F Docker identity/ports/network/mount snapshot; refresh live evidence before each future operation. No Docker invoked.
PASS actual image digest

```

## 6 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=4 -v f_c=enabled -v f_e=enabled -f /f/control/f6/check_transition.sql'
```

```text
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

## 7 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/staged/administration/retention/b2a-cleanup-disable-v1.sql'
```

```text
BEGIN
SET
DO
SET
DO
psql:/f/staged/administration/retention/b2a-cleanup-assert.sql:146: NOTICE:  E metadata/privilege assertions passed: enabled
REVOKE
REVOKE
REVOKE
SET
psql:/f/staged/administration/retention/b2a-cleanup-assert.sql:146: NOTICE:  E metadata/privilege assertions passed: dormant
DO
COMMIT

```

## 8 — exit 0

```text
docker --context default inspect tp-b2a-f-20261014-r01-pg --format '{{json .Id}}{{println}}{{json .Name}}{{println}}{{json .Config.Image}}{{println}}{{json .Config.Labels}}{{println}}{{json .State}}{{println}}{{json .HostConfig.NetworkMode}}{{println}}{{json .HostConfig.Privileged}}{{println}}{{json .HostConfig.PublishAllPorts}}{{println}}{{json .HostConfig.PortBindings}}{{println}}{{json .NetworkSettings.Networks}}{{println}}{{json .Mounts}}{{println}}{{json .Image}}' > .local/b2a-f/f6b-container-fields.jsonl
```

```text

```

## 9 — exit 0

```text
docker --context default network inspect tp-b2a-f-20261014-r01-net --format '{{json .}}' > .local/b2a-f/f6b-network.json
```

```text

```

## 10 — exit 0

```text
docker --context default volume inspect tp-b2a-f-20261014-r01-data --format '{{json .}}' > .local/b2a-f/f6b-volume-raw.json
```

```text

```

## 11 — exit 0

```text
docker --context default image inspect postgres:18.6-bookworm@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c --format '{{json .Id}}{{println}}{{json .RepoDigests}}' > .local/b2a-f/f6b-image.jsonl
```

```text

```

## 12 — exit 0

```text
& ./tomopedidos-api/db/verification/f/control/f6/Convert-DockerCapture.ps1 -Fields .local/b2a-f/f6b-container-fields.jsonl -Volume .local/b2a-f/f6b-volume-raw.json -ContainerOut .local/b2a-f/f6b-container.json -VolumeOut .local/b2a-f/f6b-volume.json
& ./tomopedidos-api/db/verification/f/Assert-FDockerSnapshot.ps1 -ContainerJson .local/b2a-f/f6b-container.json -NetworkJson .local/b2a-f/f6b-network.json -VolumeJson .local/b2a-f/f6b-volume.json
$c=Get-Content .local/b2a-f/f6b-container.json -Raw|ConvertFrom-Json
$i=@(Get-Content .local/b2a-f/f6b-image.jsonl)
if(($i[0]|ConvertFrom-Json)-cne $c.Image -or -not ($i[1]|ConvertFrom-Json|Where-Object {$_ -ceq 'postgres@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c'})){throw 'Image content/digest mismatch'}
'PASS actual image digest'
```

```text
PASS twelve JSON values parsed and selectively serialized; no Docker invoked
PASS saved F Docker identity/ports/network/mount snapshot; refresh live evidence before each future operation. No Docker invoked.
PASS actual image digest

```

## 13 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=4 -v f_c=enabled -v f_e=dormant -f /f/control/f6/check_transition.sql'
```

```text
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
psql:/f/staged/administration/retention/b2a-cleanup-assert.sql:146: NOTICE:  E metadata/privilege assertions passed: dormant
DO
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## 14 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/staged/administration/retention/b2a-session-cleanup-down-v1.sql'
```

```text
BEGIN
SET
DO
SET
psql:/f/staged/administration/retention/b2a-cleanup-assert.sql:146: NOTICE:  E metadata/privilege assertions passed: dormant
DO
DROP FUNCTION
REVOKE
REVOKE
REVOKE
REVOKE
DO
COMMIT

```

## 15 — exit 0

```text
docker --context default inspect tp-b2a-f-20261014-r01-pg --format '{{json .Id}}{{println}}{{json .Name}}{{println}}{{json .Config.Image}}{{println}}{{json .Config.Labels}}{{println}}{{json .State}}{{println}}{{json .HostConfig.NetworkMode}}{{println}}{{json .HostConfig.Privileged}}{{println}}{{json .HostConfig.PublishAllPorts}}{{println}}{{json .HostConfig.PortBindings}}{{println}}{{json .NetworkSettings.Networks}}{{println}}{{json .Mounts}}{{println}}{{json .Image}}' > .local/b2a-f/f6b-container-fields.jsonl
```

```text

```

## 16 — exit 0

```text
docker --context default network inspect tp-b2a-f-20261014-r01-net --format '{{json .}}' > .local/b2a-f/f6b-network.json
```

```text

```

## 17 — exit 0

```text
docker --context default volume inspect tp-b2a-f-20261014-r01-data --format '{{json .}}' > .local/b2a-f/f6b-volume-raw.json
```

```text

```

## 18 — exit 0

```text
docker --context default image inspect postgres:18.6-bookworm@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c --format '{{json .Id}}{{println}}{{json .RepoDigests}}' > .local/b2a-f/f6b-image.jsonl
```

```text

```

## 19 — exit 0

```text
& ./tomopedidos-api/db/verification/f/control/f6/Convert-DockerCapture.ps1 -Fields .local/b2a-f/f6b-container-fields.jsonl -Volume .local/b2a-f/f6b-volume-raw.json -ContainerOut .local/b2a-f/f6b-container.json -VolumeOut .local/b2a-f/f6b-volume.json
& ./tomopedidos-api/db/verification/f/Assert-FDockerSnapshot.ps1 -ContainerJson .local/b2a-f/f6b-container.json -NetworkJson .local/b2a-f/f6b-network.json -VolumeJson .local/b2a-f/f6b-volume.json
$c=Get-Content .local/b2a-f/f6b-container.json -Raw|ConvertFrom-Json
$i=@(Get-Content .local/b2a-f/f6b-image.jsonl)
if(($i[0]|ConvertFrom-Json)-cne $c.Image -or -not ($i[1]|ConvertFrom-Json|Where-Object {$_ -ceq 'postgres@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c'})){throw 'Image content/digest mismatch'}
'PASS actual image digest'
```

```text
PASS twelve JSON values parsed and selectively serialized; no Docker invoked
PASS saved F Docker identity/ports/network/mount snapshot; refresh live evidence before each future operation. No Docker invoked.
PASS actual image digest

```

## 20 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=4 -v f_c=enabled -v f_e=absent -f /f/control/f6/check_transition.sql'
```

```text
BEGIN
SET
SET
SET
DO
SET
DO
DO
psql:/f/staged/administration/b2a-assert-state.sql:199: NOTICE:  D metadata and effective privilege assertions passed: enabled
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## 21 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/staged/administration/b2a-auth-disable-v1.sql'
```

```text
BEGIN
SET
SET
SET
DO
SET
psql:/f/staged/administration/b2a-assert-state.sql:199: NOTICE:  D metadata and effective privilege assertions passed: enabled
DO
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
SET
psql:/f/staged/administration/b2a-assert-state.sql:199: NOTICE:  D metadata and effective privilege assertions passed: executors
DO
COMMIT

```

## 22 — exit 0

```text
docker --context default inspect tp-b2a-f-20261014-r01-pg --format '{{json .Id}}{{println}}{{json .Name}}{{println}}{{json .Config.Image}}{{println}}{{json .Config.Labels}}{{println}}{{json .State}}{{println}}{{json .HostConfig.NetworkMode}}{{println}}{{json .HostConfig.Privileged}}{{println}}{{json .HostConfig.PublishAllPorts}}{{println}}{{json .HostConfig.PortBindings}}{{println}}{{json .NetworkSettings.Networks}}{{println}}{{json .Mounts}}{{println}}{{json .Image}}' > .local/b2a-f/f6b-container-fields.jsonl
```

```text

```

## 23 — exit 0

```text
docker --context default network inspect tp-b2a-f-20261014-r01-net --format '{{json .}}' > .local/b2a-f/f6b-network.json
```

```text

```

## 24 — exit 0

```text
docker --context default volume inspect tp-b2a-f-20261014-r01-data --format '{{json .}}' > .local/b2a-f/f6b-volume-raw.json
```

```text

```

## 25 — exit 0

```text
docker --context default image inspect postgres:18.6-bookworm@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c --format '{{json .Id}}{{println}}{{json .RepoDigests}}' > .local/b2a-f/f6b-image.jsonl
```

```text

```

## 26 — exit 0

```text
& ./tomopedidos-api/db/verification/f/control/f6/Convert-DockerCapture.ps1 -Fields .local/b2a-f/f6b-container-fields.jsonl -Volume .local/b2a-f/f6b-volume-raw.json -ContainerOut .local/b2a-f/f6b-container.json -VolumeOut .local/b2a-f/f6b-volume.json
& ./tomopedidos-api/db/verification/f/Assert-FDockerSnapshot.ps1 -ContainerJson .local/b2a-f/f6b-container.json -NetworkJson .local/b2a-f/f6b-network.json -VolumeJson .local/b2a-f/f6b-volume.json
$c=Get-Content .local/b2a-f/f6b-container.json -Raw|ConvertFrom-Json
$i=@(Get-Content .local/b2a-f/f6b-image.jsonl)
if(($i[0]|ConvertFrom-Json)-cne $c.Image -or -not ($i[1]|ConvertFrom-Json|Where-Object {$_ -ceq 'postgres@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c'})){throw 'Image content/digest mismatch'}
'PASS actual image digest'
```

```text
PASS twelve JSON values parsed and selectively serialized; no Docker invoked
PASS saved F Docker identity/ports/network/mount snapshot; refresh live evidence before each future operation. No Docker invoked.
PASS actual image digest

```

## 27 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=4 -v f_c=executors -v f_e=absent -f /f/control/f6/check_transition.sql'
```

```text
BEGIN
SET
SET
SET
DO
SET
DO
DO
psql:/f/staged/administration/b2a-assert-state.sql:199: NOTICE:  D metadata and effective privilege assertions passed: executors
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## 28 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/staged/administration/b2a-auth-ungrant-v1.sql'
```

```text
BEGIN
SET
SET
SET
DO
SET
psql:/f/staged/administration/b2a-assert-state.sql:199: NOTICE:  D metadata and effective privilege assertions passed: executors
DO
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
SET
psql:/f/staged/administration/b2a-assert-state.sql:199: NOTICE:  D metadata and effective privilege assertions passed: c
DO
COMMIT

```

## 29 — exit 0

```text
docker --context default inspect tp-b2a-f-20261014-r01-pg --format '{{json .Id}}{{println}}{{json .Name}}{{println}}{{json .Config.Image}}{{println}}{{json .Config.Labels}}{{println}}{{json .State}}{{println}}{{json .HostConfig.NetworkMode}}{{println}}{{json .HostConfig.Privileged}}{{println}}{{json .HostConfig.PublishAllPorts}}{{println}}{{json .HostConfig.PortBindings}}{{println}}{{json .NetworkSettings.Networks}}{{println}}{{json .Mounts}}{{println}}{{json .Image}}' > .local/b2a-f/f6b-container-fields.jsonl
```

```text

```

## 30 — exit 0

```text
docker --context default network inspect tp-b2a-f-20261014-r01-net --format '{{json .}}' > .local/b2a-f/f6b-network.json
```

```text

```

## 31 — exit 0

```text
docker --context default volume inspect tp-b2a-f-20261014-r01-data --format '{{json .}}' > .local/b2a-f/f6b-volume-raw.json
```

```text

```

## 32 — exit 0

```text
docker --context default image inspect postgres:18.6-bookworm@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c --format '{{json .Id}}{{println}}{{json .RepoDigests}}' > .local/b2a-f/f6b-image.jsonl
```

```text

```

## 33 — exit 0

```text
& ./tomopedidos-api/db/verification/f/control/f6/Convert-DockerCapture.ps1 -Fields .local/b2a-f/f6b-container-fields.jsonl -Volume .local/b2a-f/f6b-volume-raw.json -ContainerOut .local/b2a-f/f6b-container.json -VolumeOut .local/b2a-f/f6b-volume.json
& ./tomopedidos-api/db/verification/f/Assert-FDockerSnapshot.ps1 -ContainerJson .local/b2a-f/f6b-container.json -NetworkJson .local/b2a-f/f6b-network.json -VolumeJson .local/b2a-f/f6b-volume.json
$c=Get-Content .local/b2a-f/f6b-container.json -Raw|ConvertFrom-Json
$i=@(Get-Content .local/b2a-f/f6b-image.jsonl)
if(($i[0]|ConvertFrom-Json)-cne $c.Image -or -not ($i[1]|ConvertFrom-Json|Where-Object {$_ -ceq 'postgres@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c'})){throw 'Image content/digest mismatch'}
'PASS actual image digest'
```

```text
PASS twelve JSON values parsed and selectively serialized; no Docker invoked
PASS saved F Docker identity/ports/network/mount snapshot; refresh live evidence before each future operation. No Docker invoked.
PASS actual image digest

```

## 34 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=4 -v f_c=c -v f_e=absent -f /f/control/f6/check_transition.sql'
```

```text
BEGIN
SET
SET
SET
DO
SET
DO
DO
psql:/f/staged/administration/b2a-assert-state.sql:199: NOTICE:  D metadata and effective privilege assertions passed: c
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## 35 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/control/003_c_down.sql'
```

```text
BEGIN
SET
DO
SET
psql:/f/staged/administration/b2a-assert-state.sql:199: NOTICE:  D metadata and effective privilege assertions passed: c
DO
DROP FUNCTION
DROP FUNCTION
DROP FUNCTION
DROP FUNCTION
DROP FUNCTION
DROP FUNCTION
DROP FUNCTION
DROP FUNCTION
DROP FUNCTION
DO
COMMIT

```

## 36 — exit 0

```text
docker --context default inspect tp-b2a-f-20261014-r01-pg --format '{{json .Id}}{{println}}{{json .Name}}{{println}}{{json .Config.Image}}{{println}}{{json .Config.Labels}}{{println}}{{json .State}}{{println}}{{json .HostConfig.NetworkMode}}{{println}}{{json .HostConfig.Privileged}}{{println}}{{json .HostConfig.PublishAllPorts}}{{println}}{{json .HostConfig.PortBindings}}{{println}}{{json .NetworkSettings.Networks}}{{println}}{{json .Mounts}}{{println}}{{json .Image}}' > .local/b2a-f/f6b-container-fields.jsonl
```

```text

```

## 37 — exit 0

```text
docker --context default network inspect tp-b2a-f-20261014-r01-net --format '{{json .}}' > .local/b2a-f/f6b-network.json
```

```text

```

## 38 — exit 0

```text
docker --context default volume inspect tp-b2a-f-20261014-r01-data --format '{{json .}}' > .local/b2a-f/f6b-volume-raw.json
```

```text

```

## 39 — exit 0

```text
docker --context default image inspect postgres:18.6-bookworm@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c --format '{{json .Id}}{{println}}{{json .RepoDigests}}' > .local/b2a-f/f6b-image.jsonl
```

```text

```

## 40 — exit 0

```text
& ./tomopedidos-api/db/verification/f/control/f6/Convert-DockerCapture.ps1 -Fields .local/b2a-f/f6b-container-fields.jsonl -Volume .local/b2a-f/f6b-volume-raw.json -ContainerOut .local/b2a-f/f6b-container.json -VolumeOut .local/b2a-f/f6b-volume.json
& ./tomopedidos-api/db/verification/f/Assert-FDockerSnapshot.ps1 -ContainerJson .local/b2a-f/f6b-container.json -NetworkJson .local/b2a-f/f6b-network.json -VolumeJson .local/b2a-f/f6b-volume.json
$c=Get-Content .local/b2a-f/f6b-container.json -Raw|ConvertFrom-Json
$i=@(Get-Content .local/b2a-f/f6b-image.jsonl)
if(($i[0]|ConvertFrom-Json)-cne $c.Image -or -not ($i[1]|ConvertFrom-Json|Where-Object {$_ -ceq 'postgres@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c'})){throw 'Image content/digest mismatch'}
'PASS actual image digest'
```

```text
PASS twelve JSON values parsed and selectively serialized; no Docker invoked
PASS saved F Docker identity/ports/network/mount snapshot; refresh live evidence before each future operation. No Docker invoked.
PASS actual image digest

```

## 41 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=4 -v f_c=absent -v f_e=absent -f /f/control/f6/check_transition.sql'
```

```text
BEGIN
SET
SET
SET
DO
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## 42 — exit 0

```text
docker --context default compose --env-file "D:\tomopedidos\.local\b2a-f\r01.private.env" --env-file "D:\tomopedidos\.local\b2a-f\r01.tools.private.env" -f "D:\tomopedidos\tomopedidos-api\db\verification\f\compose.f.yaml" -f "D:\tomopedidos\tomopedidos-api\db\verification\f\compose.tools.yaml" -p tp-b2a-f-20261014-r01 --profile tools run --name tp-b2a-f-20261014-r01-f6-goose-down3 --no-deps goose -dir /migrations -table migration_meta.goose_db_version down-to 3
```

```text
time="2026-10-14T17:57:47-05:00" level=warning msg="Found orphan containers (tp-b2a-f-20261014-r01-goose-up4, tp-b2a-f-20261014-r01-goose-up3, tp-b2a-f-20261014-r01-goose-up2, tp-b2a-f-20261014-r01-goose-up1, tp-b2a-f-20261014-r01-goose-validate, tp-b2a-f-20261014-r01-goose-version) for this project. If you removed or renamed this service in your compose file, you can run this command with the --remove-orphans flag to clean it up."
 Container tp-b2a-f-20261014-r01-f6-goose-down3 Creating 
 Container tp-b2a-f-20261014-r01-f6-goose-down3 Created 
2026/10/14 22:57:48 OK   00004_session_cleanup_index.sql (13.04ms)
2026/10/14 22:57:48 goose: no migrations to run. current version: 3

```

## 43 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=3 -v f_c=absent -v f_e=absent -f /f/control/f6/check_transition.sql'
```

```text
BEGIN
SET
SET
SET
DO
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## 44 — exit 0

```text
docker --context default inspect tp-b2a-f-20261014-r01-pg --format '{{json .Id}}{{println}}{{json .Name}}{{println}}{{json .Config.Image}}{{println}}{{json .Config.Labels}}{{println}}{{json .State}}{{println}}{{json .HostConfig.NetworkMode}}{{println}}{{json .HostConfig.Privileged}}{{println}}{{json .HostConfig.PublishAllPorts}}{{println}}{{json .HostConfig.PortBindings}}{{println}}{{json .NetworkSettings.Networks}}{{println}}{{json .Mounts}}{{println}}{{json .Image}}' > .local/b2a-f/f6b-container-fields.jsonl
```

```text

```

## 45 — exit 0

```text
docker --context default network inspect tp-b2a-f-20261014-r01-net --format '{{json .}}' > .local/b2a-f/f6b-network.json
```

```text

```

## 46 — exit 0

```text
docker --context default volume inspect tp-b2a-f-20261014-r01-data --format '{{json .}}' > .local/b2a-f/f6b-volume-raw.json
```

```text

```

## 47 — exit 0

```text
docker --context default image inspect postgres:18.6-bookworm@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c --format '{{json .Id}}{{println}}{{json .RepoDigests}}' > .local/b2a-f/f6b-image.jsonl
```

```text

```

## 48 — exit 0

```text
& ./tomopedidos-api/db/verification/f/control/f6/Convert-DockerCapture.ps1 -Fields .local/b2a-f/f6b-container-fields.jsonl -Volume .local/b2a-f/f6b-volume-raw.json -ContainerOut .local/b2a-f/f6b-container.json -VolumeOut .local/b2a-f/f6b-volume.json
& ./tomopedidos-api/db/verification/f/Assert-FDockerSnapshot.ps1 -ContainerJson .local/b2a-f/f6b-container.json -NetworkJson .local/b2a-f/f6b-network.json -VolumeJson .local/b2a-f/f6b-volume.json
$c=Get-Content .local/b2a-f/f6b-container.json -Raw|ConvertFrom-Json
$i=@(Get-Content .local/b2a-f/f6b-image.jsonl)
if(($i[0]|ConvertFrom-Json)-cne $c.Image -or -not ($i[1]|ConvertFrom-Json|Where-Object {$_ -ceq 'postgres@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c'})){throw 'Image content/digest mismatch'}
'PASS actual image digest'
```

```text
PASS twelve JSON values parsed and selectively serialized; no Docker invoked
PASS saved F Docker identity/ports/network/mount snapshot; refresh live evidence before each future operation. No Docker invoked.
PASS actual image digest

```

## 49 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=3 -v f_c=absent -v f_e=absent -f /f/control/f6/check_transition.sql'
```

```text
BEGIN
SET
SET
SET
DO
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## 50 — exit 0

```text
docker --context default compose --env-file "D:\tomopedidos\.local\b2a-f\r01.private.env" --env-file "D:\tomopedidos\.local\b2a-f\r01.tools.private.env" -f "D:\tomopedidos\tomopedidos-api\db\verification\f\compose.f.yaml" -f "D:\tomopedidos\tomopedidos-api\db\verification\f\compose.tools.yaml" -p tp-b2a-f-20261014-r01 --profile tools run --name tp-b2a-f-20261014-r01-f6-goose-down2 --no-deps goose -dir /migrations -table migration_meta.goose_db_version down-to 2
```

```text
time="2026-10-14T17:58:00-05:00" level=warning msg="Found orphan containers (tp-b2a-f-20261014-r01-f6-goose-down3, tp-b2a-f-20261014-r01-goose-up4, tp-b2a-f-20261014-r01-goose-up3, tp-b2a-f-20261014-r01-goose-up2, tp-b2a-f-20261014-r01-goose-up1, tp-b2a-f-20261014-r01-goose-validate, tp-b2a-f-20261014-r01-goose-version) for this project. If you removed or renamed this service in your compose file, you can run this command with the --remove-orphans flag to clean it up."
 Container tp-b2a-f-20261014-r01-f6-goose-down2 Creating 
 Container tp-b2a-f-20261014-r01-f6-goose-down2 Created 
2026/10/14 22:58:00 OK   00003_identity_guards_indexes.sql (8.08ms)
2026/10/14 22:58:00 goose: no migrations to run. current version: 2

```

## 51 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=2 -v f_c=absent -v f_e=absent -f /f/control/f6/check_transition.sql'
```

```text
BEGIN
SET
SET
SET
DO
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## 52 — exit 0

```text
docker --context default inspect tp-b2a-f-20261014-r01-pg --format '{{json .Id}}{{println}}{{json .Name}}{{println}}{{json .Config.Image}}{{println}}{{json .Config.Labels}}{{println}}{{json .State}}{{println}}{{json .HostConfig.NetworkMode}}{{println}}{{json .HostConfig.Privileged}}{{println}}{{json .HostConfig.PublishAllPorts}}{{println}}{{json .HostConfig.PortBindings}}{{println}}{{json .NetworkSettings.Networks}}{{println}}{{json .Mounts}}{{println}}{{json .Image}}' > .local/b2a-f/f6b-container-fields.jsonl
```

```text

```

## 53 — exit 0

```text
docker --context default network inspect tp-b2a-f-20261014-r01-net --format '{{json .}}' > .local/b2a-f/f6b-network.json
```

```text

```

## 54 — exit 0

```text
docker --context default volume inspect tp-b2a-f-20261014-r01-data --format '{{json .}}' > .local/b2a-f/f6b-volume-raw.json
```

```text

```

## 55 — exit 0

```text
docker --context default image inspect postgres:18.6-bookworm@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c --format '{{json .Id}}{{println}}{{json .RepoDigests}}' > .local/b2a-f/f6b-image.jsonl
```

```text

```

## 56 — exit 0

```text
& ./tomopedidos-api/db/verification/f/control/f6/Convert-DockerCapture.ps1 -Fields .local/b2a-f/f6b-container-fields.jsonl -Volume .local/b2a-f/f6b-volume-raw.json -ContainerOut .local/b2a-f/f6b-container.json -VolumeOut .local/b2a-f/f6b-volume.json
& ./tomopedidos-api/db/verification/f/Assert-FDockerSnapshot.ps1 -ContainerJson .local/b2a-f/f6b-container.json -NetworkJson .local/b2a-f/f6b-network.json -VolumeJson .local/b2a-f/f6b-volume.json
$c=Get-Content .local/b2a-f/f6b-container.json -Raw|ConvertFrom-Json
$i=@(Get-Content .local/b2a-f/f6b-image.jsonl)
if(($i[0]|ConvertFrom-Json)-cne $c.Image -or -not ($i[1]|ConvertFrom-Json|Where-Object {$_ -ceq 'postgres@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c'})){throw 'Image content/digest mismatch'}
'PASS actual image digest'
```

```text
PASS twelve JSON values parsed and selectively serialized; no Docker invoked
PASS saved F Docker identity/ports/network/mount snapshot; refresh live evidence before each future operation. No Docker invoked.
PASS actual image digest

```

## 57 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=2 -v f_c=absent -v f_e=absent -f /f/control/f6/check_transition.sql'
```

```text
BEGIN
SET
SET
SET
DO
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## 58 — exit 0

```text
docker --context default compose --env-file "D:\tomopedidos\.local\b2a-f\r01.private.env" --env-file "D:\tomopedidos\.local\b2a-f\r01.tools.private.env" -f "D:\tomopedidos\tomopedidos-api\db\verification\f\compose.f.yaml" -f "D:\tomopedidos\tomopedidos-api\db\verification\f\compose.tools.yaml" -p tp-b2a-f-20261014-r01 --profile tools run --name tp-b2a-f-20261014-r01-f6-goose-down1 --no-deps goose -dir /migrations -table migration_meta.goose_db_version down-to 1
```

```text
time="2026-10-14T17:58:13-05:00" level=warning msg="Found orphan containers (tp-b2a-f-20261014-r01-f6-goose-down2, tp-b2a-f-20261014-r01-f6-goose-down3, tp-b2a-f-20261014-r01-goose-up4, tp-b2a-f-20261014-r01-goose-up3, tp-b2a-f-20261014-r01-goose-up2, tp-b2a-f-20261014-r01-goose-up1, tp-b2a-f-20261014-r01-goose-validate, tp-b2a-f-20261014-r01-goose-version) for this project. If you removed or renamed this service in your compose file, you can run this command with the --remove-orphans flag to clean it up."
 Container tp-b2a-f-20261014-r01-f6-goose-down1 Creating 
 Container tp-b2a-f-20261014-r01-f6-goose-down1 Created 
2026/10/14 22:58:13 OK   00002_audience_sessions.sql (13.49ms)
2026/10/14 22:58:13 goose: no migrations to run. current version: 1

```

## 59 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=1 -v f_c=absent -v f_e=absent -f /f/control/f6/check_transition.sql'
```

```text
BEGIN
SET
SET
SET
DO
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## 60 — exit 0

```text
docker --context default inspect tp-b2a-f-20261014-r01-pg --format '{{json .Id}}{{println}}{{json .Name}}{{println}}{{json .Config.Image}}{{println}}{{json .Config.Labels}}{{println}}{{json .State}}{{println}}{{json .HostConfig.NetworkMode}}{{println}}{{json .HostConfig.Privileged}}{{println}}{{json .HostConfig.PublishAllPorts}}{{println}}{{json .HostConfig.PortBindings}}{{println}}{{json .NetworkSettings.Networks}}{{println}}{{json .Mounts}}{{println}}{{json .Image}}' > .local/b2a-f/f6b-container-fields.jsonl
```

```text

```

## 61 — exit 0

```text
docker --context default network inspect tp-b2a-f-20261014-r01-net --format '{{json .}}' > .local/b2a-f/f6b-network.json
```

```text

```

## 62 — exit 0

```text
docker --context default volume inspect tp-b2a-f-20261014-r01-data --format '{{json .}}' > .local/b2a-f/f6b-volume-raw.json
```

```text

```

## 63 — exit 0

```text
docker --context default image inspect postgres:18.6-bookworm@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c --format '{{json .Id}}{{println}}{{json .RepoDigests}}' > .local/b2a-f/f6b-image.jsonl
```

```text

```

## 64 — exit 0

```text
& ./tomopedidos-api/db/verification/f/control/f6/Convert-DockerCapture.ps1 -Fields .local/b2a-f/f6b-container-fields.jsonl -Volume .local/b2a-f/f6b-volume-raw.json -ContainerOut .local/b2a-f/f6b-container.json -VolumeOut .local/b2a-f/f6b-volume.json
& ./tomopedidos-api/db/verification/f/Assert-FDockerSnapshot.ps1 -ContainerJson .local/b2a-f/f6b-container.json -NetworkJson .local/b2a-f/f6b-network.json -VolumeJson .local/b2a-f/f6b-volume.json
$c=Get-Content .local/b2a-f/f6b-container.json -Raw|ConvertFrom-Json
$i=@(Get-Content .local/b2a-f/f6b-image.jsonl)
if(($i[0]|ConvertFrom-Json)-cne $c.Image -or -not ($i[1]|ConvertFrom-Json|Where-Object {$_ -ceq 'postgres@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c'})){throw 'Image content/digest mismatch'}
'PASS actual image digest'
```

```text
PASS twelve JSON values parsed and selectively serialized; no Docker invoked
PASS saved F Docker identity/ports/network/mount snapshot; refresh live evidence before each future operation. No Docker invoked.
PASS actual image digest

```

## 65 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=1 -v f_c=absent -v f_e=absent -f /f/control/f6/check_transition.sql'
```

```text
BEGIN
SET
SET
SET
DO
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## 66 — exit 0

```text
docker --context default compose --env-file "D:\tomopedidos\.local\b2a-f\r01.private.env" --env-file "D:\tomopedidos\.local\b2a-f\r01.tools.private.env" -f "D:\tomopedidos\tomopedidos-api\db\verification\f\compose.f.yaml" -f "D:\tomopedidos\tomopedidos-api\db\verification\f\compose.tools.yaml" -p tp-b2a-f-20261014-r01 --profile tools run --name tp-b2a-f-20261014-r01-f6-goose-down0 --no-deps goose -dir /migrations -table migration_meta.goose_db_version down-to 0
```

```text
time="2026-10-14T17:58:25-05:00" level=warning msg="Found orphan containers (tp-b2a-f-20261014-r01-f6-goose-down1, tp-b2a-f-20261014-r01-f6-goose-down2, tp-b2a-f-20261014-r01-f6-goose-down3, tp-b2a-f-20261014-r01-goose-up4, tp-b2a-f-20261014-r01-goose-up3, tp-b2a-f-20261014-r01-goose-up2, tp-b2a-f-20261014-r01-goose-up1, tp-b2a-f-20261014-r01-goose-validate, tp-b2a-f-20261014-r01-goose-version) for this project. If you removed or renamed this service in your compose file, you can run this command with the --remove-orphans flag to clean it up."
 Container tp-b2a-f-20261014-r01-f6-goose-down0 Creating 
 Container tp-b2a-f-20261014-r01-f6-goose-down0 Created 
2026/10/14 22:58:25 OK   00001_identity_credentials.sql (12.01ms)
2026/10/14 22:58:25 goose: no migrations to run. current version: 0

```

## 67 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=0 -v f_c=absent -v f_e=absent -f /f/control/f6/check_transition.sql'
```

```text
BEGIN
SET
SET
SET
DO
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## 68 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/control/002_post_down.sql'
```

```text
BEGIN
psql:/f/control/002_post_down.sql:21: NOTICE:  F post-Down metadata checks passed; roles and Goose metadata intentionally retained
DO
ROLLBACK

```

## 69 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/staged/verification/010_b1_metadata.sql'
```

```text
BEGIN
SET
DO
          result           
---------------------------
 B1 metadata checks passed
(1 row)

ROLLBACK

```

## 70 — exit 0

```text
docker --context default inspect tp-b2a-f-20261014-r01-pg --format '{{json .Id}}{{println}}{{json .Name}}{{println}}{{json .Config.Image}}{{println}}{{json .Config.Labels}}{{println}}{{json .State}}{{println}}{{json .HostConfig.NetworkMode}}{{println}}{{json .HostConfig.Privileged}}{{println}}{{json .HostConfig.PublishAllPorts}}{{println}}{{json .HostConfig.PortBindings}}{{println}}{{json .NetworkSettings.Networks}}{{println}}{{json .Mounts}}{{println}}{{json .Image}}' > .local/b2a-f/f6b-container-fields.jsonl
```

```text

```

## 71 — exit 0

```text
docker --context default network inspect tp-b2a-f-20261014-r01-net --format '{{json .}}' > .local/b2a-f/f6b-network.json
```

```text

```

## 72 — exit 0

```text
docker --context default volume inspect tp-b2a-f-20261014-r01-data --format '{{json .}}' > .local/b2a-f/f6b-volume-raw.json
```

```text

```

## 73 — exit 0

```text
docker --context default image inspect postgres:18.6-bookworm@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c --format '{{json .Id}}{{println}}{{json .RepoDigests}}' > .local/b2a-f/f6b-image.jsonl
```

```text

```

## 74 — exit 0

```text
& ./tomopedidos-api/db/verification/f/control/f6/Convert-DockerCapture.ps1 -Fields .local/b2a-f/f6b-container-fields.jsonl -Volume .local/b2a-f/f6b-volume-raw.json -ContainerOut .local/b2a-f/f6b-container.json -VolumeOut .local/b2a-f/f6b-volume.json
& ./tomopedidos-api/db/verification/f/Assert-FDockerSnapshot.ps1 -ContainerJson .local/b2a-f/f6b-container.json -NetworkJson .local/b2a-f/f6b-network.json -VolumeJson .local/b2a-f/f6b-volume.json
$c=Get-Content .local/b2a-f/f6b-container.json -Raw|ConvertFrom-Json
$i=@(Get-Content .local/b2a-f/f6b-image.jsonl)
if(($i[0]|ConvertFrom-Json)-cne $c.Image -or -not ($i[1]|ConvertFrom-Json|Where-Object {$_ -ceq 'postgres@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c'})){throw 'Image content/digest mismatch'}
'PASS actual image digest'
```

```text
PASS twelve JSON values parsed and selectively serialized; no Docker invoked
PASS saved F Docker identity/ports/network/mount snapshot; refresh live evidence before each future operation. No Docker invoked.
PASS actual image digest

```

## 75 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=0 -v f_c=absent -v f_e=absent -f /f/control/f6/check_transition.sql'
```

```text
BEGIN
SET
SET
SET
DO
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## 76 — exit 0

```text
docker --context default compose --env-file "D:\tomopedidos\.local\b2a-f\r01.private.env" --env-file "D:\tomopedidos\.local\b2a-f\r01.tools.private.env" -f "D:\tomopedidos\tomopedidos-api\db\verification\f\compose.f.yaml" -f "D:\tomopedidos\tomopedidos-api\db\verification\f\compose.tools.yaml" -p tp-b2a-f-20261014-r01 --profile tools run --name tp-b2a-f-20261014-r01-f6-goose-up1 --no-deps goose -dir /migrations -table migration_meta.goose_db_version up-to 1
```

```text
time="2026-10-14T17:58:43-05:00" level=warning msg="Found orphan containers (tp-b2a-f-20261014-r01-f6-goose-down0, tp-b2a-f-20261014-r01-f6-goose-down1, tp-b2a-f-20261014-r01-f6-goose-down2, tp-b2a-f-20261014-r01-f6-goose-down3, tp-b2a-f-20261014-r01-goose-up4, tp-b2a-f-20261014-r01-goose-up3, tp-b2a-f-20261014-r01-goose-up2, tp-b2a-f-20261014-r01-goose-up1, tp-b2a-f-20261014-r01-goose-validate, tp-b2a-f-20261014-r01-goose-version) for this project. If you removed or renamed this service in your compose file, you can run this command with the --remove-orphans flag to clean it up."
 Container tp-b2a-f-20261014-r01-f6-goose-up1 Creating 
 Container tp-b2a-f-20261014-r01-f6-goose-up1 Created 
2026/10/14 22:58:44 OK   00001_identity_credentials.sql (27.95ms)
2026/10/14 22:58:44 goose: successfully migrated database to version: 1

```

## 77 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=1 -v f_c=absent -v f_e=absent -f /f/control/f6/check_transition.sql'
```

```text
BEGIN
SET
SET
SET
DO
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## 78 — exit 0

```text
docker --context default inspect tp-b2a-f-20261014-r01-pg --format '{{json .Id}}{{println}}{{json .Name}}{{println}}{{json .Config.Image}}{{println}}{{json .Config.Labels}}{{println}}{{json .State}}{{println}}{{json .HostConfig.NetworkMode}}{{println}}{{json .HostConfig.Privileged}}{{println}}{{json .HostConfig.PublishAllPorts}}{{println}}{{json .HostConfig.PortBindings}}{{println}}{{json .NetworkSettings.Networks}}{{println}}{{json .Mounts}}{{println}}{{json .Image}}' > .local/b2a-f/f6b-container-fields.jsonl
```

```text

```

## 79 — exit 0

```text
docker --context default network inspect tp-b2a-f-20261014-r01-net --format '{{json .}}' > .local/b2a-f/f6b-network.json
```

```text

```

## 80 — exit 0

```text
docker --context default volume inspect tp-b2a-f-20261014-r01-data --format '{{json .}}' > .local/b2a-f/f6b-volume-raw.json
```

```text

```

## 81 — exit 0

```text
docker --context default image inspect postgres:18.6-bookworm@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c --format '{{json .Id}}{{println}}{{json .RepoDigests}}' > .local/b2a-f/f6b-image.jsonl
```

```text

```

## 82 — exit 0

```text
& ./tomopedidos-api/db/verification/f/control/f6/Convert-DockerCapture.ps1 -Fields .local/b2a-f/f6b-container-fields.jsonl -Volume .local/b2a-f/f6b-volume-raw.json -ContainerOut .local/b2a-f/f6b-container.json -VolumeOut .local/b2a-f/f6b-volume.json
& ./tomopedidos-api/db/verification/f/Assert-FDockerSnapshot.ps1 -ContainerJson .local/b2a-f/f6b-container.json -NetworkJson .local/b2a-f/f6b-network.json -VolumeJson .local/b2a-f/f6b-volume.json
$c=Get-Content .local/b2a-f/f6b-container.json -Raw|ConvertFrom-Json
$i=@(Get-Content .local/b2a-f/f6b-image.jsonl)
if(($i[0]|ConvertFrom-Json)-cne $c.Image -or -not ($i[1]|ConvertFrom-Json|Where-Object {$_ -ceq 'postgres@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c'})){throw 'Image content/digest mismatch'}
'PASS actual image digest'
```

```text
PASS twelve JSON values parsed and selectively serialized; no Docker invoked
PASS saved F Docker identity/ports/network/mount snapshot; refresh live evidence before each future operation. No Docker invoked.
PASS actual image digest

```

## 83 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=1 -v f_c=absent -v f_e=absent -f /f/control/f6/check_transition.sql'
```

```text
BEGIN
SET
SET
SET
DO
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## 84 — exit 0

```text
docker --context default compose --env-file "D:\tomopedidos\.local\b2a-f\r01.private.env" --env-file "D:\tomopedidos\.local\b2a-f\r01.tools.private.env" -f "D:\tomopedidos\tomopedidos-api\db\verification\f\compose.f.yaml" -f "D:\tomopedidos\tomopedidos-api\db\verification\f\compose.tools.yaml" -p tp-b2a-f-20261014-r01 --profile tools run --name tp-b2a-f-20261014-r01-f6-goose-up2 --no-deps goose -dir /migrations -table migration_meta.goose_db_version up-to 2
```

```text
time="2026-10-14T17:58:58-05:00" level=warning msg="Found orphan containers (tp-b2a-f-20261014-r01-f6-goose-up1, tp-b2a-f-20261014-r01-f6-goose-down0, tp-b2a-f-20261014-r01-f6-goose-down1, tp-b2a-f-20261014-r01-f6-goose-down2, tp-b2a-f-20261014-r01-f6-goose-down3, tp-b2a-f-20261014-r01-goose-up4, tp-b2a-f-20261014-r01-goose-up3, tp-b2a-f-20261014-r01-goose-up2, tp-b2a-f-20261014-r01-goose-up1, tp-b2a-f-20261014-r01-goose-validate, tp-b2a-f-20261014-r01-goose-version) for this project. If you removed or renamed this service in your compose file, you can run this command with the --remove-orphans flag to clean it up."
 Container tp-b2a-f-20261014-r01-f6-goose-up2 Creating 
 Container tp-b2a-f-20261014-r01-f6-goose-up2 Created 
2026/10/14 22:58:59 OK   00002_audience_sessions.sql (19.05ms)
2026/10/14 22:58:59 goose: successfully migrated database to version: 2

```

## 85 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=2 -v f_c=absent -v f_e=absent -f /f/control/f6/check_transition.sql'
```

```text
BEGIN
SET
SET
SET
DO
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## 86 — exit 0

```text
docker --context default inspect tp-b2a-f-20261014-r01-pg --format '{{json .Id}}{{println}}{{json .Name}}{{println}}{{json .Config.Image}}{{println}}{{json .Config.Labels}}{{println}}{{json .State}}{{println}}{{json .HostConfig.NetworkMode}}{{println}}{{json .HostConfig.Privileged}}{{println}}{{json .HostConfig.PublishAllPorts}}{{println}}{{json .HostConfig.PortBindings}}{{println}}{{json .NetworkSettings.Networks}}{{println}}{{json .Mounts}}{{println}}{{json .Image}}' > .local/b2a-f/f6b-container-fields.jsonl
```

```text

```

## 87 — exit 0

```text
docker --context default network inspect tp-b2a-f-20261014-r01-net --format '{{json .}}' > .local/b2a-f/f6b-network.json
```

```text

```

## 88 — exit 0

```text
docker --context default volume inspect tp-b2a-f-20261014-r01-data --format '{{json .}}' > .local/b2a-f/f6b-volume-raw.json
```

```text

```

## 89 — exit 0

```text
docker --context default image inspect postgres:18.6-bookworm@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c --format '{{json .Id}}{{println}}{{json .RepoDigests}}' > .local/b2a-f/f6b-image.jsonl
```

```text

```

## 90 — exit 0

```text
& ./tomopedidos-api/db/verification/f/control/f6/Convert-DockerCapture.ps1 -Fields .local/b2a-f/f6b-container-fields.jsonl -Volume .local/b2a-f/f6b-volume-raw.json -ContainerOut .local/b2a-f/f6b-container.json -VolumeOut .local/b2a-f/f6b-volume.json
& ./tomopedidos-api/db/verification/f/Assert-FDockerSnapshot.ps1 -ContainerJson .local/b2a-f/f6b-container.json -NetworkJson .local/b2a-f/f6b-network.json -VolumeJson .local/b2a-f/f6b-volume.json
$c=Get-Content .local/b2a-f/f6b-container.json -Raw|ConvertFrom-Json
$i=@(Get-Content .local/b2a-f/f6b-image.jsonl)
if(($i[0]|ConvertFrom-Json)-cne $c.Image -or -not ($i[1]|ConvertFrom-Json|Where-Object {$_ -ceq 'postgres@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c'})){throw 'Image content/digest mismatch'}
'PASS actual image digest'
```

```text
PASS twelve JSON values parsed and selectively serialized; no Docker invoked
PASS saved F Docker identity/ports/network/mount snapshot; refresh live evidence before each future operation. No Docker invoked.
PASS actual image digest

```

## 91 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=2 -v f_c=absent -v f_e=absent -f /f/control/f6/check_transition.sql'
```

```text
BEGIN
SET
SET
SET
DO
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## 92 — exit 0

```text
docker --context default compose --env-file "D:\tomopedidos\.local\b2a-f\r01.private.env" --env-file "D:\tomopedidos\.local\b2a-f\r01.tools.private.env" -f "D:\tomopedidos\tomopedidos-api\db\verification\f\compose.f.yaml" -f "D:\tomopedidos\tomopedidos-api\db\verification\f\compose.tools.yaml" -p tp-b2a-f-20261014-r01 --profile tools run --name tp-b2a-f-20261014-r01-f6-goose-up3 --no-deps goose -dir /migrations -table migration_meta.goose_db_version up-to 3
```

```text
time="2026-10-14T17:59:15-05:00" level=warning msg="Found orphan containers (tp-b2a-f-20261014-r01-f6-goose-up2, tp-b2a-f-20261014-r01-f6-goose-up1, tp-b2a-f-20261014-r01-f6-goose-down0, tp-b2a-f-20261014-r01-f6-goose-down1, tp-b2a-f-20261014-r01-f6-goose-down2, tp-b2a-f-20261014-r01-f6-goose-down3, tp-b2a-f-20261014-r01-goose-up4, tp-b2a-f-20261014-r01-goose-up3, tp-b2a-f-20261014-r01-goose-up2, tp-b2a-f-20261014-r01-goose-up1, tp-b2a-f-20261014-r01-goose-validate, tp-b2a-f-20261014-r01-goose-version) for this project. If you removed or renamed this service in your compose file, you can run this command with the --remove-orphans flag to clean it up."
 Container tp-b2a-f-20261014-r01-f6-goose-up3 Creating 
 Container tp-b2a-f-20261014-r01-f6-goose-up3 Created 
2026/10/14 22:59:16 OK   00003_identity_guards_indexes.sql (12.38ms)
2026/10/14 22:59:16 goose: successfully migrated database to version: 3

```

## 93 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=3 -v f_c=absent -v f_e=absent -f /f/control/f6/check_transition.sql'
```

```text
BEGIN
SET
SET
SET
DO
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## 94 — exit 0

```text
docker --context default inspect tp-b2a-f-20261014-r01-pg --format '{{json .Id}}{{println}}{{json .Name}}{{println}}{{json .Config.Image}}{{println}}{{json .Config.Labels}}{{println}}{{json .State}}{{println}}{{json .HostConfig.NetworkMode}}{{println}}{{json .HostConfig.Privileged}}{{println}}{{json .HostConfig.PublishAllPorts}}{{println}}{{json .HostConfig.PortBindings}}{{println}}{{json .NetworkSettings.Networks}}{{println}}{{json .Mounts}}{{println}}{{json .Image}}' > .local/b2a-f/f6b-container-fields.jsonl
```

```text

```

## 95 — exit 0

```text
docker --context default network inspect tp-b2a-f-20261014-r01-net --format '{{json .}}' > .local/b2a-f/f6b-network.json
```

```text

```

## 96 — exit 0

```text
docker --context default volume inspect tp-b2a-f-20261014-r01-data --format '{{json .}}' > .local/b2a-f/f6b-volume-raw.json
```

```text

```

## 97 — exit 0

```text
docker --context default image inspect postgres:18.6-bookworm@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c --format '{{json .Id}}{{println}}{{json .RepoDigests}}' > .local/b2a-f/f6b-image.jsonl
```

```text

```

## 98 — exit 0

```text
& ./tomopedidos-api/db/verification/f/control/f6/Convert-DockerCapture.ps1 -Fields .local/b2a-f/f6b-container-fields.jsonl -Volume .local/b2a-f/f6b-volume-raw.json -ContainerOut .local/b2a-f/f6b-container.json -VolumeOut .local/b2a-f/f6b-volume.json
& ./tomopedidos-api/db/verification/f/Assert-FDockerSnapshot.ps1 -ContainerJson .local/b2a-f/f6b-container.json -NetworkJson .local/b2a-f/f6b-network.json -VolumeJson .local/b2a-f/f6b-volume.json
$c=Get-Content .local/b2a-f/f6b-container.json -Raw|ConvertFrom-Json
$i=@(Get-Content .local/b2a-f/f6b-image.jsonl)
if(($i[0]|ConvertFrom-Json)-cne $c.Image -or -not ($i[1]|ConvertFrom-Json|Where-Object {$_ -ceq 'postgres@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c'})){throw 'Image content/digest mismatch'}
'PASS actual image digest'
```

```text
PASS twelve JSON values parsed and selectively serialized; no Docker invoked
PASS saved F Docker identity/ports/network/mount snapshot; refresh live evidence before each future operation. No Docker invoked.
PASS actual image digest

```

## 99 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=3 -v f_c=absent -v f_e=absent -f /f/control/f6/check_transition.sql'
```

```text
BEGIN
SET
SET
SET
DO
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## 100 — exit 0

```text
docker --context default compose --env-file "D:\tomopedidos\.local\b2a-f\r01.private.env" --env-file "D:\tomopedidos\.local\b2a-f\r01.tools.private.env" -f "D:\tomopedidos\tomopedidos-api\db\verification\f\compose.f.yaml" -f "D:\tomopedidos\tomopedidos-api\db\verification\f\compose.tools.yaml" -p tp-b2a-f-20261014-r01 --profile tools run --name tp-b2a-f-20261014-r01-f6-goose-up4 --no-deps goose -dir /migrations -table migration_meta.goose_db_version up-to 4
```

```text
time="2026-10-14T17:59:28-05:00" level=warning msg="Found orphan containers (tp-b2a-f-20261014-r01-f6-goose-up3, tp-b2a-f-20261014-r01-f6-goose-up2, tp-b2a-f-20261014-r01-f6-goose-up1, tp-b2a-f-20261014-r01-f6-goose-down0, tp-b2a-f-20261014-r01-f6-goose-down1, tp-b2a-f-20261014-r01-f6-goose-down2, tp-b2a-f-20261014-r01-f6-goose-down3, tp-b2a-f-20261014-r01-goose-up4, tp-b2a-f-20261014-r01-goose-up3, tp-b2a-f-20261014-r01-goose-up2, tp-b2a-f-20261014-r01-goose-up1, tp-b2a-f-20261014-r01-goose-validate, tp-b2a-f-20261014-r01-goose-version) for this project. If you removed or renamed this service in your compose file, you can run this command with the --remove-orphans flag to clean it up."
 Container tp-b2a-f-20261014-r01-f6-goose-up4 Creating 
 Container tp-b2a-f-20261014-r01-f6-goose-up4 Created 
2026/10/14 22:59:29 OK   00004_session_cleanup_index.sql (6.67ms)
2026/10/14 22:59:29 goose: successfully migrated database to version: 4

```

## 101 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=4 -v f_c=absent -v f_e=absent -f /f/control/f6/check_transition.sql'
```

```text
BEGIN
SET
SET
SET
DO
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## 102 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/control/004_migration_metadata.sql'
```

```text
Warning: truncated output (original token count: 4554)
Total output lines: 120

BEGIN
DO
psql:/f/control/004_migration_metadata.sql:26: NOTICE:  F Up 4 metadata checks passed
       relname        |       attname        |       format_type        | attnotnull | attgenerated |                                            default_sql                                            
----------------------+----------------------+--------------------------+------------+--------------+---------------------------------------------------------------------------------------------------
 audience_revocations | identity_id          | uuid                     | t          |              | 
 audience_revocations | audience             | text                     | t          |              | 
 audience_revocations | auth_epoch           | bigint                   | t          |              | 0
 identities           | id                   | uuid                     | t          |              | 
 identities           | email_original       | text                     | t          |              | 
 identities           | email_canonical      | text                     | t          | s            | translate(email_original, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'::text, 'abcdefghijklmnopqrstuvwxyz'::text)
 identities           | status               | text                     | t          |              | 'pending'::text
 identities           | email_verified_at    | timestamp with time zone | f          |              | 
 identities           | auth_epoch           | bigint                   | t          |              | 0
 identities           | credential_revision  | bigint                   | t          |              | 0
 identities           | created_at           | timestamp with time zone | t          |              | clock_timestamp()
 identity_credentials | identity_id          | uuid                     | t          |              | 
 identity_credentials | password_hash        | text                     | t          |              | 
 identity_credentials | changed_at           | timestamp with time zone | t          |              | 
 sessions             | session_id           | uuid                     | t          |              | 
 sessions             | identity_id          | uuid                     | t          |              | 
 sessions             | audience             | text                     | t          |              | 
 sessions             | token_hash           | bytea                    | t          |              | 
 sessions             | identity_epoch       | bigint                   | t          |              | 
 sessions             | audience_epoch       | bigint                   | t          |              | 
 sessions             | authentication_level | text                     | t          |              | 
 sessions             | csrf_key_id          | text                     | t          |              | 
 sessions             | csrf_generation      | bigint                   | t          |              | 1
 sessions             | csrf_salt            | bytea                    | t          |              | 
 sessions             | created_at           | timestamp with time zone | t          |              | 
 sessions             | last_activity_at     | timestamp with time zone | t          |              | 
 sessions             | idle_expires_at      | timestamp with time zone | t          |              | 
 sessions             | absolute_expires_at  | timestamp with time zone | t          |              | 
 sessions             | revoked_at           | timestamp with time zone | f          |…2754 tokens truncated…        |         |     ELSE NULL::interval                                                                                                                                                                                                                                                                                                                                                 +
                      |                                             |         | END)))
 sessions             | ck_sessions_platform_mfa                    | c       | CHECK (((audience <> 'platform'::text) OR (authentication_level = 'mfa'::text)))
 sessions             | ck_sessions_required_times_finite           | c       | CHECK ((isfinite(created_at) AND isfinite(last_activity_at) AND isfinite(idle_expires_at) AND isfinite(absolute_expires_at)))
 sessions             | ck_sessions_revoked_at_finite               | c       | CHECK (((revoked_at IS NULL) OR isfinite(revoked_at)))
 sessions             | ck_sessions_time_order                      | c       | CHECK (((created_at <= last_activity_at) AND (last_activity_at < idle_expires_at) AND (idle_expires_at <= absolute_expires_at)))
 sessions             | ck_sessions_token_hash_length               | c       | CHECK ((octet_length(token_hash) = 32))
 sessions             | ck_sessions_uuid_v4                         | c       | CHECK (((substr((session_id)::text, 15, 1) = '4'::text) AND (substr((session_id)::text, 20, 1) = ANY (ARRAY['8'::text, '9'::text, 'a'::text, 'b'::text]))))
 sessions             | fk_sessions_audience                        | f       | FOREIGN KEY (identity_id, audience) REFERENCES identity.audience_revocations(identity_id, audience) ON UPDATE RESTRICT ON DELETE RESTRICT
 sessions             | fk_sessions_identity                        | f       | FOREIGN KEY (identity_id) REFERENCES identity.identities(id) ON UPDATE RESTRICT ON DELETE RESTRICT
 sessions             | pk_sessions                                 | p       | PRIMARY KEY (session_id)
 sessions             | sessions_absolute_expires_at_not_null       | n       | NOT NULL absolute_expires_at
 sessions             | sessions_audience_epoch_not_null            | n       | NOT NULL audience_epoch
 sessions             | sessions_audience_not_null                  | n       | NOT NULL audience
 sessions             | sessions_authentication_level_not_null      | n       | NOT NULL authentication_level
 sessions             | sessions_created_at_not_null                | n       | NOT NULL created_at
 sessions             | sessions_csrf_generation_not_null           | n       | NOT NULL csrf_generation
 sessions             | sessions_csrf_key_id_not_null               | n       | NOT NULL csrf_key_id
 sessions             | sessions_csrf_salt_not_null                 | n       | NOT NULL csrf_salt
 sessions             | sessions_identity_epoch_not_null            | n       | NOT NULL identity_epoch
 sessions             | sessions_identity_id_not_null               | n       | NOT NULL identity_id
 sessions             | sessions_idle_expires_at_not_null           | n       | NOT NULL idle_expires_at
 sessions             | sessions_last_activity_at_not_null          | n       | NOT NULL last_activity_at
 sessions             | sessions_session_id_not_null                | n       | NOT NULL session_id
 sessions             | sessions_token_hash_not_null                | n       | NOT NULL token_hash
 sessions             | uq_sessions_token_hash                      | u       | UNIQUE (token_hash)
(68 rows)

ROLLBACK

```

## 103 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/control/fixtures/030_integrity.sql'
```

```text
BEGIN
SET
SET
DO
CREATE TABLE
CREATE FUNCTION
INSERT 0 1
INSERT 0 2
INSERT 0 1
INSERT 0 4
INSERT 0 1
DO
 expect_rejection 
------------------
 
(1 row)

 expect_rejection 
------------------
 
(1 row)

 expect_rejection 
------------------
 
(1 row)

 expect_rejection 
------------------
 
(1 row)

 expect_rejection 
------------------
 
(1 row)

 expect_rejection 
------------------
 
(1 row)

 expect_rejection 
------------------
 
(1 row)

 expect_rejection 
------------------
 
(1 row)

 expect_rejection 
------------------
 
(1 row)

 expect_rejection 
------------------
 
(1 row)

 expect_rejection 
------------------
 
(1 row)

 expect_rejection 
------------------
 
(1 row)

 expect_rejection 
------------------
 
(1 row)

DO
 expect_rejection 
------------------
 
(1 row)

 expect_rejection 
------------------
 
(1 row)

 expect_rejection 
------------------
 
(1 row)

 expect_rejection 
------------------
 
(1 row)

UPDATE 1
 expect_rejection 
------------------
 
(1 row)

 expect_rejection 
------------------
 
(1 row)

UPDATE 1
 expect_rejection 
------------------
 
(1 row)

DO
psql:/f/control/fixtures/030_integrity.sql:144: NOTICE:  F integrity corpus and guard checks passed
ROLLBACK

```

## 104 — exit 0

```text
docker --context default inspect tp-b2a-f-20261014-r01-pg --format '{{json .Id}}{{println}}{{json .Name}}{{println}}{{json .Config.Image}}{{println}}{{json .Config.Labels}}{{println}}{{json .State}}{{println}}{{json .HostConfig.NetworkMode}}{{println}}{{json .HostConfig.Privileged}}{{println}}{{json .HostConfig.PublishAllPorts}}{{println}}{{json .HostConfig.PortBindings}}{{println}}{{json .NetworkSettings.Networks}}{{println}}{{json .Mounts}}{{println}}{{json .Image}}' > .local/b2a-f/f6b-container-fields.jsonl
```

```text

```

## 105 — exit 0

```text
docker --context default network inspect tp-b2a-f-20261014-r01-net --format '{{json .}}' > .local/b2a-f/f6b-network.json
```

```text

```

## 106 — exit 0

```text
docker --context default volume inspect tp-b2a-f-20261014-r01-data --format '{{json .}}' > .local/b2a-f/f6b-volume-raw.json
```

```text

```

## 107 — exit 0

```text
docker --context default image inspect postgres:18.6-bookworm@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c --format '{{json .Id}}{{println}}{{json .RepoDigests}}' > .local/b2a-f/f6b-image.jsonl
```

```text

```

## 108 — exit 0

```text
& ./tomopedidos-api/db/verification/f/control/f6/Convert-DockerCapture.ps1 -Fields .local/b2a-f/f6b-container-fields.jsonl -Volume .local/b2a-f/f6b-volume-raw.json -ContainerOut .local/b2a-f/f6b-container.json -VolumeOut .local/b2a-f/f6b-volume.json
& ./tomopedidos-api/db/verification/f/Assert-FDockerSnapshot.ps1 -ContainerJson .local/b2a-f/f6b-container.json -NetworkJson .local/b2a-f/f6b-network.json -VolumeJson .local/b2a-f/f6b-volume.json
$c=Get-Content .local/b2a-f/f6b-container.json -Raw|ConvertFrom-Json
$i=@(Get-Content .local/b2a-f/f6b-image.jsonl)
if(($i[0]|ConvertFrom-Json)-cne $c.Image -or -not ($i[1]|ConvertFrom-Json|Where-Object {$_ -ceq 'postgres@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c'})){throw 'Image content/digest mismatch'}
'PASS actual image digest'
```

```text
PASS twelve JSON values parsed and selectively serialized; no Docker invoked
PASS saved F Docker identity/ports/network/mount snapshot; refresh live evidence before each future operation. No Docker invoked.
PASS actual image digest

```

## 109 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=4 -v f_c=absent -v f_e=absent -f /f/control/f6/check_transition.sql'
```

```text
BEGIN
SET
SET
SET
DO
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## 110 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/staged/administration/b2a-auth-functions-v1.sql'
```

```text
BEGIN
SET
SET
SET
SET
DO
CREATE FUNCTION
REVOKE
ALTER FUNCTION
CREATE FUNCTION
REVOKE
ALTER FUNCTION
CREATE FUNCTION
REVOKE
ALTER FUNCTION
CREATE FUNCTION
REVOKE
ALTER FUNCTION
CREATE FUNCTION
REVOKE
ALTER FUNCTION
CREATE FUNCTION
REVOKE
ALTER FUNCTION
CREATE FUNCTION
REVOKE
ALTER FUNCTION
CREATE FUNCTION
REVOKE
ALTER FUNCTION
CREATE FUNCTION
REVOKE
ALTER FUNCTION
DO
COMMIT

```

## 111 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=4 -v f_c=c -v f_e=absent -f /f/control/f6/check_transition.sql'
```

```text
BEGIN
SET
SET
SET
DO
SET
DO
DO
psql:/f/staged/administration/b2a-assert-state.sql:199: NOTICE:  D metadata and effective privilege assertions passed: c
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## 112 — exit 0

```text
docker --context default inspect tp-b2a-f-20261014-r01-pg --format '{{json .Id}}{{println}}{{json .Name}}{{println}}{{json .Config.Image}}{{println}}{{json .Config.Labels}}{{println}}{{json .State}}{{println}}{{json .HostConfig.NetworkMode}}{{println}}{{json .HostConfig.Privileged}}{{println}}{{json .HostConfig.PublishAllPorts}}{{println}}{{json .HostConfig.PortBindings}}{{println}}{{json .NetworkSettings.Networks}}{{println}}{{json .Mounts}}{{println}}{{json .Image}}' > .local/b2a-f/f6b-container-fields.jsonl
```

```text

```

## 113 — exit 0

```text
docker --context default network inspect tp-b2a-f-20261014-r01-net --format '{{json .}}' > .local/b2a-f/f6b-network.json
```

```text

```

## 114 — exit 0

```text
docker --context default volume inspect tp-b2a-f-20261014-r01-data --format '{{json .}}' > .local/b2a-f/f6b-volume-raw.json
```

```text

```

## 115 — exit 0

```text
docker --context default image inspect postgres:18.6-bookworm@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c --format '{{json .Id}}{{println}}{{json .RepoDigests}}' > .local/b2a-f/f6b-image.jsonl
```

```text

```

## 116 — exit 0

```text
& ./tomopedidos-api/db/verification/f/control/f6/Convert-DockerCapture.ps1 -Fields .local/b2a-f/f6b-container-fields.jsonl -Volume .local/b2a-f/f6b-volume-raw.json -ContainerOut .local/b2a-f/f6b-container.json -VolumeOut .local/b2a-f/f6b-volume.json
& ./tomopedidos-api/db/verification/f/Assert-FDockerSnapshot.ps1 -ContainerJson .local/b2a-f/f6b-container.json -NetworkJson .local/b2a-f/f6b-network.json -VolumeJson .local/b2a-f/f6b-volume.json
$c=Get-Content .local/b2a-f/f6b-container.json -Raw|ConvertFrom-Json
$i=@(Get-Content .local/b2a-f/f6b-image.jsonl)
if(($i[0]|ConvertFrom-Json)-cne $c.Image -or -not ($i[1]|ConvertFrom-Json|Where-Object {$_ -ceq 'postgres@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c'})){throw 'Image content/digest mismatch'}
'PASS actual image digest'
```

```text
PASS twelve JSON values parsed and selectively serialized; no Docker invoked
PASS saved F Docker identity/ports/network/mount snapshot; refresh live evidence before each future operation. No Docker invoked.
PASS actual image digest

```

## 117 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=4 -v f_c=c -v f_e=absent -f /f/control/f6/check_transition.sql'
```

```text
BEGIN
SET
SET
SET
DO
SET
DO
psql:/f/staged/administration/b2a-assert-state.sql:199: NOTICE:  D metadata and effective privilege assertions passed: c
DO
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## 118 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/staged/administration/b2a-auth-grants-v1.sql'
```

```text
BEGIN
SET
SET
SET
DO
SET
psql:/f/staged/administration/b2a-assert-state.sql:199: NOTICE:  D metadata and effective privilege assertions passed: c
DO
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
SET
psql:/f/staged/administration/b2a-assert-state.sql:199: NOTICE:  D metadata and effective privilege assertions passed: executors
DO
COMMIT

```

## 119 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=4 -v f_c=executors -v f_e=absent -f /f/control/f6/check_transition.sql'
```

```text
BEGIN
SET
SET
SET
DO
SET
DO
psql:/f/staged/administration/b2a-assert-state.sql:199: NOTICE:  D metadata and effective privilege assertions passed: executors
DO
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## 120 — exit 0

```text
docker --context default inspect tp-b2a-f-20261014-r01-pg --format '{{json .Id}}{{println}}{{json .Name}}{{println}}{{json .Config.Image}}{{println}}{{json .Config.Labels}}{{println}}{{json .State}}{{println}}{{json .HostConfig.NetworkMode}}{{println}}{{json .HostConfig.Privileged}}{{println}}{{json .HostConfig.PublishAllPorts}}{{println}}{{json .HostConfig.PortBindings}}{{println}}{{json .NetworkSettings.Networks}}{{println}}{{json .Mounts}}{{println}}{{json .Image}}' > .local/b2a-f/f6b-container-fields.jsonl
```

```text

```

## 121 — exit 0

```text
docker --context default network inspect tp-b2a-f-20261014-r01-net --format '{{json .}}' > .local/b2a-f/f6b-network.json
```

```text

```

## 122 — exit 0

```text
docker --context default volume inspect tp-b2a-f-20261014-r01-data --format '{{json .}}' > .local/b2a-f/f6b-volume-raw.json
```

```text

```

## 123 — exit 0

```text
docker --context default image inspect postgres:18.6-bookworm@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c --format '{{json .Id}}{{println}}{{json .RepoDigests}}' > .local/b2a-f/f6b-image.jsonl
```

```text

```

## 124 — exit 0

```text
& ./tomopedidos-api/db/verification/f/control/f6/Convert-DockerCapture.ps1 -Fields .local/b2a-f/f6b-container-fields.jsonl -Volume .local/b2a-f/f6b-volume-raw.json -ContainerOut .local/b2a-f/f6b-container.json -VolumeOut .local/b2a-f/f6b-volume.json
& ./tomopedidos-api/db/verification/f/Assert-FDockerSnapshot.ps1 -ContainerJson .local/b2a-f/f6b-container.json -NetworkJson .local/b2a-f/f6b-network.json -VolumeJson .local/b2a-f/f6b-volume.json
$c=Get-Content .local/b2a-f/f6b-container.json -Raw|ConvertFrom-Json
$i=@(Get-Content .local/b2a-f/f6b-image.jsonl)
if(($i[0]|ConvertFrom-Json)-cne $c.Image -or -not ($i[1]|ConvertFrom-Json|Where-Object {$_ -ceq 'postgres@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c'})){throw 'Image content/digest mismatch'}
'PASS actual image digest'
```

```text
PASS twelve JSON values parsed and selectively serialized; no Docker invoked
PASS saved F Docker identity/ports/network/mount snapshot; refresh live evidence before each future operation. No Docker invoked.
PASS actual image digest

```

## 125 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=4 -v f_c=executors -v f_e=absent -f /f/control/f6/check_transition.sql'
```

```text
BEGIN
SET
SET
SET
DO
SET
DO
psql:/f/staged/administration/b2a-assert-state.sql:199: NOTICE:  D metadata and effective privilege assertions passed: executors
DO
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## 126 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/staged/administration/b2a-auth-enable-v1.sql'
```

```text
BEGIN
SET
SET
SET
DO
SET
DO
psql:/f/staged/administration/b2a-assert-state.sql:199: NOTICE:  D metadata and effective privilege assertions passed: executors
GRANT
GRANT
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
SET
psql:/f/staged/administration/b2a-assert-state.sql:199: NOTICE:  D metadata and effective privilege assertions passed: enabled
DO
COMMIT

```

## 127 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=4 -v f_c=enabled -v f_e=absent -f /f/control/f6/check_transition.sql'
```

```text
BEGIN
SET
SET
SET
DO
SET
DO
psql:/f/staged/administration/b2a-assert-state.sql:199: NOTICE:  D metadata and effective privilege assertions passed: enabled
DO
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## 128 — exit 0

```text
docker --context default inspect tp-b2a-f-20261014-r01-pg --format '{{json .Id}}{{println}}{{json .Name}}{{println}}{{json .Config.Image}}{{println}}{{json .Config.Labels}}{{println}}{{json .State}}{{println}}{{json .HostConfig.NetworkMode}}{{println}}{{json .HostConfig.Privileged}}{{println}}{{json .HostConfig.PublishAllPorts}}{{println}}{{json .HostConfig.PortBindings}}{{println}}{{json .NetworkSettings.Networks}}{{println}}{{json .Mounts}}{{println}}{{json .Image}}' > .local/b2a-f/f6b-container-fields.jsonl
```

```text

```

## 129 — exit 0

```text
docker --context default network inspect tp-b2a-f-20261014-r01-net --format '{{json .}}' > .local/b2a-f/f6b-network.json
```

```text

```

## 130 — exit 0

```text
docker --context default volume inspect tp-b2a-f-20261014-r01-data --format '{{json .}}' > .local/b2a-f/f6b-volume-raw.json
```

```text

```

## 131 — exit 0

```text
docker --context default image inspect postgres:18.6-bookworm@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c --format '{{json .Id}}{{println}}{{json .RepoDigests}}' > .local/b2a-f/f6b-image.jsonl
```

```text

```

## 132 — exit 0

```text
& ./tomopedidos-api/db/verification/f/control/f6/Convert-DockerCapture.ps1 -Fields .local/b2a-f/f6b-container-fields.jsonl -Volume .local/b2a-f/f6b-volume-raw.json -ContainerOut .local/b2a-f/f6b-container.json -VolumeOut .local/b2a-f/f6b-volume.json
& ./tomopedidos-api/db/verification/f/Assert-FDockerSnapshot.ps1 -ContainerJson .local/b2a-f/f6b-container.json -NetworkJson .local/b2a-f/f6b-network.json -VolumeJson .local/b2a-f/f6b-volume.json
$c=Get-Content .local/b2a-f/f6b-container.json -Raw|ConvertFrom-Json
$i=@(Get-Content .local/b2a-f/f6b-image.jsonl)
if(($i[0]|ConvertFrom-Json)-cne $c.Image -or -not ($i[1]|ConvertFrom-Json|Where-Object {$_ -ceq 'postgres@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c'})){throw 'Image content/digest mismatch'}
'PASS actual image digest'
```

```text
PASS twelve JSON values parsed and selectively serialized; no Docker invoked
PASS saved F Docker identity/ports/network/mount snapshot; refresh live evidence before each future operation. No Docker invoked.
PASS actual image digest

```

## 133 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=4 -v f_c=enabled -v f_e=absent -f /f/control/f6/check_transition.sql'
```

```text
BEGIN
SET
SET
SET
DO
SET
DO
DO
psql:/f/staged/administration/b2a-assert-state.sql:199: NOTICE:  D metadata and effective privilege assertions passed: enabled
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## 134 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/staged/administration/retention/b2a-session-cleanup-v1.sql'
```

```text
BEGIN
SET
SET
SET
DO
SET
DO
psql:/f/staged/administration/b2a-assert-state.sql:199: NOTICE:  D metadata and effective privilege assertions passed: enabled
DO
CREATE FUNCTION
REVOKE
ALTER FUNCTION
GRANT
GRANT
GRANT
GRANT
SET
psql:/f/staged/administration/retention/b2a-cleanup-assert.sql:146: NOTICE:  E metadata/privilege assertions passed: dormant
DO
psql:/f/staged/administration/b2a-assert-state.sql:199: NOTICE:  D metadata and effective privilege assertions passed: enabled
DO
COMMIT

```

## 135 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=4 -v f_c=enabled -v f_e=dormant -f /f/control/f6/check_transition.sql'
```

```text
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
DO
psql:/f/staged/administration/retention/b2a-cleanup-assert.sql:146: NOTICE:  E metadata/privilege assertions passed: dormant
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## 136 — exit 0

```text
docker --context default inspect tp-b2a-f-20261014-r01-pg --format '{{json .Id}}{{println}}{{json .Name}}{{println}}{{json .Config.Image}}{{println}}{{json .Config.Labels}}{{println}}{{json .State}}{{println}}{{json .HostConfig.NetworkMode}}{{println}}{{json .HostConfig.Privileged}}{{println}}{{json .HostConfig.PublishAllPorts}}{{println}}{{json .HostConfig.PortBindings}}{{println}}{{json .NetworkSettings.Networks}}{{println}}{{json .Mounts}}{{println}}{{json .Image}}' > .local/b2a-f/f6b-container-fields.jsonl
```

```text

```

## 137 — exit 0

```text
docker --context default network inspect tp-b2a-f-20261014-r01-net --format '{{json .}}' > .local/b2a-f/f6b-network.json
```

```text

```

## 138 — exit 0

```text
docker --context default volume inspect tp-b2a-f-20261014-r01-data --format '{{json .}}' > .local/b2a-f/f6b-volume-raw.json
```

```text

```

## 139 — exit 0

```text
docker --context default image inspect postgres:18.6-bookworm@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c --format '{{json .Id}}{{println}}{{json .RepoDigests}}' > .local/b2a-f/f6b-image.jsonl
```

```text

```

## 140 — exit 0

```text
& ./tomopedidos-api/db/verification/f/control/f6/Convert-DockerCapture.ps1 -Fields .local/b2a-f/f6b-container-fields.jsonl -Volume .local/b2a-f/f6b-volume-raw.json -ContainerOut .local/b2a-f/f6b-container.json -VolumeOut .local/b2a-f/f6b-volume.json
& ./tomopedidos-api/db/verification/f/Assert-FDockerSnapshot.ps1 -ContainerJson .local/b2a-f/f6b-container.json -NetworkJson .local/b2a-f/f6b-network.json -VolumeJson .local/b2a-f/f6b-volume.json
$c=Get-Content .local/b2a-f/f6b-container.json -Raw|ConvertFrom-Json
$i=@(Get-Content .local/b2a-f/f6b-image.jsonl)
if(($i[0]|ConvertFrom-Json)-cne $c.Image -or -not ($i[1]|ConvertFrom-Json|Where-Object {$_ -ceq 'postgres@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c'})){throw 'Image content/digest mismatch'}
'PASS actual image digest'
```

```text
PASS twelve JSON values parsed and selectively serialized; no Docker invoked
PASS saved F Docker identity/ports/network/mount snapshot; refresh live evidence before each future operation. No Docker invoked.
PASS actual image digest

```

## 141 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=4 -v f_c=enabled -v f_e=dormant -f /f/control/f6/check_transition.sql'
```

```text
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
psql:/f/staged/administration/retention/b2a-cleanup-assert.sql:146: NOTICE:  E metadata/privilege assertions passed: dormant
DO
         result         
------------------------
 F6 transition verified
(1 row)

ROLLBACK

```

## 142 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/staged/administration/retention/b2a-cleanup-enable-v1.sql'
```

```text
BEGIN
SET
DO
SET
psql:/f/staged/administration/b2a-assert-state.sql:199: NOTICE:  D metadata and effective privilege assertions passed: enabled
DO
SET
psql:/f/staged/administration/retention/b2a-cleanup-assert.sql:146: NOTICE:  E metadata/privilege assertions passed: dormant
DO
GRANT
GRANT
GRANT
SET
DO
psql:/f/staged/administration/retention/b2a-cleanup-assert.sql:146: NOTICE:  E metadata/privilege assertions passed: enabled
COMMIT

```

## 143 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=4 -v f_c=enabled -v f_e=enabled -f /f/control/f6/check_transition.sql'
```

```text
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



# F6-B closing authorization — 2026-10-14 — PASS

Only pending checks run. No Goose Down/Up, CDE install/removal/grant changes, F6-C or credential changes in this closing turn. Offline route validation before these calls found exactly one F-manifest entry per pending file, exact SHA256 and source/staged050 mapping; three serializer array roundtrips and F/F6 checkers PASS.

## Closing 1 — exit 0

```text
docker --context default inspect tp-b2a-f-20261014-r01-pg --format '{{json .Id}}{{println}}{{json .Name}}{{println}}{{json .Config.Image}}{{println}}{{json .Config.Labels}}{{println}}{{json .State}}{{println}}{{json .HostConfig.NetworkMode}}{{println}}{{json .HostConfig.Privileged}}{{println}}{{json .HostConfig.PublishAllPorts}}{{println}}{{json .HostConfig.PortBindings}}{{println}}{{json .NetworkSettings.Networks}}{{println}}{{json .Mounts}}{{println}}{{json .Image}}' > .local/b2a-f/f6b-container-fields.jsonl
```

```text

```

## Closing 2 — exit 0

```text
docker --context default network inspect tp-b2a-f-20261014-r01-net --format '{{json .}}' > .local/b2a-f/f6b-network.json
```

```text

```

## Closing 3 — exit 0

```text
docker --context default volume inspect tp-b2a-f-20261014-r01-data --format '{{json .}}' > .local/b2a-f/f6b-volume-raw.json
```

```text

```

## Closing 4 — exit 0

```text
docker --context default image inspect postgres:18.6-bookworm@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c --format '{{json .Id}}{{println}}{{json .RepoDigests}}' > .local/b2a-f/f6b-image.jsonl
```

```text

```

## Closing 5 — exit 0

```text
& ./tomopedidos-api/db/verification/f/control/f6/Convert-DockerCapture.ps1 -Fields .local/b2a-f/f6b-container-fields.jsonl -Volume .local/b2a-f/f6b-volume-raw.json -ContainerOut .local/b2a-f/f6b-container.json -VolumeOut .local/b2a-f/f6b-volume.json
& ./tomopedidos-api/db/verification/f/Assert-FDockerSnapshot.ps1 -ContainerJson .local/b2a-f/f6b-container.json -NetworkJson .local/b2a-f/f6b-network.json -VolumeJson .local/b2a-f/f6b-volume.json
$c=Get-Content .local/b2a-f/f6b-container.json -Raw|ConvertFrom-Json
$i=@(Get-Content .local/b2a-f/f6b-image.jsonl)
if(($i[0]|ConvertFrom-Json)-cne $c.Image -or -not ($i[1]|ConvertFrom-Json|Where-Object {$_ -ceq 'postgres@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c'})){throw 'Image content/digest mismatch'}
'PASS actual image digest'
```

```text
PASS twelve JSON values parsed and selectively serialized; no Docker invoked
PASS saved F Docker identity/ports/network/mount snapshot; refresh live evidence before each future operation. No Docker invoked.
PASS actual image digest

```

## Closing 6 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/control/000_identify.sql'
```

```text
BEGIN
DO
  system_identifier  |   current_database    |    current_setting    | current_setting | inet_server_addr | inet_server_port 
---------------------+-----------------------+-----------------------+-----------------+------------------+------------------
 7696590721605967915 | tp_b2a_f_20261014_r01 | tp-b2a-f-20261014-r01 | 180006          | 127.0.0.1        |             5432
(1 row)

ROLLBACK

```

## Closing 7 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=4 -v f_c=enabled -v f_e=enabled -f /f/control/f6/check_transition.sql'
```

```text
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

## Closing 8 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/control/f5/117_final_fault_state.sql'
```

```text
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

## Closing 9 — exit 0

```text
& ./.local/b2a-f/Invoke-F4Maintenance.ps1 -Mode Maintenance -Test Login
```

```text
BEGIN
DO
ROLLBACK

psql:/f/control/fixtures/070_real_login.sql:19: NOTICE:  F real login context passed: tomopedidos_session_maintenance

DockerExit=0

```

## Closing 10 — exit 0

```text
& ./.local/b2a-f/Invoke-F4Maintenance.ps1 -Mode Maintenance -Test Negatives
```

```text
BEGIN
SET
DO
ROLLBACK

psql:/f/control/fixtures/071_maintenance_negatives.sql:31: NOTICE:  F maintenance negatives passed: 12

DockerExit=0

```

## Closing 11 — exit 0

```text
& ./.local/b2a-f/Invoke-F4Maintenance.ps1 -Mode Maintenance -Test NormalFunctions
```

```text
BEGIN
DO
ROLLBACK

psql:/f/control/fixtures/073_real_maintenance.sql:12: NOTICE:  F real maintenance cleanup execution passed: empty batch

DockerExit=0

```

## Closing 12 — exit 0

```text
& ./.local/b2a-f/Invoke-F4CleanupDenied.ps1 -Mode Auth -Test Negatives
```

```text
BEGIN
DO
ROLLBACK

psql:/f/control/fixtures/074_cleanup_denied.sql:13: NOTICE:  F real caller cleanup denial passed: tomopedidos_auth_runtime

DockerExit=0

```

## Closing 13 — exit 0

```text
& ./.local/b2a-f/Invoke-F4CleanupDenied.ps1 -Mode Tenant -Test Negatives
```

```text
BEGIN
DO
ROLLBACK

psql:/f/control/fixtures/074_cleanup_denied.sql:13: NOTICE:  F real caller cleanup denial passed: tomopedidos_runtime

DockerExit=0

```

## Closing 14 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/control/fixtures/060_auth_primitives.sql'
```

```text
BEGIN
SET
SET
DO
INSERT 0 1
INSERT 0 2
INSERT 0 1
INSERT 0 2
SAVEPOINT
SET
DO
RESET
ROLLBACK
SAVEPOINT
SET
DO
RESET
DO
ROLLBACK
SAVEPOINT
SET
DO
RESET
ROLLBACK
SAVEPOINT
SET
DO
RESET
ROLLBACK
SAVEPOINT
SET
DO
RESET
ROLLBACK
SAVEPOINT
SET
DO
RESET
DO
ROLLBACK
SAVEPOINT
SET
DO
RESET
DO
ROLLBACK
SAVEPOINT
SET
DO
RESET
DO
ROLLBACK
SAVEPOINT
SET
DO
RESET
ROLLBACK
SAVEPOINT
SET
DO
RESET
ROLLBACK
SAVEPOINT
SET
DO
RESET
DO
ROLLBACK
DO
psql:/f/control/fixtures/060_auth_primitives.sql:172: NOTICE:  F nine primitive SQL paths passed on synthetic fixtures; no cryptographic proof
ROLLBACK

```

## Closing 15 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/control/fixtures/061_fail_closed.sql'
```

```text
BEGIN
SET
SET
DO
INSERT 0 1
INSERT 0 2
INSERT 0 1
INSERT 0 2
SAVEPOINT
UPDATE 1
SET
DO
RESET
ROLLBACK
SAVEPOINT
DELETE 1
SET
DO
RESET
ROLLBACK
SAVEPOINT
UPDATE 1
SET
DO
RESET
ROLLBACK
SAVEPOINT
SET
DO
RESET
ROLLBACK
SAVEPOINT
SET
DO
RESET
ROLLBACK
SAVEPOINT
UPDATE 1
INSERT 0 1
SET
DO
RESET
ROLLBACK
SAVEPOINT
UPDATE 1
INSERT 0 1
SET
DO
RESET
ROLLBACK
SAVEPOINT
UPDATE 1
SET
DO
RESET
ROLLBACK
SAVEPOINT
SET
DO
RESET
ROLLBACK
DO
psql:/f/control/fixtures/061_fail_closed.sql:135: NOTICE:  F fail-closed state/audience/digest/overflow/CAS checks passed
ROLLBACK

```

## Closing 16 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/staged/verification/050_b2a_retention_concurrency.sql'
```

```text
BEGIN
SET
SET
SET
SET
DO
SET
psql:/f/staged/administration/b2a-assert-state.sql:199: NOTICE:  D metadata and effective privilege assertions passed: enabled
DO
SET
DO
psql:/f/staged/administration/retention/b2a-cleanup-assert.sql:146: NOTICE:  E metadata/privilege assertions passed: enabled
DO
INSERT 0 1
INSERT 0 2
SELECT 1
INSERT 0 8
SAVEPOINT
SET
DO
RESET
DO
ROLLBACK
DO
SAVEPOINT
SET
DO
RESET
ROLLBACK
DO
psql:/f/staged/verification/050_b2a_retention_concurrency.sql:117: NOTICE:  E retention fixtures, batch bounds and rollback checks passed
ROLLBACK

```

## Closing 17 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/staged/verification/051_b2a_cleanup_failures.sql'
```

```text
BEGIN
SET
SET
DO
SET
psql:/f/staged/administration/retention/b2a-cleanup-assert.sql:146: NOTICE:  E metadata/privilege assertions passed: enabled
DO
DO
DO
INSERT 0 1
INSERT 0 2
INSERT 0 2
SET
DO
RESET
DO
psql:/f/staged/verification/051_b2a_cleanup_failures.sql:65: NOTICE:  E ACL, clock anomaly and atomic failure checks passed
ROLLBACK
BEGIN
SET
SET
DO
ROLLBACK

```

## Closing 18 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v e_stage=enabled -f /f/staged/verification/052_b2a_cleanup_metadata.sql'
```

```text
BEGIN
SET
DO
SET
psql:/f/staged/administration/b2a-assert-state.sql:199: NOTICE:  D metadata and effective privilege assertions passed: enabled
DO
SET
DO
psql:/f/staged/administration/retention/b2a-cleanup-assert.sql:146: NOTICE:  E metadata/privilege assertions passed: enabled
ROLLBACK

```

## Closing 19 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -v f_version=4 -v f_c=enabled -v f_e=enabled -f /f/control/f6/check_transition.sql'
```

```text
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

## Closing 20 — exit 0

```text
docker --context default exec tp-b2a-f-20261014-r01-pg sh -c 'PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/control/f5/117_final_fault_state.sql'
```

```text
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

Comprobación documental posterior: git diff --check devolvió exit1 por una línea vacía al final de docs/verification.md (línea3218), además de avisos LF/CRLF. No fue un fallo SQL ni altera los resultados de F6-B; no se repitieron pruebas ni se hicieron correcciones funcionales. Se conserva este resultado como observación editorial.
