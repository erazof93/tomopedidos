# One Docker process only. Keep its stdin open until an explicit named-pipe barrier.
param([switch]$Offline)
$ErrorActionPreference='Stop'
$pipeName='tp-b2a-f-20261014-r01-f6-holder-control'
$server=New-Object IO.Pipes.NamedPipeServerStream($pipeName,[IO.Pipes.PipeDirection]::In)
$si=New-Object Diagnostics.ProcessStartInfo
$si.UseShellExecute=$false;$si.CreateNoWindow=$true
$si.RedirectStandardInput=$true;$si.RedirectStandardOutput=$true;$si.RedirectStandardError=$true
if($Offline){
 $fake="[Console]::WriteLine('F6_HOLDER_LOCK_ACQUIRED');`$v=[Console]::ReadLine();if(`$v -ne 'release'){exit 19};[Console]::WriteLine('ROLLBACK')"
 $si.FileName=(Join-Path $PSHOME 'powershell.exe')
 $si.Arguments='-NoProfile -EncodedCommand '+[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($fake))
}else{
 $si.FileName='docker'
 $inner='PGPASSWORD=$POSTGRES_PASSWORD exec psql -X -w -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5432 -d tp_b2a_f_20261014_r01 -U tomopedidos_bootstrap -v f_actor=tomopedidos_bootstrap -v f_system_id=7696590721605967915 -f /f/control/f6/holder.sql'
 $si.Arguments='--context default exec -i tp-b2a-f-20261014-r01-pg sh -c "'+$inner+'"'
}
$p=New-Object Diagnostics.Process;$p.StartInfo=$si
[void]$p.Start();$errors=$p.StandardError.ReadToEndAsync()
$acquired=$false
while($null-ne ($line=$p.StandardOutput.ReadLine())){
 [Console]::WriteLine($line)
 if($line.Contains('F6_HOLDER_LOCK_ACQUIRED')){$acquired=$true;break}
}
if(-not $acquired){$p.WaitForExit();[Console]::WriteLine($errors.Result);$server.Dispose();throw 'Holder failed before lock barrier'}
[Console]::WriteLine('F6_HOLDER_CONTROL_READY')
$server.WaitForConnection()
$reader=New-Object IO.StreamReader($server)
$message=$reader.ReadLine()
if($message-cne 'RELEASE_AFTER_CONFIRMED_FAILURE'){
 # No silent release: preserve this process/connection for explicit recovery.
 throw 'Holder control message rejected'
}
$p.StandardInput.WriteLine('release');$p.StandardInput.Flush();$p.StandardInput.Close()
$remaining=$p.StandardOutput.ReadToEnd();$p.WaitForExit()
[Console]::WriteLine($remaining);[Console]::WriteLine($errors.Result)
$reader.Dispose();$server.Dispose()
if($p.ExitCode-ne 0){throw ('Holder Docker exit '+$p.ExitCode)}
if(-not $remaining.Contains('ROLLBACK')){throw 'Holder explicit rollback not observed'}
[Console]::WriteLine('F6_HOLDER_RELEASED_ROLLBACK_CONFIRMED')
