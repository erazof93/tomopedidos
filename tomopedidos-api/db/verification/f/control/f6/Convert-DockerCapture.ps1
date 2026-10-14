# Offline serializer. Docker templates emit one JSON value per line, with no
# literal quote characters in their arguments. Never reads Config.Env.
param([Parameter(Mandatory=$true)][string]$Fields,
      [Parameter(Mandatory=$true)][string]$Volume,
      [Parameter(Mandatory=$true)][string]$ContainerOut,
      [Parameter(Mandatory=$true)][string]$VolumeOut)
$ErrorActionPreference='Stop'
$lines=@(Get-Content -LiteralPath $Fields)
if($lines.Count-ne 12){throw 'Require exactly twelve container JSON values'}
$x=New-Object 'object[]' 12
for($i=0;$i-lt 12;$i++){
 # An object property preserves []/[one]/[many], including nested arrays,
 # without PowerShell pipeline enumeration of the decoded value.
 $decoded=ConvertFrom-Json -InputObject ('{"value":'+$lines[$i]+'}') -ErrorAction Stop
 $x[$i]=$decoded.value
}
$c=[ordered]@{Id=$x[0];Name=$x[1];Config=@{Image=$x[2];Labels=$x[3]};State=$x[4];HostConfig=@{NetworkMode=$x[5];Privileged=$x[6];PublishAllPorts=$x[7];PortBindings=$x[8]};NetworkSettings=@{Networks=$x[9]};Mounts=$x[10];Image=$x[11]}
$v=Get-Content -LiteralPath $Volume -Raw|ConvertFrom-Json
$count=if($null-eq $v.Options){0}else{@($v.Options.PSObject.Properties).Count}
$v|Add-Member -NotePropertyName OptionsCount -NotePropertyValue $count
$c|ConvertTo-Json -Depth 30|Set-Content -LiteralPath $ContainerOut -Encoding UTF8
$v|ConvertTo-Json -Depth 30|Set-Content -LiteralPath $VolumeOut -Encoding UTF8
$roundtrip=Get-Content -LiteralPath $ContainerOut -Raw|ConvertFrom-Json
if(@($roundtrip.PSObject.Properties).Count-ne 8){throw 'Serialization root field mismatch'}
$actual=New-Object 'object[]' 12
$actual[0]=$roundtrip.Id;$actual[1]=$roundtrip.Name;$actual[2]=$roundtrip.Config.Image
$actual[3]=$roundtrip.Config.Labels;$actual[4]=$roundtrip.State;$actual[5]=$roundtrip.HostConfig.NetworkMode
$actual[6]=$roundtrip.HostConfig.Privileged;$actual[7]=$roundtrip.HostConfig.PublishAllPorts
$actual[8]=$roundtrip.HostConfig.PortBindings;$actual[9]=$roundtrip.NetworkSettings.Networks
$actual[10]=$roundtrip.Mounts;$actual[11]=$roundtrip.Image
for($i=0;$i-lt 12;$i++){
 $before=ConvertTo-Json -InputObject $x[$i] -Depth 30 -Compress
 $after=ConvertTo-Json -InputObject $actual[$i] -Depth 30 -Compress
 if($before-cne $after){throw ('Serialization roundtrip mismatch at value '+$i)}
}
Write-Output 'PASS twelve JSON values parsed and selectively serialized; no Docker invoked'
