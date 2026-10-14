# Offline checker for the deliberately restricted C manifest format, not a YAML parser.
# Reads local files only; never invokes psql, Goose, Docker or a database client.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$dbRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$manifestPath = Join-Path $dbRoot 'administration/manifests/b2a-auth-v1.yaml'
$manifest = [IO.File]::ReadAllText($manifestPath)
$sql = [IO.File]::ReadAllText((Join-Path $dbRoot 'administration/b2a-auth-functions-v1.sql'))
function Normalize-Sql([string]$value) {
    return ([regex]::Replace($value.Trim(), '\s+', ' ') -replace '\s*([(),])\s*', '$1')
}
function Hash-Text([string]$value) {
    $hasher = [Security.Cryptography.SHA256]::Create()
    try {
        return [BitConverter]::ToString($hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($value.Replace("`r`n", "`n")))).Replace('-', '')
    } finally { $hasher.Dispose() }
}
# Split entries at indentation-aware boundaries; preserve multiline entry fields.
$entries = [regex]::Matches($manifest, '(?ms)^  - signature: "([^"\r\n]+)"\r?\n(.*?)(?=^  - signature:|^# Derived|\z)')
$functions = [regex]::Matches($sql, '(?s)CREATE FUNCTION (identity\.\w+)\((.*?)\)\s*(RETURNS TABLE\s*\(.*?\))\s*LANGUAGE plpgsql(.*?)AS \$function\$(.*?)\$function\$;')
if ($entries.Count -ne 9 -or $functions.Count -ne 9) { throw 'Expected exactly nine manifest entries and SQL functions' }
$seen = @{}
foreach ($fn in $functions) {
    $params = @($fn.Groups[2].Value.Split(',') | ForEach-Object {
        $parts = $_.Trim() -split '\s+'
        if ($parts.Count -ne 2) { throw 'Unsupported parameter syntax' }
        [pscustomobject]@{ Name = $parts[0]; Type = $parts[1] }
    })
    $signature = $fn.Groups[1].Value + '(' + (($params | ForEach-Object { $_.Type }) -join ', ') + ')'
    if ($seen.ContainsKey($signature)) { throw 'Duplicate SQL signature' }
    $seen[$signature] = $true
    $matching = @($entries | Where-Object { (Normalize-Sql $_.Groups[1].Value) -ceq (Normalize-Sql $signature) })
    if ($matching.Count -ne 1) { throw "Manifest signature mismatch: $signature" }
    $entry = $matching[0].Groups[2].Value
    $names = [regex]::Match($entry, '(?m)^    input_names: \[([^\r\n]*)\]\r?$')
    $returns = [regex]::Match($entry, '(?m)^    returns_sql: "([^"\r\n]*)"\r?$')
    $hash = [regex]::Match($entry, '(?m)^    source_sha256_lf: ([A-F0-9]{64})\r?$')
    $owner = [regex]::Match($entry, '(?m)^    owner: (\w+)\r?$')
    if (-not $names.Success -or -not $returns.Success -or -not $hash.Success -or -not $owner.Success) { throw 'Unsupported or missing manifest field' }
    if (($params.Name -join ', ') -cne $names.Groups[1].Value) { throw "Parameter name/order mismatch: $signature" }
    if ((Normalize-Sql $fn.Groups[3].Value) -cne (Normalize-Sql $returns.Groups[1].Value)) { throw "Return name/type/order mismatch: $signature" }
    if ((Hash-Text $fn.Groups[5].Value) -cne $hash.Groups[1].Value) { throw "Body hash mismatch: $signature" }
    $alter = 'ALTER FUNCTION ' + $signature + ' OWNER TO ' + $owner.Groups[1].Value + ';'
    if (-not $sql.Contains($alter)) { throw "Owner mismatch: $signature" }
    if (-not $sql.Contains("'" + $hash.Groups[1].Value + "'")) { throw "Missing installer hash assertion: $signature" }
    Write-Output "PASS $signature : parameters, returns, body hash, owner"
}
# Verify exact bytes of C and all A/B dependencies from their pinned manifest hashes.
$artifactHash = [regex]::Match($manifest, '(?m)^  sha256: ([A-F0-9]{64})\r?$').Groups[1].Value
if ((Get-FileHash -LiteralPath (Join-Path $dbRoot 'administration/b2a-auth-functions-v1.sql') -Algorithm SHA256).Hash -cne $artifactHash) { throw 'C file hash mismatch' }
$deps = [regex]::Matches($manifest, '(?m)^    - file: ([^\r\n]+)\r?\n      sha256: ([A-F0-9]{64})\r?$')
if ($deps.Count -ne 3) { throw 'Expected three pinned migrations' }
foreach ($dep in $deps) {
    $path = Join-Path (Split-Path $manifestPath) $dep.Groups[1].Value
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $dep.Groups[2].Value) { throw 'Migration hash mismatch' }
}
Write-Output 'PASS 9/9 SQL/YAML contracts; A/B/C byte hashes unchanged. Offline only.'
