# Offline only; no psql, Docker, Goose, isolationtester or network invocation.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'check_b2a_delivery_d.ps1')
$dbRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$retentionRoot = Join-Path $dbRoot 'administration/retention'
$manifestPath = Join-Path $dbRoot 'administration/manifests/b2a-retention-v1.yaml'
$manifest = [IO.File]::ReadAllText($manifestPath)
$sql = [IO.File]::ReadAllText((Join-Path $retentionRoot 'b2a-session-cleanup-v1.sql'))
$index = [IO.File]::ReadAllText((Join-Path $dbRoot 'migrations/00004_session_cleanup_index.sql'))
$bodyMatch = [regex]::Match($sql,'(?s)AS \$cleanup\$(.*?)\$cleanup\$;')
if (-not $bodyMatch.Success) { throw 'Missing complete E function body' }
$hasher = [Security.Cryptography.SHA256]::Create()
try { $hash = [BitConverter]::ToString($hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($bodyMatch.Groups[1].Value.Replace("`r`n","`n")))).Replace('-','') } finally { $hasher.Dispose() }
if (-not $manifest.Contains('source_sha256_lf: ' + $hash)) { throw 'E source hash differs from manifest' }
$assertions = [IO.File]::ReadAllText((Join-Path $retentionRoot 'b2a-cleanup-assert.sql'))
if (-not $assertions.Contains("'" + $hash + "'")) { throw 'E installer assertion source pin differs' }
if (-not $sql.Contains('CREATE FUNCTION identity.cleanup_sessions(p_batch_size integer DEFAULT 100)') -or
    -not $sql.Contains('RETURNS TABLE (examined integer, deleted integer, skipped integer, checked_at timestamptz)') -or
    -not $manifest.Contains('signature: "identity.cleanup_sessions(integer)"') -or
    -not $sql.Contains('OWNER TO tomopedidos_cleanup_executor;')) { throw 'E signature/default/return/owner mismatch' }
$body = $bodyMatch.Groups[1].Value
$deletes = [regex]::Matches($body,'(?im)^\s*DELETE FROM ([\w.]+)')
if ($deletes.Count -ne 1 -or $deletes[0].Groups[1].Value -cne 'identity.sessions') { throw 'E deletion scope differs' }
if ($body -match '(?im)^\s*(UPDATE|INSERT|TRUNCATE)\b' -or $body -match '\b(auth_epoch|token_hash|password_hash|csrf_salt)\b') { throw 'E unexpectedly mutates or reads non-cleanup data' }
$terminal = 'LEAST(idle_expires_at, absolute_expires_at, revoked_at, expired_at)'
if (-not $index.Contains($terminal) -or -not $body.Replace('s.','').Contains($terminal)) { throw 'Index/discovery terminal expression differs' }
if ($index -match '(?i)\b(now|clock_timestamp|current_timestamp)\s*\(' -or -not $index.Contains('-- +goose Up') -or -not $index.Contains('-- +goose Down')) { throw 'Index is time-dependent or lacks Up/Down' }
if ([regex]::Matches($body,"INTERVAL '2592000 seconds'").Count -ne 3 -or -not $body.Contains('p_batch_size NOT BETWEEN 1 AND 100')) { throw 'Retention/batch bounds differ' }
$identityLock = $body.IndexOf('SELECT i.id FROM identity.identities')
$audienceLock = $body.IndexOf('SELECT a.identity_id, a.audience FROM identity.audience_revocations')
$sessionLock = $body.IndexOf('SELECT s.session_id, s.identity_id, s.audience, s.created_at')
if ($identityLock -lt 0 -or $audienceLock -le $identityLock -or $sessionLock -le $audienceLock -or
    -not $body.Contains('ORDER BY i.id FOR SHARE') -or
    -not $body.Contains('ORDER BY a.identity_id, a.audience COLLATE "C" FOR SHARE') -or
    -not $body.Contains('ORDER BY s.session_id FOR UPDATE')) { throw 'Global lock phases differ' }
$pins = [regex]::Matches($manifest,'(?m)^  - file: ([^\r\n]+)\r?\n    sha256: ([A-F0-9]{64})\r?$')
if ($pins.Count -lt 14) { throw 'Incomplete E dependency inventory' }
foreach ($pin in $pins) {
    $path = [IO.Path]::GetFullPath((Join-Path (Split-Path $manifestPath) $pin.Groups[1].Value))
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $pin.Groups[2].Value) { throw ('E pinned file differs: '+$pin.Groups[1].Value) }
    if ($path.EndsWith('.sql')) {
        $text = [IO.File]::ReadAllText($path)
        foreach ($include in [regex]::Matches($text,'(?m)^\\ir ([^\r\n]+)\r?$')) {
            if (-not [IO.File]::Exists([IO.Path]::GetFullPath((Join-Path (Split-Path $path) $include.Groups[1].Value)))) { throw 'Missing E include dependency' }
        }
    }
}
$enable = [IO.File]::ReadAllText((Join-Path $retentionRoot 'b2a-cleanup-enable-v1.sql'))
if ([regex]::Matches($enable,'(?m)^GRANT EXECUTE ON FUNCTION identity.cleanup_sessions\(integer\) TO tomopedidos_session_maintenance;\r?$').Count -ne 1 -or
    $enable -match '(?m)^GRANT .+ TO (PUBLIC|tomopedidos_auth_runtime|tomopedidos_runtime)') { throw 'E caller grants differ' }
$spec = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'isolation/b2a_cleanup.spec'))
$steps = @([regex]::Matches($spec,'(?m)^step "([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
$permutations = [regex]::Matches($spec,'(?m)^permutation ([^\r\n]+)')
if ($permutations.Count -ne 12 -or @($steps | Select-Object -Unique).Count -ne $steps.Count) { throw 'Concurrency inventory differs' }
foreach ($permutation in $permutations) {
    foreach ($step in [regex]::Matches($permutation.Groups[1].Value,'"([^"]+)"')) {
        if ($step.Groups[1].Value -notin $steps) { throw 'Undefined isolation permutation step' }
    }
}
Write-Output 'PASS E offline: A-D unchanged; signature/source/pins/includes; session-only DELETE; 30d/1-100 bounds; matching index; lock phases; maintenance-only enable; 12 prepared concurrency permutations. No SQL executed.'
