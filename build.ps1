param([switch]$SelfTest, [string]$OutputDirectory, [ValidateSet('Debug','Release')][string]$Configuration='Debug')
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
  $env:BDS = 'C:\Program Files (x86)\Embarcadero\Studio\37.0'
  $env:BDSCOMMONDIR = 'C:\Users\Public\Documents\Embarcadero\Studio\37.0'
  if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $PSScriptRoot ('TestOutput\Build-' + [guid]::NewGuid().ToString('N'))
  }
  $taskBuildRoot = [IO.Path]::GetFullPath($OutputDirectory)
  if (-not $taskBuildRoot.StartsWith((Join-Path $PSScriptRoot 'TestOutput') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Build output must stay inside this project''s TestOutput directory.'
  }
  New-Item -ItemType Directory -Path $taskBuildRoot -Force | Out-Null
  & 'C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe' MangaMaker.dproj /t:Build "/p:Config=$Configuration" /p:Platform=Win64 "/p:DCC_ExeOutput=$taskBuildRoot" "/p:DCC_DcuOutput=$taskBuildRoot\Dcu" /v:minimal /nologo
  if ($LASTEXITCODE -ne 0) { throw 'Build failed.' }
  Write-Output (Join-Path $taskBuildRoot 'MangaMaker.exe')
  if ($SelfTest) {
    $taskRoot = Join-Path $PSScriptRoot ('TestOutput\' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $taskRoot -Force | Out-Null
    $taskPrevious = $env:MANGAMAKER_DATA_ROOT
    try {
      $env:MANGAMAKER_DATA_ROOT = Join-Path $taskRoot 'Data'
      $taskProcess = Start-Process -FilePath (Join-Path $taskBuildRoot 'MangaMaker.exe') -ArgumentList @('--self-test',('"' + $taskRoot + '"')) -WindowStyle Hidden -PassThru
      if (-not $taskProcess.WaitForExit(60000)) { throw 'Self-test timed out.' }
      Get-Content -LiteralPath (Join-Path $taskRoot 'result.txt') -Encoding UTF8
      Write-Output $taskRoot
      if ($taskProcess.ExitCode -ne 0) { throw 'Self-test failed.' }
    } finally { $env:MANGAMAKER_DATA_ROOT = $taskPrevious }
  }
} finally { Pop-Location }
