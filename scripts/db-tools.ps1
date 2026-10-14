[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Install', 'Versions', 'GooseValidate', 'SqlcCompile', 'SqlcGenerate')]
    [string]$Action,
    [string]$GoExecutable = ''
)

$ErrorActionPreference = 'Stop'
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$apiDirectory = Join-Path $workspaceRoot 'tomopedidos-api'
$versions = Get-Content -Raw -LiteralPath (Join-Path $workspaceRoot 'tools/versions.json') | ConvertFrom-Json
$executableSuffix = if ($env:OS -eq 'Windows_NT') { '.exe' } else { '' }
$gooseDirectory = Join-Path $workspaceRoot ".tools/goose/$($versions.goose)"
$sqlcDirectory = Join-Path $workspaceRoot ".tools/sqlc/$($versions.sqlc)"
$gooseExecutable = Join-Path $gooseDirectory "goose$executableSuffix"
$sqlcExecutable = Join-Path $sqlcDirectory "sqlc$executableSuffix"

if ($Action -eq 'Install') {
    if (!$GoExecutable) {
        $goCommand = Get-Command go -ErrorAction SilentlyContinue
        if ($goCommand) { $GoExecutable = $goCommand.Source }
        elseif (Test-Path -LiteralPath 'C:\Program Files\Go\bin\go.exe') { $GoExecutable = 'C:\Program Files\Go\bin\go.exe' }
        else { throw 'Go is missing. Supply -GoExecutable; do not install a global toolchain.' }
    }
    $names = @('GOBIN', 'GOENV', 'GOTOOLCHAIN', 'GOCACHE', 'GOMODCACHE', 'GOTMPDIR', 'CGO_ENABLED')
    $previous = @{}
    foreach ($name in $names) { $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
    try {
        $env:GOENV = 'off'
        $env:GOTOOLCHAIN = 'local'
        $env:CGO_ENABLED = '0'
        $env:GOCACHE = Join-Path $workspaceRoot '.cache/go/build'
        $env:GOMODCACHE = Join-Path $workspaceRoot '.cache/go/mod'
        $env:GOTMPDIR = Join-Path $workspaceRoot '.cache/go/tmp'
        foreach ($directory in @($gooseDirectory, $sqlcDirectory, $env:GOCACHE, $env:GOMODCACHE, $env:GOTMPDIR)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
        $env:GOBIN = $gooseDirectory
        & $GoExecutable install "github.com/pressly/goose/v3/cmd/goose@$($versions.goose)"
        if ($LASTEXITCODE -ne 0) { throw 'Pinned Goose installation failed; no fallback registry/toolchain used.' }
        $env:GOBIN = $sqlcDirectory
        & $GoExecutable install "github.com/sqlc-dev/sqlc/cmd/sqlc@$($versions.sqlc)"
        if ($LASTEXITCODE -ne 0) { throw 'Pinned sqlc installation failed; no fallback registry/toolchain used.' }
    }
    finally {
        foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process') }
    }
    Write-Output 'Pinned tools installed locally; global PATH and API go.mod unchanged.'
    return
}

if (!(Test-Path -LiteralPath $gooseExecutable) -or !(Test-Path -LiteralPath $sqlcExecutable)) {
    throw 'Pinned tools are not installed. Run Install when official Go registries are reachable.'
}
Push-Location $apiDirectory
try {
    switch ($Action) {
        'Versions' {
            & $gooseExecutable -version
            if ($LASTEXITCODE -ne 0) { throw 'Goose version check failed.' }
            & $sqlcExecutable version
        }
        'GooseValidate' { & $gooseExecutable -dir db/migrations validate }
        { $_ -in @('SqlcCompile', 'SqlcGenerate') } {
            if (!(Get-ChildItem -LiteralPath db/schema -Filter '*.sql') -or !(Get-ChildItem -LiteralPath db/queries -Filter '*.sql')) {
                throw 'Schema/queries are empty; generation requires D2.1-B or later approval.'
            }
            $sqlcAction = if ($Action -eq 'SqlcCompile') { 'compile' } else { 'generate' }
            & $sqlcExecutable $sqlcAction -f sqlc.yaml
        }
    }
    if ($LASTEXITCODE -ne 0) { throw "Tool action $Action failed (exit $LASTEXITCODE)." }
}
finally { Pop-Location }
