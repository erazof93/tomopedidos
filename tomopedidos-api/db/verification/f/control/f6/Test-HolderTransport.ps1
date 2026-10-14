# Offline fake child: actual stdin-pipe and named-pipe synchronization, no sleeps.
$ErrorActionPreference='Stop'
$si=New-Object Diagnostics.ProcessStartInfo
$si.FileName=(Join-Path $PSHOME 'powershell.exe')
$si.Arguments='-NoProfile -File "'+(Join-Path $PSScriptRoot 'Start-F6Holder.ps1')+'" -Offline'
$si.UseShellExecute=$false;$si.CreateNoWindow=$true
$si.RedirectStandardOutput=$true;$si.RedirectStandardError=$true
$p=New-Object Diagnostics.Process;$p.StartInfo=$si;[void]$p.Start()
$err=$p.StandardError.ReadToEndAsync();$lines=New-Object 'Collections.Generic.List[string]'
while($null-ne($line=$p.StandardOutput.ReadLine())){
 $lines.Add($line)
 if($line-ceq 'F6_HOLDER_CONTROL_READY'){break}
}
if($p.HasExited -or -not $lines.Contains('F6_HOLDER_LOCK_ACQUIRED')){throw 'Offline holder did not retain stdin through barrier'}
& (Join-Path $PSScriptRoot 'Release-F6Holder.ps1')
$tail=$p.StandardOutput.ReadToEnd();$p.WaitForExit()
if($p.ExitCode-ne 0 -or -not $tail.Contains('F6_HOLDER_RELEASED_ROLLBACK_CONFIRMED') -or $err.Result){throw 'Offline holder release failed'}
'PASS offline: stdin retained, acquired barrier, named-pipe release, rollback marker, child exit0; no Docker/PostgreSQL'
