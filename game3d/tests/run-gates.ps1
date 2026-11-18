[CmdletBinding()]
param([string]$Engine = '')

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repoRoot = Split-Path -Parent $projectRoot
$logRoot = Join-Path $repoRoot '.build/3d/gates'
if (-not $Engine) {
    $Engine = Join-Path $repoRoot '.tools/godot-4.5.1/Godot_v4.5.1-stable_win64_console.exe'
}
if (-not (Test-Path -LiteralPath $Engine -PathType Leaf)) {
    throw 'Godot 4.5.1 is missing. Pass -Engine <path> or extract it to .tools/godot-4.5.1.'
}
$Engine = (Resolve-Path -LiteralPath $Engine).Path
$version = (& $Engine --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $version -notmatch '^4\.5\.1\.stable(?:\.|$)') {
    throw "Expected Godot 4.5.1 stable; found: $version"
}
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null

function Invoke-Gate {
    param([string]$Name, [string[]]$GodotArgs, [string]$PassPattern = '')
    $logPath = [IO.Path]::GetFullPath((Join-Path $logRoot "$Name.log"))
    $arguments = @('--headless', '--path', $projectRoot, '--log-file', $logPath) + $GodotArgs
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $lines = @(& $Engine @arguments 2>&1)
        $gateExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    $output = ($lines | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $output = $output -replace '\x1b\[[0-9;]*[A-Za-z]', ''
    [IO.File]::WriteAllText($logPath, $output, [Text.UTF8Encoding]::new($false))
    Write-Output $output
    if ($gateExit -ne 0 -or $output -match '(?m)^\s*(?:SCRIPT ERROR|ERROR|Parse Error):' -or
        ($PassPattern -and $output -notmatch $PassPattern)) {
        throw "3D gate $Name failed (exit $gateExit or missing PASS/error output). See $logPath."
    }
}

Invoke-Gate -Name 'import' -GodotArgs @('--editor', '--import', '--quit')
foreach ($script in @('test_simulation.gd', 'test_scene.gd', 'test_art.gd', 'test_viewmodel.gd', 'test_game_state.gd', 'test_memory_loop.gd', 'test_progression.gd')) {
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $script) -PathType Leaf)) {
        throw "Required gate $script is missing. Simulation, scene and art checks must exist before this runner can pass."
    }
}
Invoke-Gate -Name 'simulation' -GodotArgs @('--script', 'res://tests/test_simulation.gd', '--quit-after', '6000') -PassPattern '3D SIMULATION GATE: PASS'
Invoke-Gate -Name 'scene' -GodotArgs @('--script', 'res://tests/test_scene.gd', '--quit-after', '6000') -PassPattern '3D SCENE GATE: PASS'
Invoke-Gate -Name 'art' -GodotArgs @('--script', 'res://tests/test_art.gd', '--quit-after', '6000') -PassPattern '3D ART GATE: PASS'
Invoke-Gate -Name 'viewmodel' -GodotArgs @('--script', 'res://tests/test_viewmodel.gd', '--quit-after', '6000') -PassPattern '3D VIEWMODEL GATE: PASS'
Invoke-Gate -Name 'full-state' -GodotArgs @('--script', 'res://tests/test_game_state.gd', '--quit-after', '6000') -PassPattern '3D FULL STATE GATE: PASS'
Invoke-Gate -Name 'memory' -GodotArgs @('--script', 'res://tests/test_memory_loop.gd', '--quit-after', '6000') -PassPattern '3D MEMORY GATE: PASS'
Invoke-Gate -Name 'progression' -GodotArgs @('--script', 'res://tests/test_progression.gd', '--quit-after', '6000') -PassPattern '3D PROGRESSION GATE: PASS'
foreach ($entry in @(
    @{ Name = 'content'; Script = '3d-content-gate.mjs'; Arguments = @() },
    @{ Name = 'content-drift'; Script = 'export-3d-content.mjs'; Arguments = @('--check') },
    @{ Name = 'memory-oracle'; Script = '3d-memory-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'progression-oracle'; Script = '3d-progression-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'parity-coverage'; Script = '3d-parity-gate.mjs'; Arguments = @() }
)) {
    $scriptPath = Join-Path $repoRoot ('tools/' + $entry.Script)
    $nodeArgs = @('--experimental-vm-modules', $scriptPath) + $entry.Arguments
    & node @nodeArgs 2>&1 | Tee-Object -FilePath (Join-Path $logRoot ($entry.Name + '.log'))
    if ($LASTEXITCODE -ne 0) { throw "3D gate $($entry.Name) failed." }
}
Write-Output '3D GATE RUNNER: 12/12 PASS (import clean; 7 engine suites and 5 source/parity checks; full-port integration remains tracked separately)'
