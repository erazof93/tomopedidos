# Offline D verifier. Restricted line-oriented manifest format; no SQL execution.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'check_b2a_contracts.ps1')
$dbRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$adminRoot = Join-Path $dbRoot 'administration'
$cManifest = [IO.File]::ReadAllText((Join-Path $adminRoot 'manifests/b2a-auth-v1.yaml'))
$cSql = [IO.File]::ReadAllText((Join-Path $adminRoot 'b2a-auth-functions-v1.sql'))
$grants = [IO.File]::ReadAllText((Join-Path $adminRoot 'b2a-auth-grants-v1.sql'))
$enable = [IO.File]::ReadAllText((Join-Path $adminRoot 'b2a-auth-enable-v1.sql'))
$assertions = [IO.File]::ReadAllText((Join-Path $adminRoot 'b2a-assert-state.sql'))
$expected = @{}
$plan = ($cManifest -split '(?m)^executor_permission_plan:\r?\n')[1]
if (-not $plan) { throw 'Missing C permission plan' }
$sessionSql = [IO.File]::ReadAllText((Join-Path $dbRoot 'migrations/00002_audience_sessions.sql'))
$sessionBlock = [regex]::Match($sessionSql, '(?s)CREATE TABLE identity.sessions \((.*?)CONSTRAINT').Groups[1].Value
$sessionColumns = @([regex]::Matches($sessionBlock, '(?m)^    (\w+) (?:uuid|text|bytea|bigint|timestamptz)\b') | ForEach-Object { $_.Groups[1].Value })
if ($sessionColumns.Count -ne 16) { throw 'Unexpected sessions shape' }
foreach ($role in @('tomopedidos_auth_executor','tomopedidos_auth_revoke_executor')) {
    $roleBlock = [regex]::Match($plan, '(?ms)^  ' + $role + ':\r?\n(.*?)(?=^  [a-z_]+:|\z)').Groups[1].Value
    $tables = [regex]::Matches($roleBlock, '(?ms)^      (identity\.\w+):\r?\n(.*?)(?=^      identity\.|\z)')
    foreach ($table in $tables) {
        $rights = [regex]::Matches($table.Groups[2].Value, '(?m)^        (select|insert|update): (\[[^\r\n]*\]|all_columns_used_by_typed_row)\r?$')
        foreach ($right in $rights) {
            $cols = if ($right.Groups[2].Value -eq 'all_columns_used_by_typed_row') { $sessionColumns } else { $right.Groups[2].Value.Trim('[',']').Split(',') | ForEach-Object { $_.Trim() } }
            $key = $role + '|' + $table.Groups[1].Value + '|' + $right.Groups[1].Value.ToUpperInvariant()
            $expected[$key] = @($cols | Sort-Object) -join ','
        }
    }
}
$actual = @{}
foreach ($grant in [regex]::Matches($grants, '(?m)^GRANT (SELECT|INSERT|UPDATE) \(([^)]+)\) ON TABLE (identity\.\w+) TO (\w+);\r?$')) {
    $key = $grant.Groups[4].Value + '|' + $grant.Groups[3].Value + '|' + $grant.Groups[1].Value
    if ($actual.ContainsKey($key)) { throw 'Duplicate grant' }
    $actual[$key] = @($grant.Groups[2].Value.Split(',') | Sort-Object) -join ','
    $row = "('" + $grant.Groups[4].Value + "','" + ($grant.Groups[3].Value -replace '^identity\.','') + "','" + $grant.Groups[1].Value + "',string_to_array('" + $grant.Groups[2].Value + "',','))"
    if (-not $assertions.Contains($row)) { throw 'Effective-right assertion matrix differs from GRANT' }
}
if ($expected.Count -ne 15 -or $actual.Count -ne $expected.Count) { throw 'Expected 15 exact column GRANT groups' }
foreach ($key in $expected.Keys) { if ($actual[$key] -cne $expected[$key]) { throw "C permission-plan mismatch: $key" } }
$normal = @([regex]::Matches($cSql, '(?m)^ALTER FUNCTION ([^\r\n]+) OWNER TO tomopedidos_auth_executor;\r?$') | ForEach-Object { $_.Groups[1].Value })
$enabled = @([regex]::Matches($enable, '(?m)^GRANT EXECUTE ON FUNCTION ([^\r\n]+) TO tomopedidos_auth_runtime;\r?$') | ForEach-Object { $_.Groups[1].Value })
if ($enabled.Count -ne 7 -or (($enabled | Sort-Object) -join '|') -cne (($normal | Sort-Object) -join '|')) { throw 'Enabled function inventory differs from seven normal C signatures' }
foreach ($privileged in @('identity.revoke_audience(bytea, text)','identity.revoke_global(bytea, text)')) {
    if ($enable.Contains('GRANT EXECUTE ON FUNCTION ' + $privileged)) { throw 'Privileged caller accidentally enabled' }
    if (-not $enable.Contains('REVOKE ALL ON FUNCTION ' + $privileged + ' FROM PUBLIC, tomopedidos_auth_runtime, tomopedidos_runtime, tomopedidos_migrator;')) { throw 'Missing privileged revoke' }
}
$manifestPath = Join-Path $adminRoot 'manifests/b2a-roles-v1.yaml'
$dManifest = [IO.File]::ReadAllText($manifestPath)
$pinned = [regex]::Matches($dManifest, '(?m)^  - file: ([^\r\n]+)\r?\n    sha256: ([A-F0-9]{64})\r?$')
if ($pinned.Count -lt 14) { throw 'Incomplete D dependency pins' }
foreach ($pin in $pinned) {
    $path = [IO.Path]::GetFullPath((Join-Path (Split-Path $manifestPath) $pin.Groups[1].Value))
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $pin.Groups[2].Value) { throw ('Pinned file changed: ' + $pin.Groups[1].Value) }
    if ($path.EndsWith('.sql')) {
        $text = [IO.File]::ReadAllText($path)
        foreach ($include in [regex]::Matches($text, '(?m)^\\ir ([^\r\n]+)\r?$')) {
            $target = [IO.Path]::GetFullPath((Join-Path (Split-Path $path) $include.Groups[1].Value))
            if (-not [IO.File]::Exists($target)) { throw 'Missing SQL include dependency' }
        }
    }
}
foreach ($path in @(Get-ChildItem -LiteralPath $adminRoot -Filter '*.sql' | Where-Object { $_.Name -ne 'b2a-auth-functions-v1.sql' })) {
    $text = [IO.File]::ReadAllText($path.FullName)
    if ($text -match '(?im)^\s*(CREATE (OR REPLACE )?FUNCTION|ALTER FUNCTION|ALTER DEFAULT PRIVILEGES|DROP OWNED|REASSIGN OWNED|TRUNCATE|DELETE FROM)\b') { throw 'D unexpectedly changes functional contracts/defaults/data' }
    if ($text -match '\+goose') { throw 'Administrative D file contains Goose directive' }
    if ($path.Name -notin @('b2a-assert-state.sql','b2a-role-preflight.sql') -and (-not $text.TrimEnd().EndsWith('COMMIT;') -or -not $text.Contains('\set ON_ERROR_STOP on'))) { throw 'Missing installer transaction/client guard' }
}
$negative = [IO.File]::ReadAllText((Join-Path $dbRoot 'verification/041_b2a_caller_negatives.sql'))
if ([regex]::Matches($negative, "(?m)^\s+'[^\r\n]+',?\r?$").Count -ne 33 -or -not $negative.TrimEnd().EndsWith('ROLLBACK;')) { throw 'Negative inventory/rollback mismatch' }
Write-Output 'PASS D: 15 column grant groups match C; 7 normal EXECUTE only; privileged revokes; pinned files/includes; 26 auth + 33 tenant cases prepared. No PostgreSQL verification.'
