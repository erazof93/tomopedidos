# Synthetic offline security tests only. Does not inspect or create any real resource.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$t=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'target.json') -Raw | ConvertFrom-Json
$testRoot=Join-Path $PSScriptRoot 'synthetic-snapshots'
[IO.Directory]::CreateDirectory($testRoot)|Out-Null
$containerId='a'*64; $networkId='b'*64
$c=[pscustomobject]@{
    Id=$containerId; Name='/'+$t.container; State=@{Running=$true}
    Config=@{Image=$t.postgres_image;Labels=@{'com.docker.compose.project'=$t.compose_project;'com.docker.compose.service'='postgres';'pe.tomopedidos.f.run'=$t.run_id;'pe.tomopedidos.f.disposable'='true'}}
    HostConfig=@{PortBindings=@{};NetworkMode=$t.network;Privileged=$false;PublishAllPorts=$false}
    NetworkSettings=@{Networks=@{($t.network)=@{NetworkID=$networkId}}}
    Mounts=@(@{Type='volume';Name=$t.volume;Destination='/var/lib/postgresql';RW=$true},
        @{Type='bind';Source=(Join-Path $PSScriptRoot 'staged');Destination='/f/staged';RW=$false},
        @{Type='bind';Source=(Join-Path $PSScriptRoot 'control');Destination='/f/control';RW=$false})
}
$n=[pscustomobject]@{Id=$networkId;Name=$t.network;Internal=$true;Labels=@{'com.docker.compose.project'=$t.compose_project};Containers=@{($containerId)=@{Name=$t.container}}}
$v=[pscustomobject]@{Name=$t.volume;Driver='local';OptionsCount=0;Labels=@{'com.docker.compose.project'=$t.compose_project}}
$paths=@('container.json','network.json','volume.json')|ForEach-Object {Join-Path $testRoot $_}
function Save-Synthetic($objects) {
    for ($i=0;$i-lt 3;$i++) { [IO.File]::WriteAllText($paths[$i],($objects[$i]|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false)) }
}
$objects=@($c,$n,$v)
Save-Synthetic $objects
& (Join-Path $PSScriptRoot 'Assert-FDockerSnapshot.ps1') -ContainerJson $paths[0] -NetworkJson $paths[1] -VolumeJson $paths[2] | Out-Null
$baseline=@($objects|ForEach-Object {$_|ConvertTo-Json -Depth 12})
$passed=0
foreach ($case in @('principal_project','shared_volume','published_port','external_network','writable_bind','foreign_peer','wrong_image','network_id')) {
    $objects=@($baseline|ForEach-Object {$_|ConvertFrom-Json})
    switch ($case) {
        'principal_project' {$objects[0].Config.Labels.'com.docker.compose.project'='tomopedidos-local'}
        'shared_volume' {$objects[0].Mounts[0].Name='tomopedidos-local_postgres_data'}
        'published_port' {$objects[0].HostConfig.PortBindings=[pscustomobject]@{'5432/tcp'=@(@{HostIp='127.0.0.1';HostPort='55432'})}}
        'external_network' {$objects[1].Internal=$false}
        'writable_bind' {$objects[0].Mounts[1].RW=$true}
        'foreign_peer' {$objects[1].Containers | Add-Member -NotePropertyName ('c'*64) -NotePropertyValue @{Name='foreign-project-pg'}}
        'wrong_image' {$objects[0].Config.Image='postgres:latest'}
        'network_id' {$objects[0].NetworkSettings.Networks.($t.network).NetworkID='d'*64}
    }
    Save-Synthetic $objects
    $rejected=$false
    try { & (Join-Path $PSScriptRoot 'Assert-FDockerSnapshot.ps1') -ContainerJson $paths[0] -NetworkJson $paths[1] -VolumeJson $paths[2] | Out-Null }
    catch {$rejected=$true}
    if (-not $rejected) {throw ('Synthetic unsafe F destination accepted: '+$case)}
    $passed++
}
Save-Synthetic @($c,$n,$v)
Write-Output ('PASS synthetic offline F snapshot guard: 1 positive + '+$passed+' unsafe snapshots rejected. No real Docker/PostgreSQL evidence.')
