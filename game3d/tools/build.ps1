[CmdletBinding()]
param(
    [ValidateSet('All', 'Windows', 'Web')]
    [string]$Target = 'All',
    [string]$Engine = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repoRoot = Split-Path -Parent $projectRoot
$buildRoot = Join-Path $repoRoot '.build/3d'
$templateRoot = Join-Path $repoRoot '.tools/templates'
if (-not $Engine) {
    $Engine = Join-Path $repoRoot '.tools/godot-4.5.1/Godot_v4.5.1-stable_win64_console.exe'
}
if (-not (Test-Path -LiteralPath $Engine -PathType Leaf)) {
    throw 'Godot 4.5.1 is missing. Extract the official Windows editor to .tools/godot-4.5.1, or pass -Engine <path>.'
}
$Engine = (Resolve-Path -LiteralPath $Engine).Path
$version = (& $Engine --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $version -notmatch '^4\.5\.1\.stable(?:\.|$)') {
    throw "Expected Godot 4.5.1 stable; found: $version"
}
$templateVersion = Join-Path $templateRoot 'version.txt'
if (-not (Test-Path -LiteralPath $templateVersion -PathType Leaf) -or
    (Get-Content -LiteralPath $templateVersion -Raw).Trim() -ne '4.5.1.stable') {
    throw 'Matching templates are missing. Extract the official Godot 4.5.1 export templates version.txt and selected Windows/Web files to .tools/templates. This script does not download them.'
}
$required = @()
if ($Target -in @('All', 'Windows')) { $required += 'windows_release_x86_64.exe' }
if ($Target -in @('All', 'Web')) { $required += 'web_nothreads_release.zip' }
foreach ($template in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $templateRoot $template) -PathType Leaf)) {
        throw "Missing .tools/templates/$template. Use templates from the same 4.5.1 release as the editor."
    }
}
New-Item -ItemType Directory -Force -Path $buildRoot | Out-Null

function Invoke-GodotChecked {
    param([string]$Stage, [string[]]$GodotArgs)
    $logPath = [IO.Path]::GetFullPath((Join-Path $buildRoot "$Stage.log"))
    $arguments = @('--headless', '--path', $projectRoot, '--log-file', $logPath) + $GodotArgs
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $lines = @(& $Engine @arguments 2>&1)
        $stageExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    $output = ($lines | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $output = $output -replace '\x1b\[[0-9;]*[A-Za-z]', ''
    [IO.File]::WriteAllText($logPath, $output, [Text.UTF8Encoding]::new($false))
    Write-Output $output
    if ($stageExit -ne 0 -or $output -match '(?m)^\s*(?:SCRIPT ERROR|ERROR|Parse Error):') {
        throw "Godot $Stage failed (exit $stageExit). See $logPath."
    }
}

# Import first: exported script bytecode must include the complete class registry.
Invoke-GodotChecked -Stage 'import' -GodotArgs @('--editor', '--import', '--quit')
if ($Target -in @('All', 'Windows')) {
    $windowsRoot = Join-Path $buildRoot 'windows'
    New-Item -ItemType Directory -Force -Path $windowsRoot | Out-Null
    $windowsExe = Join-Path $windowsRoot 'RockBottom.exe'
    Invoke-GodotChecked -Stage 'export-windows' -GodotArgs @('--export-release', 'Windows', $windowsExe)
    if (-not (Test-Path -LiteralPath $windowsExe -PathType Leaf)) { throw 'Windows export did not produce RockBottom.exe.' }
}
if ($Target -in @('All', 'Web')) {
    $webRoot = Join-Path $buildRoot 'web'
    New-Item -ItemType Directory -Force -Path $webRoot | Out-Null
    Invoke-GodotChecked -Stage 'export-web' -GodotArgs @('--export-release', 'Web', (Join-Path $webRoot 'index.html'))
    foreach ($file in @('index.html', 'index.js', 'index.wasm', 'index.pck')) {
        if (-not (Test-Path -LiteralPath (Join-Path $webRoot $file) -PathType Leaf)) { throw "Web export did not produce $file." }
    }
    Copy-Item -LiteralPath (Join-Path $projectRoot 'web/storage.js') -Destination (Join-Path $webRoot 'storage.js')
    $html = Get-Content -LiteralPath (Join-Path $webRoot 'index.html') -Raw
    if (-not $html.Contains('<script src="storage.js"></script>')) { throw 'The exported web shell is missing the async storage adapter.' }
    # A normal refresh can retain cached subresources. Give each game-data revision its own URL.
    $packPath = Join-Path $webRoot 'index.pck'
    $packHash = (Get-FileHash -LiteralPath $packPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $packName = "index.$packHash.pck"
    Copy-Item -LiteralPath $packPath -Destination (Join-Path $webRoot $packName)
    $configMatch = [regex]::Match($html, '(?m)^const GODOT_CONFIG = (\{[^\r\n]+\});\r?$')
    if (-not $configMatch.Success) { throw 'Expected Godot web configuration was not found; refusing to emit a stale pack URL.' }
    $config = $configMatch.Groups[1].Value | ConvertFrom-Json -AsHashtable
    $config['mainPack'] = $packName
    $config['fileSizes'][$packName] = (Get-Item -LiteralPath $packPath).Length
    $config['fileSizes'].Remove('index.pck')
    $html = $html.Replace($configMatch.Groups[1].Value, ($config | ConvertTo-Json -Depth 8 -Compress))
    [IO.File]::WriteAllText((Join-Path $webRoot 'index.html'), $html, [Text.UTF8Encoding]::new($false))
}
Write-Output "3D BUILD: PASS ($Target; Godot $version; outputs: $buildRoot)"
