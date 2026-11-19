#requires -Version 7.2
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('baseline','positive_certificate')][string]$Variant,
    [Parameter(Mandatory)][ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$')][string]$RunName
)

$ErrorActionPreference = 'Stop'
$Diagnostic = $true # Collect original16ms failures; never relax workload or threshold.
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$engine = Join-Path $repoRoot '.tools/godot-4.5.1/Godot_v4.5.1-stable_win64_console.exe'
$engineRuntime = Join-Path $repoRoot '.tools/godot-4.5.1/Godot_v4.5.1-stable_win64.exe'
$template = Join-Path $repoRoot '.tools/templates/windows_release_x86_64.exe'
$pinsPath = Join-Path $PSScriptRoot 'pins.json'
$utf8 = [Text.UTF8Encoding]::new($false)
$overlayNames = @('tests/full_actor_performance_probe.gd','tests/sustained_actor_driver.gd','tests/test_sustained_actor_driver.gd','tests/test_performance_phase_snapshot.gd')
$allowedGeneratedUids = @('tests/sustained_actor_driver.gd.uid','tests/test_sustained_actor_driver.gd.uid','tests/test_performance_phase_snapshot.gd.uid')
if ($Variant -eq 'positive_certificate') { $allowedGeneratedUids += @('tests/reference_positive_clearance_adapter.gd.uid','tests/test_positive_clearance_retention.gd.uid') }

