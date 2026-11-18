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
foreach ($script in @('test_simulation.gd', 'test_scene.gd', 'test_art.gd', 'test_viewmodel.gd', 'test_game_state.gd', 'test_memory_loop.gd', 'test_progression.gd', 'test_economy.gd', 'test_full_world.gd', 'test_character_roster.gd', 'test_combat.gd', 'test_full_runtime.gd', 'test_world_adapter.gd', 'test_full_integration.gd', 'test_bosses.gd', 'test_travel.gd', 'test_actor_navigation.gd', 'test_full_hud.gd', 'test_full_scene.gd', 'test_resident_dialogue.gd', 'test_quest_dialogue.gd', 'test_street_dialogue.gd', 'test_rhythm.gd', 'test_robbery.gd', 'test_day_system.gd', 'test_communications.gd')) {
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
Invoke-Gate -Name 'economy' -GodotArgs @('--script', 'res://tests/test_economy.gd', '--quit-after', '6000') -PassPattern '3D ECONOMY GATE: PASS'
Invoke-Gate -Name 'full-world' -GodotArgs @('--script', 'res://tests/test_full_world.gd', '--quit-after', '12000') -PassPattern 'FULL WORLD GEOMETRY PASS:'
Invoke-Gate -Name 'roster' -GodotArgs @('--script', 'res://tests/test_character_roster.gd', '--quit-after', '6000') -PassPattern '3D CHARACTER ROSTER GATE: PASS'
Invoke-Gate -Name 'combat' -GodotArgs @('--script', 'res://tests/test_combat.gd', '--quit-after', '6000') -PassPattern '3D COMBAT GATE: PASS'
Invoke-Gate -Name 'full-runtime' -GodotArgs @('--script', 'res://tests/test_full_runtime.gd', '--quit-after', '6000') -PassPattern '3D FULL RUNTIME GATE: PASS'
Invoke-Gate -Name 'physics-adapter' -GodotArgs @('--script', 'res://tests/test_world_adapter.gd', '--quit-after', '6000') -PassPattern '3D PHYSICS ADAPTER GATE: PASS'
Invoke-Gate -Name 'full-integration' -GodotArgs @('--script', 'res://tests/test_full_integration.gd', '--quit-after', '6000') -PassPattern '3D FULL INTEGRATION GATE: PASS'
Invoke-Gate -Name 'bosses' -GodotArgs @('--script', 'res://tests/test_bosses.gd', '--quit-after', '6000') -PassPattern '3D BOSS GATE: PASS'
Invoke-Gate -Name 'travel' -GodotArgs @('--script', 'res://tests/test_travel.gd', '--quit-after', '6000') -PassPattern '3D TRAVEL GATE: PASS'
Invoke-Gate -Name 'navigation' -GodotArgs @('--script', 'res://tests/test_actor_navigation.gd', '--quit-after', '6000') -PassPattern '3D ACTOR NAVIGATION GATE: PASS'
Invoke-Gate -Name 'full-hud' -GodotArgs @('--script', 'res://tests/test_full_hud.gd', '--quit-after', '6000') -PassPattern '3D FULL HUD GATE: PASS'
Invoke-Gate -Name 'full-scene' -GodotArgs @('--script', 'res://tests/test_full_scene.gd', '--quit-after', '6000') -PassPattern '3D FULL SCENE GATE: PASS'
Invoke-Gate -Name 'residents' -GodotArgs @('--script', 'res://tests/test_resident_dialogue.gd', '--quit-after', '6000') -PassPattern '3D RESIDENT GATE: PASS'
Invoke-Gate -Name 'quests' -GodotArgs @('--script', 'res://tests/test_quest_dialogue.gd', '--quit-after', '6000') -PassPattern '3D QUEST GATE: PASS'
Invoke-Gate -Name 'street' -GodotArgs @('--script', 'res://tests/test_street_dialogue.gd', '--quit-after', '6000') -PassPattern '3D STREET GATE: PASS'
Invoke-Gate -Name 'rhythm' -GodotArgs @('--script', 'res://tests/test_rhythm.gd', '--quit-after', '6000') -PassPattern '3D RHYTHM GATE: PASS'
Invoke-Gate -Name 'robbery' -GodotArgs @('--script', 'res://tests/test_robbery.gd', '--quit-after', '6000') -PassPattern '3D ROBBERY GATE: PASS'
Invoke-Gate -Name 'days' -GodotArgs @('--script', 'res://tests/test_day_system.gd', '--quit-after', '6000') -PassPattern '3D DAY GATE: PASS'
Invoke-Gate -Name 'communications' -GodotArgs @('--script', 'res://tests/test_communications.gd', '--quit-after', '6000') -PassPattern '3D COMMUNICATIONS GATE: PASS'
foreach ($entry in @(
    @{ Name = 'content'; Script = '3d-content-gate.mjs'; Arguments = @() },
    @{ Name = 'content-drift'; Script = 'export-3d-content.mjs'; Arguments = @('--check') },
    @{ Name = 'memory-oracle'; Script = '3d-memory-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'progression-oracle'; Script = '3d-progression-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'economy-oracle'; Script = '3d-economy-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'world-oracle'; Script = '3d-world-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'combat-oracle'; Script = '3d-combat-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'boss-oracle'; Script = '3d-boss-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'travel-oracle'; Script = '3d-travel-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'resident-oracle'; Script = '3d-resident-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'quest-oracle'; Script = '3d-quest-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'street-oracle'; Script = '3d-street-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'rhythm-oracle'; Script = '3d-rhythm-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'robbery-oracle'; Script = '3d-robbery-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'day-oracle'; Script = '3d-day-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'communications-oracle'; Script = '3d-communications-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'parity-coverage'; Script = '3d-parity-gate.mjs'; Arguments = @() }
)) {
    $scriptPath = Join-Path $repoRoot ('tools/' + $entry.Script)
    $nodeArgs = @('--experimental-vm-modules', $scriptPath) + $entry.Arguments
    & node @nodeArgs 2>&1 | Tee-Object -FilePath (Join-Path $logRoot ($entry.Name + '.log'))
    if ($LASTEXITCODE -ne 0) { throw "3D gate $($entry.Name) failed." }
}
Write-Output '3D GATE RUNNER: 43/43 PASS (import clean; 26 engine suites and 17 source/parity checks; complete-port acceptance remains tracked separately)'
