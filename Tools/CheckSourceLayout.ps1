param(
  [int]$MaxUnitLines = 1500,
  [int]$MaxUnitsPerFolder = 8
)
$ErrorActionPreference = 'Stop'
# note.mdの1500行・8ユニットの基準を確認し、役割の異なる処理が再び集中する前に見直す。
# 行数以内でも責務と長いメソッドをレビューし、空行削除で数値だけを合わせない。
$taskSourceRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'Source'
$taskUnits = @(Get-ChildItem -LiteralPath $taskSourceRoot -Recurse -Filter '*.pas' -File)
$taskViolations = @()
foreach ($taskUnit in $taskUnits) {
  $taskLimit = $MaxUnitLines
  $taskLineCount = [IO.File]::ReadAllLines($taskUnit.FullName).Length
  if ($taskLineCount -gt $taskLimit) {
    $taskViolations += "$($taskUnit.Name): $taskLineCount lines exceeds $taskLimit; split by responsibility."
  }
}
foreach ($taskGroup in $taskUnits | Group-Object DirectoryName) {
  if ($taskGroup.Count -gt $MaxUnitsPerFolder) {
    $taskViolations += "$($taskGroup.Name): $($taskGroup.Count) units exceeds $MaxUnitsPerFolder; organize by responsibility."
  }
}
if ($taskViolations.Count -gt 0) { throw ($taskViolations -join [Environment]::NewLine) }
Write-Output "Source layout OK: $($taskUnits.Count) units."
