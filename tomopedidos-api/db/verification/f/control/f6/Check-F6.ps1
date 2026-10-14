# Offline only: includes, pins, command preview safety and SQL lexical checks.
$ErrorActionPreference='Stop'
$m=Get-Content (Join-Path $PSScriptRoot 'manifest.json') -Raw|ConvertFrom-Json
if($m.database-cne 'tp_b2a_f_20261014_r01' -or $m.system_identifier-cne '7696590721605967915' -or $m.execution_authorized){throw 'Unapproved F6 target/scope'}
foreach($pin in $m.files){if((Get-FileHash (Join-Path $PSScriptRoot $pin.file)).Hash-cne $pin.sha256){throw ('F6 pin drift: '+$pin.file)}}
$f=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
foreach($sql in Get-ChildItem $PSScriptRoot -Filter '*.sql'){
 $s=[IO.File]::ReadAllText($sql.FullName)
 if(-not $s.Contains('\ir /f/control/001_preflight.sql') -or $s.Contains('tomopedidos_local') -or $s -match '(?i)\b(terminate_backend|DROP OWNED|REASSIGN OWNED)\b'){throw 'F6 SQL safety gate missing'}
 if($s-match '(?i)\b(BETWEEN|THEN|ELSE|WHEN|BY)\d'){throw 'F6 malformed SQL numeric token'}
 foreach($inc in [regex]::Matches($s,'(?m)^\\ir (/f/[^\r\n]+)')){$p=Join-Path $f $inc.Groups[1].Value.Substring(3);if(-not(Test-Path -LiteralPath $p)){throw ('Missing include: '+$p)}}
}
foreach($ps in Get-ChildItem $PSScriptRoot -Filter '*.ps1'){$t=$null;$e=$null;[Management.Automation.Language.Parser]::ParseFile($ps.FullName,[ref]$t,[ref]$e)|Out-Null;if($e.Count){throw 'F6 PowerShell syntax error'}}
$preview=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Print-F6Commands.ps1'))
if($preview-match '(?m)^\s*&\s+(docker|goose|psql)' -or -not$preview.Contains('-table migration_meta.goose_db_version') -or $preview.Contains('--rm ')){throw 'F6 preview executes/misroutes/deletes'}
Write-Output 'PASS F6 offline pins/includes/target/PS syntax/preview; SQL parse and PostgreSQL tests NOT executed'
