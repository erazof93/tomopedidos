# OFFLINE preparation only. No Docker/psql/Goose/network/process calls.
[CmdletBinding()]
param([switch]$RefreshEnrollment)
$ErrorActionPreference='Stop'
$fRoot=[IO.Path]::GetFullPath($PSScriptRoot)
$dbRoot=[IO.Path]::GetFullPath((Join-Path $fRoot '../..'))
$target=Get-Content -LiteralPath (Join-Path $fRoot 'target.json') -Raw | ConvertFrom-Json
if ($target.database -cne 'tp_b2a_f_20261014_r01' -or $target.cluster_name -cne 'tp-b2a-f-20261014-r01') { throw 'Unreviewed F target' }
$utf8=[Text.UTF8Encoding]::new($false)
$previousManifest=if ([IO.File]::Exists((Join-Path $fRoot 'stage-manifest.json'))) {
    Get-Content -LiteralPath (Join-Path $fRoot 'stage-manifest.json') -Raw | ConvertFrom-Json
} else {$null}
if ($RefreshEnrollment -and [string]$target.system_identifier -notmatch '^[0-9]{19,20}$') { throw 'Enrollment refresh requires manually reviewed/pinned system identifier' }
function Get-BodyHashes([string]$text) {
    $result=@()
    foreach ($m in [regex]::Matches($text,'(?s)CREATE FUNCTION (\w+\.\w+)\(.*?\bAS (\$[a-z_]+\$)(.*?)\2;')) {
        $sha=[Security.Cryptography.SHA256]::Create()
        try { $hash=[BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($m.Groups[3].Value))).Replace('-','') } finally { $sha.Dispose() }
        $result+=($m.Groups[1].Value+'|'+$hash)
    }
    return $result
}
$sources=@(Get-ChildItem -LiteralPath $dbRoot -Recurse -File | Where-Object {
    ($_.Extension -eq '.sql' -or $_.Extension -eq '.spec') -and
    -not $_.FullName.StartsWith($fRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)
})
$records=@()
$diffLines=@('F target-only staging diff; originals remain untouched. No credentials/data captured.')
foreach ($source in $sources) {
    $relative=$source.FullName.Substring($dbRoot.Length+1).Replace('\','/')
    $dest=[IO.Path]::GetFullPath((Join-Path $fRoot ('staged/'+$relative)))
    if (-not $dest.StartsWith((Join-Path $fRoot 'staged')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Staging path escaped F' }
    $original=[IO.File]::ReadAllText($source.FullName)
    $adapted=$original.Replace('tomopedidos_local',$target.database)
    $before=@(Get-BodyHashes $original)
    $after=@(Get-BodyHashes $adapted)
    if (($before -join ';') -cne ($after -join ';')) { throw ('Destination adaptation changed function body: '+$relative) }
    $replacementCount=[regex]::Matches($original,'tomopedidos_local').Count
    $diffLines+=('FILE '+$relative+' : '+$replacementCount+' destination replacements')
    $lineNumber=0
    foreach ($line in ($original -split '\r?\n')) {
        $lineNumber++
        if ($line.Contains('tomopedidos_local')) {
            $diffLines+=('- source line '+$lineNumber+': '+$line)
            $diffLines+=('+ target line counterpart: '+$line.Replace('tomopedidos_local',$target.database))
        }
    }
    $isMigration=$relative.StartsWith('migrations/')
    $isInclude=$source.Name -in @('b2a-role-preflight.sql','b2a-assert-state.sql','b2a-cleanup-assert.sql')
    if ($isMigration) {
        if ($replacementCount -ne 0) { throw 'Migration requires target adaptation; report before changing' }
        $bytes=[IO.File]::ReadAllBytes($source.FullName)
    } elseif ($source.Extension -eq '.spec') {
        $sid=if ($null -eq $target.system_identifier) { '__F_SYSTEM_ID_PENDING__' } else { [string]$target.system_identifier }
        if ($sid -notmatch '^(?:[0-9]{19,20}|__F_SYSTEM_ID_PENDING__)$') { throw 'Invalid enrolled control identifier' }
        $guard="`n  DO `$f_target`$ BEGIN IF current_database()<>'"+$target.database+"' OR current_setting('cluster_name')<>'"+$target.cluster_name+"' OR current_setting('server_version_num')::integer<>180006 OR session_user<>'tomopedidos_bootstrap' OR (SELECT system_identifier::text FROM pg_control_system())<>'"+$sid+"' THEN RAISE EXCEPTION 'F isolation exact target failed'; END IF; END; `$f_target`$;`n"
        $adapted=[regex]::new('(?m)^setup\r?\n\{').Replace($adapted,[Text.RegularExpressions.MatchEvaluator]{ param($m) $m.Value+$guard },1)
        $diffLines+=('+ setup guard: '+$guard.Trim())
        $bytes=$utf8.GetBytes($adapted)
    } else {
        if (-not $isInclude) {
            $prefix="-- F target-only staged copy; original hash is in stage-manifest.json.`n\set ON_ERROR_STOP on`n\ir /f/control/001_preflight.sql`n"
            $adapted=$prefix+$adapted
            $diffLines+=('+ entry prefix: '+$prefix.Trim())
        }
        $bytes=$utf8.GetBytes($adapted)
    }
    [IO.Directory]::CreateDirectory((Split-Path $dest)) | Out-Null
    if ([IO.File]::Exists($dest)) {
        $sha=[Security.Cryptography.SHA256]::Create()
        try { $newHash=[BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-','') } finally { $sha.Dispose() }
        $oldHash=(Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash
        if ($oldHash -cne $newHash) {
            $previous=@($previousManifest.files | Where-Object {$_.source -ceq $relative})
            if (-not $RefreshEnrollment -or $source.Extension -ne '.spec' -or $previous.Count -ne 1 -or
                $previous[0].staged_sha256 -cne $oldHash -or
                $previous[0].source_sha256 -cne (Get-FileHash -LiteralPath $source.FullName -Algorithm SHA256).Hash) {
                throw ('Refuse to overwrite reviewed staging: '+$relative)
            }
            [IO.File]::WriteAllBytes($dest,$bytes)
        }
    } else { [IO.File]::WriteAllBytes($dest,$bytes) }
    $records += [pscustomobject]@{
        source=$relative; source_sha256=(Get-FileHash -LiteralPath $source.FullName -Algorithm SHA256).Hash
        staged=('staged/'+$relative); staged_sha256=(Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash
        target_replacements=$replacementCount; migration_bytes_identical=$isMigration
        function_bodies_identical=$true; function_body_hashes=$before
        preflight_prefix=(-not $isInclude -and -not $isMigration -and $source.Extension -ne '.spec')
    }
}
$manifest=[pscustomobject]@{run_id=$target.run_id; database=$target.database; generated_offline=$true; SQL_executed=$false; native_spec_blocked_until_system_id_enrolled=($null -eq $target.system_identifier); files=$records}
[IO.File]::WriteAllText((Join-Path $fRoot 'stage-manifest.json'),($manifest|ConvertTo-Json -Depth 8)+"`n",$utf8)
[IO.File]::WriteAllText((Join-Path $fRoot 'stage-target-diff.txt'),($diffLines -join "`n")+"`n",$utf8)
Write-Output ('F staged '+$records.Count+' SQL/spec files offline; four migrations unchanged; all function bodies unchanged. Native spec requires enrollment.')
