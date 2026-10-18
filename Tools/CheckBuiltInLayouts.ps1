param([string]$OutputDirectory = 'TestOutput\BuiltInLayouts')
$ErrorActionPreference = 'Stop'
# 定数で定義した標準コマ割りだけを読む静的検査。Delphiのビルド・UI検証の代用にはしない。
$taskProject = Split-Path $PSScriptRoot -Parent
$taskOutput = [IO.Path]::GetFullPath((Join-Path $taskProject $OutputDirectory))
if (-not $taskOutput.StartsWith((Join-Path $taskProject 'TestOutput') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Verification output must stay inside TestOutput.'
}
$taskSourcePath = Join-Path $taskProject 'Source\Model\ComicLayouts.pas'
$taskSource = [IO.File]::ReadAllText($taskSourcePath)
$taskCases = [regex]::Matches($taskSource, "(?ms)^\s*(\d+): begin L\.Name:='([^']+)';(.*?)end;")
$taskCountMatch = [regex]::Match($taskSource, 'BuiltInLayoutCount\s*=\s*(\d+);')
$taskExpectedCount = [int]$taskCountMatch.Groups[1].Value
if ($taskCases.Count -ne $taskExpectedCount) { throw 'Standard case count differs from BuiltInLayoutCount.' }
$taskLayouts = @()
$taskNames = @{}
$taskIDs = @{}
$taskGeometry = @{}
foreach ($taskCase in $taskCases) {
    $taskID = [int]$taskCase.Groups[1].Value
    $taskName = $taskCase.Groups[2].Value
    if ($taskIDs.ContainsKey($taskID) -or $taskNames.ContainsKey($taskName)) { throw 'Duplicate standard ID or name.' }
    $taskIDs[$taskID] = $true; $taskNames[$taskName] = $true
    $taskRects = @()
    foreach ($taskMatch in [regex]::Matches($taskCase.Groups[3].Value, 'Add\((\d+),(\d+),(\d+),(\d+)\)')) {
        $taskRects += [pscustomobject]@{ number = $taskRects.Count + 1; left = [int]$taskMatch.Groups[1].Value;
            top = [int]$taskMatch.Groups[2].Value; right = [int]$taskMatch.Groups[3].Value; bottom = [int]$taskMatch.Groups[4].Value }
    }
    if ($taskRects.Count -eq 0) { throw "No rectangles in $taskName" }
    foreach ($taskRect in $taskRects) {
        if ($taskRect.left -lt 60 -or $taskRect.top -lt 60 -or $taskRect.right -gt 1140 -or $taskRect.bottom -gt 1640 -or
            $taskRect.right - $taskRect.left -lt 30 -or $taskRect.bottom - $taskRect.top -lt 30) { throw "Out of bounds or too small: $taskName" }
    }
    for ($i = 0; $i -lt $taskRects.Count; $i++) {
        for ($j = $i + 1; $j -lt $taskRects.Count; $j++) {
            $a = $taskRects[$i]; $b = $taskRects[$j]
            $xOverlap = [Math]::Min($a.right, $b.right) - [Math]::Max($a.left, $b.left)
            $yOverlap = [Math]::Min($a.bottom, $b.bottom) - [Math]::Max($a.top, $b.top)
            if ($xOverlap -gt 0 -and $yOverlap -gt 0) { throw "Overlapping panels: $taskName" }
            # 同じ段は右から左、同じ列は上から下。縦長の隣列もこの関係で確認する。
            if ($yOverlap -gt 0 -and $a.left - $b.right -lt 24) { throw "Wrong horizontal reading order or gutter: $taskName" }
            if ($xOverlap -gt 0 -and $b.top - $a.bottom -lt 24) { throw "Wrong vertical reading order or gutter: $taskName" }
        }
    }
    $taskKey = ($taskRects | ForEach-Object { '{0},{1},{2},{3}' -f $_.left,$_.top,$_.right,$_.bottom }) -join ';'
    if ($taskGeometry.ContainsKey($taskKey)) { throw "Duplicate layout geometry: $taskName" }
    $taskGeometry[$taskKey] = $true
    $taskLayouts += [pscustomobject]@{ id = $taskID; name = $taskName; panels = $taskRects; geometry = $taskKey }
}
$taskLayouts = @($taskLayouts | Sort-Object id)
# 従来5件の配置は更新せず、既存インデックスでの利用も保つ。
$taskOriginal = @('60,60,1140,1640', '60,60,1140,838;60,862,1140,1640',
    '612,60,1140,1640;60,60,588,1640', '612,60,1140,838;60,60,588,838;612,862,1140,1640;60,862,588,1640',
    '60,60,1140,974;612,998,1140,1640;60,998,588,1640')
for ($i = 0; $i -lt $taskLayouts.Count; $i++) {
    if ($taskLayouts[$i].id -ne $i + 1) { throw 'Noncontiguous standard IDs.' }
    if ($i -lt 5 -and $taskLayouts[$i].geometry -cne $taskOriginal[$i]) { throw 'Original standard layout changed.' }
}
if ($taskSource -notmatch 'Item\.Shape:=0; Item\.Number:=L\.Panels\.Count\+1' -or
    $taskSource -notmatch 'if not L\.BuiltIn then A\.AddElement\(L\.Json\)') { throw 'Review numbering or persistence policy changes.' }
New-Item -ItemType Directory -Path $taskOutput -Force | Out-Null
$taskReport = [ordered]@{ mode = 'static-source'; result = 'PASS'; count = $taskLayouts.Count; additions = $taskLayouts.Count - 5;
    checks = @('unique IDs/names/geometry', 'original five preserved', 'page bounds', 'minimum size', 'no overlap',
        '24px gutters', 'right-to-left/top-to-bottom order', 'consecutive panel numbers', 'built-ins excluded from persistence');
    compiled = $false; sourceSHA256 = (Get-FileHash -LiteralPath $taskSourcePath -Algorithm SHA256).Hash; layouts = $taskLayouts }
$taskReport | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $taskOutput 'structure.json') -Encoding utf8
# 実VCLサムネイルとは区別し、番号付きの構造見本だけをSVGへ出力する。
$taskSVG = [Text.StringBuilder]::new()
[void]$taskSVG.AppendLine('<svg xmlns="http://www.w3.org/2000/svg" width="1120" height="1560" viewBox="0 0 1120 1560"><rect width="1120" height="1560" fill="#eee"/>')
for ($i = 0; $i -lt $taskLayouts.Count; $i++) {
    $layout = $taskLayouts[$i]; $x = 20 + ($i % 4) * 280; $y = 20 + [Math]::Floor($i / 4) * 310
    $name = [Security.SecurityElement]::Escape($layout.name)
    [void]$taskSVG.AppendLine("<g transform=`"translate($x $y)`"><text x=`"0`" y=`"18`" font-family=`"sans-serif`" font-size=`"13`">$($layout.id). $name</text><g transform=`"translate(30 30) scale(.14)`"><rect width=`"1200`" height=`"1700`" fill=`"white`"/>")
    foreach ($rect in $layout.panels) {
        $width = $rect.right - $rect.left; $height = $rect.bottom - $rect.top
        $cx = ($rect.left + $rect.right) / 2; $cy = ($rect.top + $rect.bottom) / 2
        [void]$taskSVG.AppendLine("<rect x=`"$($rect.left)`" y=`"$($rect.top)`" width=`"$width`" height=`"$height`" fill=`"#f5f7fb`" stroke=`"#222`" stroke-width=`"8`"/><text x=`"$cx`" y=`"$cy`" text-anchor=`"middle`" dominant-baseline=`"middle`" font-family=`"sans-serif`" font-size=`"90`">$($rect.number)</text>")
    }
    [void]$taskSVG.AppendLine('</g></g>')
}
[void]$taskSVG.AppendLine('</svg>')
[IO.File]::WriteAllText((Join-Path $taskOutput 'layout-structure.svg'),$taskSVG.ToString(),[Text.UTF8Encoding]::new($false))
Write-Output "Static built-in layouts PASS: $($taskLayouts.Count) layouts, $($taskLayouts.Count - 5) additions. No Delphi/UI execution."
