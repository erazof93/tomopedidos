# OFFLINE inspection of F preparation. No container, database or tool invocation.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot '../check_b2a_delivery_e.ps1')
$t=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'target.json') -Raw | ConvertFrom-Json
if ($t.database -cne 'tp_b2a_f_20261014_r01' -or $t.container -cne 'tp-b2a-f-20261014-r01-pg' -or
    $t.compose_project -cne 'tp-b2a-f-20261014-r01' -or $t.docker_context -cne 'default' -or
    $t.execution_authorized -or $t.credential_provisioning_authorized -or $t.published_ports.Count -ne 0) { throw 'F target is no longer preparation-only reviewed target' }
$compose=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'compose.f.yaml'))
if ($compose -match '(?m)^\s*(ports:|external:|env_file:)' -or $compose.Contains('tomopedidos_local') -or
    -not $compose.Contains('internal: true') -or -not $compose.Contains($t.postgres_image) -or
    -not [IO.File]::Exists([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../docker/goose.Dockerfile')))) { throw 'F compose has fallback/shared path/missing build dependency' }
$m=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'stage-manifest.json') -Raw | ConvertFrom-Json
$dbRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$migrationCount=0
foreach ($entry in $m.files) {
    $source=Join-Path $dbRoot $entry.source
    $staged=Join-Path $PSScriptRoot $entry.staged
    if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -cne $entry.source_sha256 -or
        (Get-FileHash -LiteralPath $staged -Algorithm SHA256).Hash -cne $entry.staged_sha256) { throw 'F source/staging pin drift' }
    $text=[IO.File]::ReadAllText($staged)
    if ($text.Contains('tomopedidos_local')) { throw 'Staging still references main database' }
    if ($entry.migration_bytes_identical) {
        $migrationCount++
        if ($entry.source_sha256 -cne $entry.staged_sha256 -or -not $text.Contains('-- +goose Up') -or
            -not $text.Contains('-- +goose Down') -or $text.Contains('-- +goose NO TRANSACTION')) { throw 'Migration bytes/transaction convention changed' }
    } elseif ($entry.preflight_prefix -and -not $text.Contains('\ir /f/control/001_preflight.sql')) { throw 'Missing F entry preflight' }
    foreach ($inc in [regex]::Matches($text,'(?m)^\\ir ([^\r\n]+)\r?$')) {
        $include=$inc.Groups[1].Value
        $path=if ($include.StartsWith('/f/control/')) {Join-Path $PSScriptRoot ('control/'+$include.Substring(11))} else {Join-Path (Split-Path $staged) $include}
        if (-not [IO.File]::Exists([IO.Path]::GetFullPath($path))) { throw ('Missing staged include: '+$include) }
    }
}
if ($migrationCount-ne 4) { throw 'F must stage exactly migrations 00001-00004' }
$down=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'control/003_c_down.sql'))
if ([regex]::Matches($down,'(?m)^DROP FUNCTION identity\.').Count -ne 9 -or $down -match '(?i)\bCASCADE\b') { throw 'C Down scope differs' }
$commands=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Print-FCommands.ps1'))
if (-not $commands.Contains('-table migration_meta.goose_db_version') -or $commands -match '(?m)^\s*&\s+(docker|goose|psql)') { throw 'Command preview lacks qualified Goose table or executes tools' }
foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1') {
    $tokens=$null; $errors=$null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors) | Out-Null
    if ($errors.Count-ne 0) { throw ('F PowerShell syntax error: '+$file.Name) }
}
$pins=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'f-manifest.json') -Raw | ConvertFrom-Json
foreach ($pin in $pins.files) {
    $path=Join-Path $PSScriptRoot $pin.file
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $pin.sha256) { throw ('F control fixture/hash drift: '+$pin.file) }
}
Write-Output ('PASS F offline: '+$m.files.Count+' staged SQL/spec files; four byte-identical migrations; isolated target/no ports/fallback; includes and control pins; 9 exact C Down functions; qualified Goose commands; PS syntax. This checker performs no PostgreSQL/Docker execution; actual F1/F2 evidence is in docs/verification.md; later phases require separate approval.')
