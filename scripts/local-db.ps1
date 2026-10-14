[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Init', 'Config', 'Start', 'Stop', 'Restart', 'Status', 'Check')]
    [string]$Action
)

$ErrorActionPreference = 'Stop'
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$environmentFile = Join-Path $workspaceRoot '.env'

if ($Action -eq 'Init') {
    & node (Join-Path $PSScriptRoot 'init-local-db.cjs')
    if ($LASTEXITCODE -ne 0) { throw 'Local credential initialization failed.' }
    return
}

if (!(Get-Command docker -ErrorAction SilentlyContinue)) { throw 'Docker is not available in PATH.' }
if ($Action -eq 'Start') {
    & node (Join-Path $PSScriptRoot 'init-local-db.cjs')
    if ($LASTEXITCODE -ne 0) { throw 'Local configuration initialization failed; PostgreSQL not started.' }
}
if (!(Test-Path -LiteralPath $environmentFile -PathType Leaf)) { throw 'Run Init to prepare the root .env file.' }
# Compose automatically reads .env from the explicit project directory. Never print config values.
$composeArguments = @('--context', 'default', 'compose', '--project-name', 'tomopedidos-local', '--project-directory', $workspaceRoot, '-f', (Join-Path $workspaceRoot 'compose.yaml'))
if ($Action -ne 'Config') {
    $engineHost = & docker --context default context inspect default --format '{{.Endpoints.docker.Host}}'
    if ($LASTEXITCODE -ne 0 -or ($engineHost -join '').Trim() -notmatch '^(npipe://|unix://)') {
        throw 'The default Docker context must use a local named pipe or Unix socket; remote engines are refused.'
    }
}

switch ($Action) {
    'Config' { & docker @composeArguments config --quiet }
    'Start' {
        & docker @composeArguments up -d --wait --wait-timeout 120 postgres
    }
    'Stop' { & docker @composeArguments stop postgres }
    'Restart' { & docker @composeArguments restart postgres }
    'Status' { & docker @composeArguments ps --all }
    'Check' {
        & docker @composeArguments exec -T postgres sh -c 'pg_isready -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
        if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL readiness failed.' }
        # Read-only query; no schema or role modifications.
        & docker @composeArguments exec -T postgres sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -h 127.0.0.1 -X -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1;"'
    }
}
if ($LASTEXITCODE -ne 0) { throw "Docker action $Action failed (exit $LASTEXITCODE)." }
