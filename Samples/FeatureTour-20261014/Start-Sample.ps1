$ErrorActionPreference='Stop'
$samplePreviousRoot=$env:MANGAMAKER_DATA_ROOT
try {
    $env:MANGAMAKER_DATA_ROOT=Join-Path $PSScriptRoot 'Data'
    Start-Process -FilePath (Join-Path $PSScriptRoot 'App\MangaMaker.exe') -WorkingDirectory $PSScriptRoot -WindowStyle Normal
} finally { $env:MANGAMAKER_DATA_ROOT=$samplePreviousRoot }