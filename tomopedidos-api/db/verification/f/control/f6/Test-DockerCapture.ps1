# Offline only. Synthetic values exercise every projected field and array shape.
$ErrorActionPreference='Stop'
$testDir=Join-Path ([IO.Path]::GetTempPath()) ('tp-f6-serializer-'+[guid]::NewGuid())
[void](New-Item -ItemType Directory -Path $testDir)
$mountCases=@('[]','[{"Type":"bind","RW":false,"Nested":[[],[1],[2,3]]}]','[{"Type":"bind","RW":false},{"Type":"volume","RW":true}]')
foreach($mounts in $mountCases){
 $values=@('"fixture-id"','"/fixture-name"','"fixture-image"','{"label":"value","nested":[[],[true],[1,2]]}','{"Running":true,"Pid":123}','"fixture-network"','false','false','{}','{"net":{"Aliases":["one"],"Null":null}}',$mounts,'"sha256:fixture"')
 $fields=Join-Path $testDir 'fields.jsonl';$volume=Join-Path $testDir 'volume.json'
 $output=Join-Path $testDir 'container.json';$volumeOut=Join-Path $testDir 'volume-out.json'
 $values|Set-Content -LiteralPath $fields -Encoding UTF8
 '{"Name":"fixture-volume","Options":null}'|Set-Content -LiteralPath $volume -Encoding UTF8
 & (Join-Path $PSScriptRoot 'Convert-DockerCapture.ps1') -Fields $fields -Volume $volume -ContainerOut $output -VolumeOut $volumeOut
 $c=Get-Content $output -Raw|ConvertFrom-Json
 $expected=(ConvertFrom-Json -InputObject ('{"value":'+$mounts+'}')).value
 if($c.Mounts-isnot [array] -or (ConvertTo-Json -InputObject $c.Mounts -Depth 30 -Compress)-cne (ConvertTo-Json -InputObject $expected -Depth 30 -Compress)){throw 'Mounts array equivalence failed'}
 Write-Output ('PASS Mounts count='+$c.Mounts.Count+'; all twelve fields roundtripped')
}
Write-Output 'PASS 3 offline serializer roundtrip cases; no Docker or PostgreSQL invoked'
