# Invoke only after the operation's expected error, explicit rollback and recovery.
$ErrorActionPreference='Stop'
$client=New-Object IO.Pipes.NamedPipeClientStream('.','tp-b2a-f-20261014-r01-f6-holder-control',[IO.Pipes.PipeDirection]::Out)
$client.Connect(5000)
$writer=New-Object IO.StreamWriter($client)
$writer.WriteLine('RELEASE_AFTER_CONFIRMED_FAILURE');$writer.Flush()
$writer.Dispose();$client.Dispose()
'F6_HOLDER_RELEASE_REQUEST_SENT'
