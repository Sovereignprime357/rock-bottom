[CmdletBinding()]
param(
    [string]$Revision = 'HEAD',
    [ValidateRange(120,1200)][int]$Frames = 1080,
    [switch]$Diagnostic
)

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$engine = Join-Path $repoRoot '.tools/godot-4.5.1/Godot_v4.5.1-stable_win64_console.exe'
$template = Join-Path $repoRoot '.tools/templates/windows_release_x86_64.exe'
foreach ($required in @($engine,$template)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required official binary missing: $required" }
}
$version = (& $engine --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $version -notmatch '^4\.5\.1\.stable(?:\.|$)') { throw "Unexpected engine: $version" }
$commit = (& git -C $repoRoot rev-parse --verify --end-of-options ($Revision + '^{commit}') | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[a-f0-9]{40}$') { throw 'A valid committed revision is required.' }
$runName = $commit.Substring(0,12) + '-' + [guid]::NewGuid().ToString('N').Substring(0,8)
$runRoot = Join-Path $repoRoot ('.build/full-port/release-profile/' + $runName)
New-Item -ItemType Directory -Path $runRoot | Out-Null
$archive = Join-Path $runRoot 'source.zip'
& git -C $repoRoot archive --format=zip ('--output=' + $archive) $commit -- game3d
if ($LASTEXITCODE -ne 0) { throw 'Committed source archive failed.' }
Expand-Archive -LiteralPath $archive -DestinationPath (Join-Path $runRoot 'source')
$project = Join-Path $runRoot 'source/game3d'
$probeSource = Join-Path $project 'tests/full_actor_performance_probe.gd'
if (-not (Test-Path -LiteralPath $probeSource -PathType Leaf)) { throw 'Selected revision has no full actor probe.' }
$sourceHashes = [ordered]@{}
Get-ChildItem -LiteralPath $project -Recurse -File | Where-Object { $_.Extension -in @('.gd','.godot','.cfg','.json') } | Sort-Object FullName | ForEach-Object {
    $relative = [IO.Path]::GetRelativePath($project,$_.FullName).Replace('\','/')
    $sourceHashes[$relative] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
}
$templateLiteral = $template.Replace('\','/')
$preset = @"
[preset.0]
name="Windows Full Profile"
platform="Windows Desktop"
runnable=false
dedicated_server=false
custom_features="full_port"
export_filter="all_resources"
include_filter="data/source_content.json"
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
[IO.File]::WriteAllText((Join-Path $project 'export_presets.cfg'),$preset,[Text.UTF8Encoding]::new($false))

function Invoke-ProfileBuild {
    param([string]$Stage,[string[]]$Arguments)
    $log = Join-Path $runRoot ($Stage + '.log')
    Write-Output "Release profile: $Stage ($commit)"
    $priorPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $lines = @(& $engine --headless --path $project --log-file $log @Arguments 2>&1)
        $stageExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = $priorPreference }
    $body = ($lines | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $body = $body -replace '\x1b\[[0-9;]*[A-Za-z]', ''
    [IO.File]::WriteAllText($log,$body,[Text.UTF8Encoding]::new($false))
    if ($stageExit -ne 0 -or $body -match '(?m)^\s*(?:SCRIPT ERROR|ERROR|Parse Error):') { throw "Profile $Stage failed. See $log" }
}

Invoke-ProfileBuild 'import' @('--editor','--import','--quit')
$executable = Join-Path $runRoot 'RockBottomProfile.exe'
Invoke-ProfileBuild 'export' @('--export-release','Windows Full Profile',$executable)
if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) { throw 'Release export is missing.' }
$evidence = Join-Path $runRoot 'evidence'
New-Item -ItemType Directory -Path $evidence | Out-Null
$log = Join-Path $evidence 'native.log'
$arguments = @('--log-file',('"' + $log + '"'),'--script','res://tests/full_actor_performance_probe.gd','--','--qa-full',('--frames=' + $Frames),('"--output=' + $evidence + '"'))
if ($Diagnostic) { $arguments += '--diagnostic' }
$provenance = [ordered]@{
    revision=$commit; engine=$version; frames=$Frames; diagnostic=[bool]$Diagnostic
    engine_sha256=(Get-FileHash -LiteralPath $engine -Algorithm SHA256).Hash.ToLowerInvariant()
    template_sha256=(Get-FileHash -LiteralPath $template -Algorithm SHA256).Hash.ToLowerInvariant()
    executable_sha256=(Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash.ToLowerInvariant()
    executable=$executable; archived_project=$project; evidence=$evidence
    isolated_preset_sha256=(Get-FileHash -LiteralPath (Join-Path $project 'export_presets.cfg') -Algorithm SHA256).Hash.ToLowerInvariant()
    source_sha256=$sourceHashes
}
$provenance | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $evidence 'provenance.json') -Encoding utf8
Write-Output "Release profile: running $Frames measured frames per phase. Evidence: $evidence"
$process = Start-Process -FilePath $executable -ArgumentList $arguments -WindowStyle Hidden -PassThru
while (-not $process.WaitForExit(30000)) { Write-Output "Release profile remains active: $($process.Id)" }
$body = if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log -Raw } else { '' }
$reportPath = Join-Path $evidence 'full-actor-performance.json'
if ($process.ExitCode -ne 0 -or $body -match '(?m)^\s*(?:SCRIPT ERROR|ERROR|Parse Error):' -or -not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
    if ($body) { Write-Output ($body -split "`n" | Select-Object -Last 20) }
    throw "Release probe failed (exit $($process.ExitCode)). Evidence: $evidence"
}
$report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
Write-Output ($report.phases | ForEach-Object { '{0}: scene p95={1}ms; engine p95={2}ms' -f $_.id,$_.scene_cpu_ms.p95,$_.engine_process_ms.p95 })
Write-Output "RELEASE PROFILE: acceptance=$($report.acceptance); diagnostic=$Diagnostic; evidence=$evidence"
if (-not $Diagnostic -and -not $report.acceptance) { throw 'Release performance is not accepted.' }