function Get-Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Get-ByteSha([byte[]]$Bytes) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant() }
function Write-Json([string]$Path,$Value) { [IO.File]::WriteAllText($Path,($Value | ConvertTo-Json -Depth 20),$utf8) }
function Assert-Within([string]$Parent,[string]$Child) {
    $base = [IO.Path]::GetFullPath($Parent).TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar
    $resolved = [IO.Path]::GetFullPath($Child)
    if (-not $resolved.StartsWith($base,[StringComparison]::OrdinalIgnoreCase)) { throw "Path escaped intended root: $resolved" }
    return $resolved
}
function Get-Inventory([string]$Directory,[bool]$AllowCache=$false) {
    $result = [ordered]@{}
    foreach ($file in (Get-ChildItem -LiteralPath $Directory -Recurse -File -Force | Sort-Object FullName)) {
        $relative = [IO.Path]::GetRelativePath($Directory,$file.FullName).Replace('\','/')
        if ($relative -match '(^|/)\.godot/') {
            if ($AllowCache) { continue }
            throw 'An archived .godot cache is not source.'
        }
        $result[$relative] = Get-Sha $file.FullName
    }
    return $result
}
function Assert-SourceUnchanged($Before,$After) {
    foreach ($relative in $Before.Keys) {
        if ($After[$relative] -ne $Before[$relative]) { throw "Source changed after prepared inventory: $relative" }
    }
    foreach ($relative in $After.Keys) {
        if ($Before.Contains($relative)) { continue }
        # Import may assign only the named new workload/observer script UIDs.
        # They are generated artifacts, recorded separately, never original source.
        if ($relative -notin $allowedGeneratedUids) { throw "Unexpected generated source: $relative" }
    }
}
function Get-MeasuredClassSha([string]$Text) {
    $normalized = $Text.Replace("`r`n","`n")
    $start = $normalized.IndexOf("class MeasuredScene:`n",[StringComparison]::Ordinal)
    $end = $normalized.IndexOf("`nvar game: MeasuredScene",[StringComparison]::Ordinal)
    if ($start -lt 0 -or $end -le $start) { throw 'MeasuredScene extraction boundary missing.' }
    return Get-ByteSha ($utf8.GetBytes($normalized.Substring($start,$end-$start).TrimEnd()+"`n"))
}

foreach ($required in @($engine,$engineRuntime,$template,$pinsPath,$PSCommandPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required pinned file missing: $required" }
}
$pins = Get-Content -LiteralPath $pinsPath -Raw | ConvertFrom-Json -AsHashtable
foreach ($relative in $pins.snapshot_proof.Keys) {
    $path = Assert-Within $repoRoot (Join-Path $repoRoot $relative)
    if ((Get-Sha $path) -ne $pins.snapshot_proof[$relative]) { throw "Common observer proof changed: $relative" }
}
foreach ($relative in $pins.candidate_proof.Keys) {
    $path = Assert-Within $repoRoot (Join-Path $repoRoot $relative)
    if ((Get-Sha $path) -ne $pins.candidate_proof[$relative]) { throw "Candidate source-proof input changed: $relative" }
}
$wrapperHash = Get-Sha $PSCommandPath
if ($pins.wrapper_sha256 -ne $wrapperHash) { throw 'Wrapper hash changed; explicit review/repin required.' }
if ($pins.engine_launcher_sha256 -ne (Get-Sha $engine) -or $pins.engine_runtime_sha256 -ne (Get-Sha $engineRuntime) -or $pins.release_template_sha256 -ne (Get-Sha $template)) { throw 'Official launcher/engine/release-template pin mismatch.' }
if ($pins.overlay.Count -ne 4 -or @($pins.overlay.Keys | Where-Object { $_ -notin $overlayNames }).Count -ne 0) { throw 'Overlay must contain the three workload files and snapshot regression.' }
$overlayBytes = @{}
foreach ($relative in $overlayNames) {
    $source = Assert-Within $PSScriptRoot (Join-Path $PSScriptRoot $relative)
    $bytes = [IO.File]::ReadAllBytes($source)
    if ((Get-ByteSha $bytes) -ne $pins.overlay[$relative]) { throw "Draft overlay changed: $relative" }
    $overlayBytes[$relative] = $bytes # Publish these exact checked bytes, not a later reread.
}
$draftProbe = $utf8.GetString($overlayBytes['tests/full_actor_performance_probe.gd'])
if ($draftProbe -notmatch '(?m)^var sample_frames: int = 1080\r?$' -or $draftProbe -notmatch '(?m)^var warmup_frames: int = 120\r?$') { throw 'Fixed workload constants changed.' }
if ((Get-MeasuredClassSha $draftProbe) -ne $pins.measured_scene_sha256) { throw 'Draft MeasuredScene timing class changed.' }

$archivePin = Join-Path $PSScriptRoot 'source.zip'
if ((Get-Sha $archivePin) -ne $pins.archive_sha256) { throw 'Exact resident source archive drift.' }
$commit = 'pinned-resident-positive-certificate-'+$Variant # Descriptive only; not a Git revision.
$parent = Join-Path $repoRoot '.build/full-port/positive-certificate-performance-v2'
$runRoot = Assert-Within $parent (Join-Path $parent $RunName)
if (Test-Path -LiteralPath $runRoot) { throw "Refusing existing run/evidence directory: $runRoot" }
New-Item -ItemType Directory -Path $runRoot | Out-Null
$archive = Join-Path $runRoot 'source.zip'
$sourceRoot = Join-Path $runRoot 'source'
$project = Join-Path $sourceRoot 'game3d'
$evidence = Join-Path $runRoot 'evidence'
$userdata = Join-Path $runRoot 'userdata'
$roaming = Join-Path $userdata 'Roaming'; $local = Join-Path $userdata 'Local'
foreach ($directory in @($evidence,$roaming,$local)) { New-Item -ItemType Directory -Path $directory | Out-Null }
$provenancePath = Join-Path $evidence 'provenance.json'
$provenance = [ordered]@{
    schema=1; workload_version='sustained60_normal_input_v2_draft'; status='preparing'; acceptance=$false
    source_kind=$pins.snapshot_kind; variant=$Variant; archive_input_sha256=$pins.archive_sha256; certificate_overlay_sha256=$pins.certificate_overlay; candidate_proof_sha256=$pins.candidate_proof; snapshot_proof_sha256=$pins.snapshot_proof; source_runtime_pins=$pins.runtime_sources; performance_acceptance=$false
    measured_frames=1080; warmup_frames=120; phases=@('core_day','trainyard_night'); diagnostic=[bool]$Diagnostic
    wrapper_sha256=$wrapperHash; pins_sha256=(Get-Sha $pinsPath); overlay_sha256=$pins.overlay
    engine_launcher_sha256=$pins.engine_launcher_sha256; engine_runtime_sha256=$pins.engine_runtime_sha256; template_sha256=$pins.release_template_sha256
    measured_scene_sha256=$pins.measured_scene_sha256; archived_project=$project; evidence=$evidence
    child_userdata_environment=@{APPDATA=$roaming; LOCALAPPDATA=$local}; stages=@()
}
Write-Json $provenancePath $provenance

function Invoke-IsolatedChild([string]$Stage,[string]$Executable,[string[]]$Arguments) {
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $Executable; $startInfo.UseShellExecute = $false
    $startInfo.WorkingDirectory = $project
    $startInfo.CreateNoWindow = $true; $startInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $startInfo.RedirectStandardOutput = $true; $startInfo.RedirectStandardError = $true
    $startInfo.Environment['APPDATA'] = $roaming; $startInfo.Environment['LOCALAPPDATA'] = $local
    foreach ($argument in $Arguments) { $startInfo.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new(); $process.StartInfo = $startInfo
    $stdoutTask = $null; $stderrTask = $null
    try {
        if (-not $process.Start()) { throw "Could not start own child: $Stage" }
        $processId = $process.Id; $clock = [Diagnostics.Stopwatch]::StartNew()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync(); $stderrTask = $process.StandardError.ReadToEndAsync()
        $timedOut = $false
        while (-not $process.WaitForExit(30000)) {
            Write-Host "Sustained release $Stage remains active: PID $processId; $([int]$clock.Elapsed.TotalSeconds)s"
            if ($clock.Elapsed.TotalSeconds -ge 900) {
                $timedOut = $true; $process.Kill($true)
                if (-not $process.WaitForExit(10000)) { throw "Own child $processId did not stop within timeout grace." }
                break
            }
        }
        if (-not [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($stdoutTask,$stderrTask),10000)) { throw "Child $processId output streams did not close within timeout grace." }
        $stdout = $stdoutTask.GetAwaiter().GetResult(); $stderr = $stderrTask.GetAwaiter().GetResult()
        $exitCode = $process.ExitCode
        [IO.File]::WriteAllText((Join-Path $runRoot ($Stage+'.stdout.log')),$stdout,$utf8)
        [IO.File]::WriteAllText((Join-Path $runRoot ($Stage+'.stderr.log')),$stderr,$utf8)
        $body = ($stdout+"`n"+$stderr) -replace '\x1b\[[0-9;]*[A-Za-z]',''
        $result = [ordered]@{stage=$Stage; pid=$processId; executable=$Executable; arguments=$Arguments; exit_code=$exitCode; timeout=$timedOut; elapsed_ms=$clock.ElapsedMilliseconds}
        $logIndex = [Array]::IndexOf($Arguments,'--log-file')
        if ($logIndex -ge 0) {
            $logPath = $Arguments[$logIndex+1]
            $result.godot_log = $logPath
            $result.godot_log_exists = Test-Path -LiteralPath $logPath -PathType Leaf
            if ($result.godot_log_exists) {
                $body += "`n"+[IO.File]::ReadAllText($logPath)
                $result.godot_log_sha256 = Get-Sha $logPath
            }
        }
        $provenance.stages += $result; Write-Json $provenancePath $provenance
        if ($logIndex -ge 0 -and -not $result.godot_log_exists) { throw "Stage $Stage did not create its required Godot log." }
        if ($timedOut -or $exitCode -ne 0 -or $body -match '(?m)^\s*(?:SCRIPT ERROR|ERROR|Parse Error):') { throw "Stage $Stage failed; retained logs: $runRoot" }
        return $stdout
    } finally {
        # Interruption/stream exceptions must not leave this own child running.
        try {
            if (-not $process.HasExited) { $process.Kill($true); $null = $process.WaitForExit(10000) }
        } catch { } # Start failure has no live process to terminate.
        foreach ($stream in @(@{task=$stdoutTask; name='stdout'},@{task=$stderrTask; name='stderr'})) {
            $streamPath = Join-Path $runRoot ($Stage+'.'+$stream.name+'.log')
            if ($null -ne $stream.task -and $stream.task.IsCompletedSuccessfully -and -not (Test-Path -LiteralPath $streamPath)) {
                [IO.File]::WriteAllText($streamPath,$stream.task.GetAwaiter().GetResult(),$utf8)
            }
        }
        $process.Dispose()
    }
}

try {
    Copy-Item -LiteralPath $archivePin -Destination $archive
    if ((Get-Sha $archive) -ne $pins.archive_sha256) { throw 'Pinned archive copy failed.' }
    $provenance.archive_sha256 = Get-Sha $archive
    $zip = [IO.Compression.ZipFile]::OpenRead($archive)
    try { foreach ($entry in $zip.Entries) { $null = Assert-Within $sourceRoot (Join-Path $sourceRoot $entry.FullName) } }
    finally { $zip.Dispose() }
    Expand-Archive -LiteralPath $archive -DestinationPath $sourceRoot
    $provenance.original_source_sha256 = Get-Inventory $project
    if ($provenance.original_source_sha256.Count -ne $pins.source.Count) { throw 'Source archive census mismatch.' }
    foreach ($relative in $pins.source.Keys) { if ($provenance.original_source_sha256[$relative] -ne $pins.source[$relative]) { throw "Archive source differs: $relative" } }
    $certificateNames = @('scripts/world_adapter.gd','tests/reference_positive_clearance_adapter.gd','tests/test_positive_clearance_retention.gd')
    if ($pins.certificate_overlay.Count -ne 3 -or @($pins.certificate_overlay.Keys | Where-Object { $_ -notin $certificateNames }).Count -ne 0) { throw 'Only the three exact certificate-candidate files are allowed.' }
    foreach ($relative in $certificateNames) {
        $candidatePath = Assert-Within $PSScriptRoot (Join-Path $PSScriptRoot ('certificate/'+$relative))
        $bytes = [IO.File]::ReadAllBytes($candidatePath)
        if ((Get-ByteSha $bytes) -ne $pins.certificate_overlay[$relative]) { throw "Certificate overlay changed: $relative" }
        if ($Variant -eq 'positive_certificate') {
            $destination = Assert-Within $project (Join-Path $project $relative)
            $null = New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($destination)) -Force
            [IO.File]::WriteAllBytes($destination,$bytes)
        }
    }
    $archivedProbe = Join-Path $project 'tests/full_actor_performance_probe.gd'
    if (-not (Test-Path -LiteralPath $archivedProbe -PathType Leaf)) { throw 'Frozen revision has no source probe for timing-class comparison.' }
    if ((Get-MeasuredClassSha ([IO.File]::ReadAllText($archivedProbe))) -ne $pins.measured_scene_sha256) { throw 'Frozen timing class differs; do not silently change measurement boundary.' }
    foreach ($relative in $overlayNames) {
        $destination = Assert-Within $project (Join-Path $project $relative)
        [IO.File]::WriteAllBytes($destination,$overlayBytes[$relative])
    }
    foreach ($table in @('data/source_content.json','data/courier_canvas_metrics.json')) {
        if (-not (Test-Path -LiteralPath (Join-Path $project $table) -PathType Leaf)) { throw "Required archived data table missing: $table" }
    }
    $templateLiteral = $template.Replace('\','/')
    $preset = @"
[preset.0]
name="Windows Sustained Frozen"
platform="Windows Desktop"
runnable=false
dedicated_server=false
custom_features="full_port"
export_filter="all_resources"
include_filter="data/source_content.json,data/courier_canvas_metrics.json,tests/full_actor_performance_probe.gd,tests/sustained_actor_driver.gd,tests/test_sustained_actor_driver.gd"
exclude_filter="tools/*,web/*,tests/fixtures/*,data/parity_manifest.json"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false

[preset.0.options]
custom_template/release="$templateLiteral"
debug/export_console_wrapper=0
binary_format/embed_pck=true
binary_format/architecture="x86_64"
codesign/enable=false
application/modify_resources=false
application/export_angle=0
application/export_d3d12=0
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
shader_baker/enabled=false
"@
    [IO.File]::WriteAllText((Join-Path $project 'export_presets.cfg'),$preset,$utf8)
    $provenance.isolated_preset_sha256 = Get-Sha (Join-Path $project 'export_presets.cfg')
    $provenance.prepared_source_sha256 = Get-Inventory $project
    foreach ($relative in $provenance.original_source_sha256.Keys) {
        if ($relative -eq 'export_presets.cfg' -or $relative -in $overlayNames -or ($Variant -eq 'positive_certificate' -and $relative -in $certificateNames)) { continue }
        if ($provenance.prepared_source_sha256[$relative] -ne $provenance.original_source_sha256[$relative]) { throw "Unexpected archived source mutation: $relative" }
    }
    $provenance.status = 'building'; Write-Json $provenancePath $provenance
    $version = (Invoke-IsolatedChild 'version' $engine @('--version')).Trim()
    if ($version -notmatch '^4\.5\.1\.stable\.official(?:\.|$)') { throw "Unexpected official engine version: $version" }
    $provenance.engine = $version
    $null = Invoke-IsolatedChild 'import' $engine @('--headless','--path',$project,'--log-file',(Join-Path $runRoot 'import.godot.log'),'--editor','--import','--quit')
    $contract = Invoke-IsolatedChild 'contract' $engine @('--headless','--path',$project,'--log-file',(Join-Path $runRoot 'contract.godot.log'),'--script','res://tests/test_sustained_actor_driver.gd')
    if ($contract -notmatch 'SUSTAINED60 DRIVER CONTRACT: PASS') { throw 'Detached contract did not complete all required groups.' }
    $snapshot = Invoke-IsolatedChild 'snapshot_contract' $engine @('--headless','--path',$project,'--log-file',(Join-Path $runRoot 'snapshot_contract.godot.log'),'--script','res://tests/test_performance_phase_snapshot.gd')
    if ($snapshot -notmatch '(?m)^PERFORMANCE PHASE SNAPSHOT: PASS; [1-9][0-9]* checks; 5/5 groups; original_alias_reproduced=true; no performance claim\r?$') { throw 'Snapshot contract did not complete all five groups and original alias witness.' }
    $provenance.snapshot_contract_complete = $true
    if ($Variant -eq 'positive_certificate') {
        $retention = Invoke-IsolatedChild 'retention_contract' $engine @('--headless','--path',$project,'--log-file',(Join-Path $runRoot 'retention_contract.godot.log'),'--script','res://tests/test_positive_clearance_retention.gd')
        if ($retention -notmatch '(?m)^POSITIVE CLEARANCE RETENTION: PASS; [1-9][0-9]* checks; 6/6 groups; focused_saved_queries=2; no performance claim\r?$') { throw 'Actual certificate contract did not finish all six groups and both saved-query witnesses.' }
        $provenance.retention_contract_complete = $true
    }
    $provenance.exported_source_sha256 = Get-Inventory $project $true
    Assert-SourceUnchanged $provenance.prepared_source_sha256 $provenance.exported_source_sha256
    $executable = Join-Path $runRoot 'RockBottomSustained.exe'
    if (Test-Path -LiteralPath $executable) { throw 'Refusing existing executable.' }
    $null = Invoke-IsolatedChild 'export' $engine @('--headless','--path',$project,'--log-file',(Join-Path $runRoot 'export.godot.log'),'--export-release','Windows Sustained Frozen',$executable)
    Assert-SourceUnchanged $provenance.exported_source_sha256 (Get-Inventory $project $true)
    if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) { throw 'Official release export is missing.' }
    $provenance.executable = $executable; $provenance.executable_sha256 = Get-Sha $executable
    $nativeLog = Join-Path $evidence 'native.log'
    $nativeArguments = @('--log-file',$nativeLog,'--script','res://tests/full_actor_performance_probe.gd','--','--qa-full',('--output='+$evidence))
    if ($Diagnostic) { $nativeArguments += '--diagnostic' }
    $provenance.native_arguments = $nativeArguments; $provenance.status = 'running'; Write-Json $provenancePath $provenance
    Write-Output "Sustained frozen $commit; fixed120+1080 per phase. Evidence: $evidence"
    $null = Invoke-IsolatedChild 'native' $executable $nativeArguments
    $provenance.post_native_source_sha256 = Get-Inventory $project $true
    Assert-SourceUnchanged $provenance.exported_source_sha256 $provenance.post_native_source_sha256
    if ((Get-Sha $archive) -ne $pins.archive_sha256 -or (Get-Sha $archivePin) -ne $pins.archive_sha256) { throw 'Source archive changed during run.' }
    $reportPath = Join-Path $evidence 'full-actor-performance.json'
    if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) { throw 'Native report missing.' }
    $nativeBody = if (Test-Path -LiteralPath $nativeLog) { Get-Content -LiteralPath $nativeLog -Raw } else { '' }
    if ($nativeBody -match '(?m)^\s*(?:SCRIPT ERROR|ERROR|Parse Error):') { throw 'Godot native log contains errors despite process exit.' }
    $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json -AsHashtable
    $provenance.report_sha256 = Get-Sha $reportPath
    if ($report.schema -ne 1 -or $report.acceptance -isnot [bool] -or $report.failures -isnot [array] -or $report.phases -isnot [array] -or $report.diagnostic -ne [bool]$Diagnostic) { throw 'Report schema/diagnostic contract mismatch.' }
    $complete = $report.workload_version -eq 'sustained60_normal_input_v2_draft' -and $report.fixed_measured_frames -eq 1080 -and $report.fixed_warmup_frames -eq 120 -and $report.phases.Count -eq 2
    $expectedPhases = @('core_day','trainyard_night')
    for ($index=0; $index -lt $report.phases.Count; $index++) {
        $phase = $report.phases[$index]
        $complete = $complete -and $index -lt 2 -and $phase.id -eq $expectedPhases[$index] -and $phase.frames -eq 1080 -and $phase.warmup_frames -eq 120
    }
    foreach ($phase in $report.phases) {
        if ($phase.min_live_actors -lt 60 -or $phase.min_supported_live_actors -lt 60 -or $phase.min_live_rigs -lt 60) { throw 'Sustained60 population requirement failed.' }
    }
    foreach ($failure in $report.failures) {
        if ($failure -notin @('core_day: scene CPU or held engine-process monitor p95 exceeds16ms','trainyard_night: scene CPU or held engine-process monitor p95 exceeds16ms')) { throw "Non-performance workload failure: $failure" }
    }
    $provenance.complete_fixed_workload = [bool]$complete; $provenance.original_probe_acceptance = $report.acceptance -eq $true; $provenance.acceptance = $false
    $provenance.failures = $report.failures
    if ($report.acceptance -ne ($report.failures.Count -eq 0 -and $report.phases.Count -eq 2)) { throw 'Report acceptance contradicts its failure list.' }
    $provenance.status = 'complete' ; Write-Json $provenancePath $provenance
    if (-not $complete) { throw 'Fixed workload incomplete; retained report is not a paired result.' }
    foreach ($phase in $report.phases) { Write-Output ('{0}: scene p95={1}ms; live minimum={2}' -f $phase.id,$phase.scene_cpu_ms.p95,$phase.min_live_actors) }
    Write-Output "SUSTAINED RELEASE: acceptance=$($report.acceptance); diagnostic=$Diagnostic; evidence=$evidence"
    if (-not $Diagnostic -and $report.acceptance -ne $true) { throw 'Performance/population acceptance remains false.' }
} catch {
    $provenance.status = 'failed'; $provenance.error = $_.Exception.Message
    Write-Json $provenancePath $provenance
    throw
}
