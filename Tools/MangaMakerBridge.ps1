param(
    [string]$PipeName,
    [string]$ManifestPath,
    [string]$RequestFile,
    [string]$RequestJson = '{"version":1,"action":"status"}',
    [ValidateRange(1, 60000)][int]$TimeoutMS = 30000
)

$ErrorActionPreference = 'Stop'
if ($ManifestPath) {
    if ($PipeName) { throw 'Specify either PipeName or ManifestPath.' }
    $taskManifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($taskManifest.version -ne 1) { throw 'Unsupported bridge manifest.' }
    $PipeName = [string]$taskManifest.pipe
}
if (-not $PipeName -or $PipeName.Length -gt 250 -or $PipeName.Contains('\') -or
    $PipeName.Contains('/') -or $PipeName.Contains([char]0)) {
    throw 'Specify a local pipe name from the running MangaMaker manifest.'
}
if ($RequestFile) { $RequestJson = Get-Content -LiteralPath $RequestFile -Raw -Encoding UTF8 }
$taskRequest = $RequestJson | ConvertFrom-Json
if ($taskRequest.version -ne 1 -or -not $taskRequest.action) { throw 'Request needs version:1 and action.' }
$taskJson = $taskRequest | ConvertTo-Json -Depth 64 -Compress
$taskUtf8 = [Text.UTF8Encoding]::new($false, $true)
$taskBytes = $taskUtf8.GetBytes($taskJson + "`n")
if ($taskBytes.Length -gt 1048576) { throw 'Request exceeds the 1 MiB limit.' }
$taskClock = [Diagnostics.Stopwatch]::StartNew()
$taskPipe = [IO.Pipes.NamedPipeClientStream]::new('.', $PipeName, [IO.Pipes.PipeDirection]::InOut,
    [IO.Pipes.PipeOptions]::Asynchronous, [Security.Principal.TokenImpersonationLevel]::Identification)
$taskReply = [IO.MemoryStream]::new()
try {
    $taskPipe.Connect($TimeoutMS)
    $taskWrite = $taskPipe.WriteAsync($taskBytes, 0, $taskBytes.Length)
    $taskRemaining = [Math]::Max(0, $TimeoutMS - [int]$taskClock.ElapsedMilliseconds)
    if (-not $taskWrite.Wait($taskRemaining)) { throw 'Bridge write timed out.' }
    [void]$taskWrite.GetAwaiter().GetResult()
    $taskBuffer = [byte[]]::new(4096)
    $taskFinished = $false
    while (-not $taskFinished) {
        $taskRead = $taskPipe.ReadAsync($taskBuffer, 0, $taskBuffer.Length)
        $taskRemaining = [Math]::Max(0, $TimeoutMS - [int]$taskClock.ElapsedMilliseconds)
        if (-not $taskRead.Wait($taskRemaining)) { throw 'Bridge read timed out.' }
        $taskCount = $taskRead.GetAwaiter().GetResult()
        if ($taskCount -eq 0) { throw 'Bridge closed before a complete reply.' }
        if ($taskReply.Length + $taskCount -gt 4194304) { throw 'Reply exceeds the 4 MiB limit.' }
        for ($taskAt = 0; $taskAt -lt $taskCount; $taskAt++) {
            if ($taskBuffer[$taskAt] -eq 10) {
                if ($taskAt -ne $taskCount - 1) { throw 'Unexpected data after reply.' }
                $taskReply.Write($taskBuffer, 0, $taskAt)
                $taskFinished = $true
                break
            }
        }
        if (-not $taskFinished) { $taskReply.Write($taskBuffer, 0, $taskCount) }
    }
    $taskUtf8.GetString($taskReply.ToArray()) | ConvertFrom-Json
} finally {
    $taskReply.Dispose()
    $taskPipe.Dispose()
    $taskClock.Stop()
}
