# Reads SAVED inspection JSON only; never calls Docker or a database.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ContainerJson,
      [Parameter(Mandatory=$true)][string]$NetworkJson,
      [Parameter(Mandatory=$true)][string]$VolumeJson)
$ErrorActionPreference='Stop'
$target=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'target.json') -Raw | ConvertFrom-Json
$containers=@(Get-Content -LiteralPath $ContainerJson -Raw | ConvertFrom-Json)
$networks=@(Get-Content -LiteralPath $NetworkJson -Raw | ConvertFrom-Json)
$volumes=@(Get-Content -LiteralPath $VolumeJson -Raw | ConvertFrom-Json)
if ($containers.Count-ne 1 -or $networks.Count-ne 1 -or $volumes.Count-ne 1) { throw 'Require exactly one saved F container/network/volume' }
$c=$containers[0]; $n=$networks[0]; $v=$volumes[0]
if ($c.Name -cne ('/'+$target.container) -or $c.Config.Image -cne $target.postgres_image -or
    $c.Config.Labels.'com.docker.compose.project' -cne $target.compose_project -or
    $c.Config.Labels.'com.docker.compose.service' -cne 'postgres' -or
    $c.Config.Labels.'pe.tomopedidos.f.run' -cne $target.run_id -or
    $c.Config.Labels.'pe.tomopedidos.f.disposable' -cne 'true' -or -not $c.State.Running -or
    $c.HostConfig.NetworkMode -eq 'host' -or $c.HostConfig.Privileged -or $c.HostConfig.PublishAllPorts) { throw 'Wrong/non-isolated F container' }
if (@($c.HostConfig.PortBindings.PSObject.Properties).Count -ne 0 -or
    @($c.NetworkSettings.Networks.PSObject.Properties.Name).Count-ne 1 -or
    @($c.NetworkSettings.Networks.PSObject.Properties.Name)[0] -cne $target.network) { throw 'Ports/extra network not allowed' }
if ($n.Name -cne $target.network -or -not $n.Internal -or $n.Labels.'com.docker.compose.project' -cne $target.compose_project -or
    $v.Name -cne $target.volume -or $v.Driver -cne 'local' -or $v.Labels.'com.docker.compose.project' -cne $target.compose_project -or
    $v.OptionsCount -ne 0) { throw 'Wrong/internal network or volume' }
if ($c.NetworkSettings.Networks.($target.network).NetworkID -cne $n.Id -or
    -not $n.Containers.PSObject.Properties[$c.Id]) { throw 'Container/network snapshot linkage differs' }
foreach ($peer in $n.Containers.PSObject.Properties) {
    if (-not $peer.Value.Name.StartsWith($target.run_id+'-',[StringComparison]::Ordinal)) { throw 'Foreign container attached to F network' }
}
$mounts=@($c.Mounts)
if ($mounts.Count-ne 3) { throw 'Unexpected F mounts' }
foreach ($m in $mounts) {
    if ($m.Type-eq 'volume') {
        if ($m.Name-cne $target.volume -or $m.Destination-cne '/var/lib/postgresql') { throw 'Wrong/shared PG volume' }
    } elseif ($m.Type-eq 'bind') {
        $sub=if ($m.Destination-eq '/f/staged') {'staged'} elseif ($m.Destination-eq '/f/control') {'control'} else {throw 'Unexpected bind target'}
        $expected=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot $sub)).Replace('\','/').ToLowerInvariant()
        $actual=$m.Source.Replace('\','/').ToLowerInvariant()
        # Docker Desktop may report /run/desktop/mnt/host/d/... rather than D:/...
        $desktop='/run/desktop/mnt/host/'+$expected.Substring(0,1)+$expected.Substring(2)
        $wsl='/host_mnt/'+$expected.Substring(0,1)+$expected.Substring(2)
        if ($m.RW -or $actual -notin @($expected,$desktop,$wsl)) { throw 'Writable or external bind source' }
    } else { throw 'Unexpected mount type' }
}
Write-Output 'PASS saved F Docker identity/ports/network/mount snapshot; refresh live evidence before each future operation. No Docker invoked.'
