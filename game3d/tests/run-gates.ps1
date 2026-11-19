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
foreach ($script in @('test_simulation.gd', 'test_scene.gd', 'test_art.gd', 'test_viewmodel.gd', 'test_game_state.gd', 'test_memory_loop.gd', 'test_progression.gd', 'test_economy.gd', 'test_full_world.gd', 'test_character_roster.gd', 'test_combat.gd', 'test_full_runtime.gd', 'test_world_adapter.gd', 'test_full_integration.gd', 'test_bosses.gd', 'test_travel.gd', 'test_actor_navigation.gd', 'test_full_hud.gd', 'test_full_scene.gd', 'test_resident_dialogue.gd', 'test_quest_dialogue.gd', 'test_street_dialogue.gd', 'test_rhythm.gd', 'test_robbery.gd', 'test_day_system.gd', 'test_communications.gd', 'test_heists.gd', 'test_site_integration.gd', 'test_campaign.gd', 'test_office_campaign.gd', 'test_cooking.gd', 'test_cooking_presentation.gd', 'test_startup.gd', 'test_cooking_runtime.gd', 'test_companions.gd', 'test_kingdom_campaign.gd', 'test_kingdom_physics.gd', 'test_world_prop_actions.gd', 'test_interactive_props.gd', 'test_actor_contact.gd', 'test_presentation_visibility.gd', 'test_incidents.gd', 'test_neighborhood_utilities.gd', 'test_interactive_prop_view.gd', 'test_viewmodel_context.gd', 'test_guidance.gd', 'test_incident_presentation.gd')) {
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
Invoke-Gate -Name 'heists' -GodotArgs @('--script', 'res://tests/test_heists.gd', '--quit-after', '12000') -PassPattern '3D HEIST GATE: PASS'
Invoke-Gate -Name 'sites' -GodotArgs @('--script', 'res://tests/test_site_integration.gd', '--quit-after', '12000') -PassPattern '3D SITE INTEGRATION GATE: PASS'
Invoke-Gate -Name 'campaign' -GodotArgs @('--script', 'res://tests/test_campaign.gd', '--quit-after', '12000') -PassPattern '3D CAMPAIGN FOUNDATION GATE: PASS'
Invoke-Gate -Name 'office' -GodotArgs @('--script', 'res://tests/test_office_campaign.gd', '--quit-after', '12000') -PassPattern '3D OFFICE CAMPAIGN GATE: PASS'
Invoke-Gate -Name 'cooking' -GodotArgs @('--script', 'res://tests/test_cooking.gd', '--quit-after', '12000') -PassPattern '3D COOKING GATE: PASS'
Invoke-Gate -Name 'cooking-presentation' -GodotArgs @('--script', 'res://tests/test_cooking_presentation.gd', '--quit-after', '12000') -PassPattern '3D COOKING PRESENTATION GATE: PASS'
Invoke-Gate -Name 'startup' -GodotArgs @('--script', 'res://tests/test_startup.gd', '--quit-after', '12000') -PassPattern '3D STARTUP GATE: PASS'
Invoke-Gate -Name 'cooking-runtime' -GodotArgs @('--script', 'res://tests/test_cooking_runtime.gd', '--quit-after', '12000') -PassPattern '3D COOKING RUNTIME GATE: PASS'
Invoke-Gate -Name 'companions' -GodotArgs @('--script', 'res://tests/test_companions.gd', '--quit-after', '6000') -PassPattern '3D COMPANION GATE: PASS'
Invoke-Gate -Name 'kingdom' -GodotArgs @('--script', 'res://tests/test_kingdom_campaign.gd', '--quit-after', '12000') -PassPattern '3D KINGDOM CAMPAIGN GATE: PASS'
Invoke-Gate -Name 'kingdom-physics' -GodotArgs @('--script', 'res://tests/test_kingdom_physics.gd', '--quit-after', '12000') -PassPattern '3D KINGDOM PHYSICS GATE: PASS'
Invoke-Gate -Name 'world-props' -GodotArgs @('--script', 'res://tests/test_world_prop_actions.gd', '--quit-after', '12000') -PassPattern '3D WORLD PROP ACTIONS GATE: PASS'
Invoke-Gate -Name 'interactive-props' -GodotArgs @('--script', 'res://tests/test_interactive_props.gd', '--quit-after', '12000') -PassPattern '3D INTERACTIVE PROPS GATE: PASS'
Invoke-Gate -Name 'actor-contact' -GodotArgs @('--script', 'res://tests/test_actor_contact.gd', '--quit-after', '12000') -PassPattern '3D ACTOR CONTACT GATE: PASS'
Invoke-Gate -Name 'presentation-visibility' -GodotArgs @('--script', 'res://tests/test_presentation_visibility.gd', '--quit-after', '12000') -PassPattern '3D PRESENTATION VISIBILITY GATE: PASS'
Invoke-Gate -Name 'incidents' -GodotArgs @('--script', 'res://tests/test_incidents.gd', '--quit-after', '12000') -PassPattern '3D INCIDENTS GATE: PASS'
Invoke-Gate -Name 'utilities' -GodotArgs @('--script', 'res://tests/test_neighborhood_utilities.gd', '--quit-after', '12000') -PassPattern '3D NEIGHBORHOOD UTILITIES GATE: PASS'
Invoke-Gate -Name 'interactive-prop-view' -GodotArgs @('--script', 'res://tests/test_interactive_prop_view.gd', '--quit-after', '12000') -PassPattern '3D INTERACTIVE PROP VIEW GATE: PASS'
Invoke-Gate -Name 'viewmodel-context' -GodotArgs @('--script', 'res://tests/test_viewmodel_context.gd', '--quit-after', '12000') -PassPattern '3D VIEWMODEL CONTEXT GATE: PASS'
Invoke-Gate -Name 'guidance' -GodotArgs @('--script', 'res://tests/test_guidance.gd', '--quit-after', '12000') -PassPattern '3D GUIDANCE: PASS'
Invoke-Gate -Name 'incident-presentation' -GodotArgs @('--script', 'res://tests/test_incident_presentation.gd', '--quit-after', '12000') -PassPattern '3D INCIDENT PRESENTATION GATE: PASS'
Invoke-Gate -Name 'guidance-projection' -GodotArgs @('--script', 'res://tests/test_guidance_projection.gd', '--quit-after', '12000') -PassPattern '3D GUIDANCE PROJECTION: PASS'
Invoke-Gate -Name 'incident-reservations' -GodotArgs @('--script', 'res://tests/test_incident_reservations.gd', '--quit-after', '12000') -PassPattern '3D INCIDENT RESERVATION GATE: PASS'
Invoke-Gate -Name 'incident-runtime' -GodotArgs @('--script', 'res://tests/test_incident_runtime.gd', '--quit-after', '12000') -PassPattern '3D INCIDENT RUNTIME GATE: PASS'
Invoke-Gate -Name 'cart-view' -GodotArgs @('--script', 'res://tests/test_cart_view.gd', '--quit-after', '12000') -PassPattern '3D CART VIEW GATE: PASS'
Invoke-Gate -Name 'old-school' -GodotArgs @('--script', 'res://tests/test_old_school.gd', '--quit-after', '12000') -PassPattern '3D OLD SCHOOL: PASS'
Invoke-Gate -Name 'old-school-physical' -GodotArgs @('--script', 'res://tests/test_old_school_physical.gd', '--quit-after', '12000') -PassPattern '3D OLD SCHOOL PHYSICAL GATE: PASS'
Invoke-Gate -Name 'source-audio' -GodotArgs @('--script', 'res://tests/test_source_audio.gd', '--quit-after', '12000') -PassPattern '3D SOURCE AUDIO GATE: PASS'
Invoke-Gate -Name 'audio-runtime' -GodotArgs @('--script', 'res://tests/test_audio_runtime.gd', '--quit-after', '12000') -PassPattern '3D AUDIO RUNTIME GATE: PASS'
Invoke-Gate -Name 'find-view' -GodotArgs @('--script', 'res://tests/test_find_view.gd', '--quit-after', '12000') -PassPattern '3D FIND VIEW GATE: PASS'
Invoke-Gate -Name 'weather-presentation' -GodotArgs @('--script', 'res://tests/test_weather_presentation.gd', '--quit-after', '12000') -PassPattern '3D WEATHER PRESENTATION GATE: PASS'
Invoke-Gate -Name 'actor-hud' -GodotArgs @('--script', 'res://tests/test_actor_hud.gd', '--quit-after', '12000') -PassPattern '3D ACTOR HUD: PASS'
Invoke-Gate -Name 'viewmodel-gear' -GodotArgs @('--script', 'res://tests/test_viewmodel_gear.gd', '--quit-after', '12000') -PassPattern '3D VIEWMODEL GEAR GATE: PASS'
Invoke-Gate -Name 'departures' -GodotArgs @('--script', 'res://tests/test_departures.gd', '--quit-after', '12000') -PassPattern '3D DEPARTURE PHYSICS GATE: PASS'
Invoke-Gate -Name 'projectile-view' -GodotArgs @('--script', 'res://tests/test_projectile_view.gd', '--quit-after', '12000') -PassPattern '3D PROJECTILE VIEW GATE: PASS'
Invoke-Gate -Name 'dynamic-emitters' -GodotArgs @('--script', 'res://tests/test_dynamic_emitters.gd', '--quit-after', '12000') -PassPattern '3D DYNAMIC EMITTER GATE: PASS'
Invoke-Gate -Name 'world-ownership' -GodotArgs @('--script', 'res://tests/test_world_ownership.gd', '--quit-after', '6000') -PassPattern '3D WORLD OWNERSHIP: PASS'
Invoke-Gate -Name 'leash-border' -GodotArgs @('--script', 'res://tests/test_leash_border.gd', '--quit-after', '6000') -PassPattern '3D LEASH BORDER GATE: PASS'
Invoke-Gate -Name 'kingdom-view' -GodotArgs @('--script', 'res://tests/test_kingdom_view.gd', '--quit-after', '6000') -PassPattern '3D KINGDOM VIEW: PASS'
Invoke-Gate -Name 'wall-markings' -GodotArgs @('--script', 'res://tests/test_wall_markings.gd', '--quit-after', '6000') -PassPattern '3D WALL MARKINGS GATE: PASS'
Invoke-Gate -Name 'wall-marking-view' -GodotArgs @('--script', 'res://tests/test_wall_marking_view.gd', '--quit-after', '6000') -PassPattern '3D WALL MARKING VIEW GATE: PASS'
Invoke-Gate -Name 'boss-acceptance-contract' -GodotArgs @('--script', 'res://tests/test_boss_acceptance_contract.gd', '--quit-after', '6000') -PassPattern '3D BOSS ACCEPTANCE CONTRACT: PASS'
Invoke-Gate -Name 'pose-input-memo' -GodotArgs @('--script', 'res://tests/test_pose_input_memo.gd', '--quit-after', '6000') -PassPattern '3D POSE INPUT MEMO GATE: PASS'
Invoke-Gate -Name 'district-grade' -GodotArgs @('--script', 'res://tests/test_district_grade.gd', '--quit-after', '6000') -PassPattern 'DISTRICT GRADE DRAFT GATE: PASS'
Invoke-Gate -Name 'office-acceptance-contract' -GodotArgs @('--script', 'res://tests/test_office_acceptance_contract.gd', '--quit-after', '6000') -PassPattern '3D OFFICE ACCEPTANCE CONTRACT: PASS'
Invoke-Gate -Name 'karaoke-acceptance-contract' -GodotArgs @('--script', 'res://tests/test_karaoke_acceptance_contract.gd', '--quit-after', '6000') -PassPattern '3D KARAOKE ACCEPTANCE CONTRACT: PASS'
Invoke-Gate -Name 'fixture-motion' -GodotArgs @('--script', 'res://tests/test_fixture_motion.gd', '--quit-after', '6000') -PassPattern '3D FIXTURE MOTION GATE: PASS'
Invoke-Gate -Name 'fixture-motion-world' -GodotArgs @('--script', 'res://tests/test_fixture_motion_world.gd', '--quit-after', '6000') -PassPattern '3D FIXTURE MOTION WORLD GATE: PASS'
Invoke-Gate -Name 'startup-parity' -GodotArgs @('--script', 'res://tests/test_startup_parity.gd', '--quit-after', '6000') -PassPattern '3D STARTUP PARITY GATE: PASS'
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
    @{ Name = 'heist-oracle'; Script = '3d-heist-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'campaign-oracle'; Script = '3d-campaign-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'office-oracle'; Script = '3d-office-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'cooking-oracle'; Script = '3d-cooking-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'companion-oracle'; Script = '3d-companion-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'kingdom-oracle'; Script = '3d-kingdom-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'world-props-oracle'; Script = '3d-world-props-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'interactive-props-oracle'; Script = '3d-interactive-props-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'incidents-oracle'; Script = '3d-incidents-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'utilities-oracle'; Script = '3d-neighborhood-utilities-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'guidance-oracle'; Script = '3d-guidance-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'guidance-projection-oracle'; Script = '3d-guidance-projection-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'old-school-oracle'; Script = '3d-old-school-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'audio-oracle'; Script = '3d-audio-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'weather-oracle'; Script = '3d-weather-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'actor-hud-oracle'; Script = '3d-actor-hud-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'world-ownership-oracle'; Script = '3d-world-ownership-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'leash-border-oracle'; Script = 'leash-border-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'kingdom-view-oracle'; Script = '3d-kingdom-view-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'wall-markings-oracle'; Script = 'wall-markings-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'district-grade-oracle'; Script = 'district-grade-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'fixture-motion-oracle'; Script = '3d-fixture-motion-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'startup-oracle'; Script = '3d-startup-oracle.mjs'; Arguments = @('--check') },
    @{ Name = 'parity-coverage'; Script = '3d-parity-gate.mjs'; Arguments = @() }
)) {
    $scriptPath = Join-Path $repoRoot ('tools/' + $entry.Script)
    $nodeArgs = @('--experimental-vm-modules', $scriptPath) + $entry.Arguments
    & node @nodeArgs 2>&1 | Tee-Object -FilePath (Join-Path $logRoot ($entry.Name + '.log'))
    if ($LASTEXITCODE -ne 0) { throw "3D gate $($entry.Name) failed." }
}
Write-Output '3D GATE RUNNER: 115/115 PASS (import clean; 75 engine suites and 40 source/parity checks; complete-port acceptance remains tracked separately)'
