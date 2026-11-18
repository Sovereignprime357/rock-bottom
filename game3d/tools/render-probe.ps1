[CmdletBinding()]
param(
    [string]$Project = '',
    [string]$Output = '',
    [switch]$Stress
)

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $Project) { $Project = Join-Path $repoRoot 'game3d' }
if (-not $Output) { $Output = Join-Path $repoRoot '.build/art-pass/current' }
$Project = (Resolve-Path -LiteralPath $Project).Path
$Output = [IO.Path]::GetFullPath($Output)
$engine = Join-Path $repoRoot '.tools/godot-4.5.1/Godot_v4.5.1-stable_win64.exe'
if (-not (Test-Path -LiteralPath $engine)) { throw 'Pinned Godot 4.5.1 executable is missing.' }
New-Item -ItemType Directory -Force -Path $Output | Out-Null
$probeLog = Join-Path $Output 'render-probe.log'
$arguments = @('--path', ('"{0}"' -f $Project), '--script', 'res://tests/render_probe.gd',
    '--log-file', ('"{0}"' -f $probeLog), '--', ('"--output={0}"' -f $Output))
if ($Stress) { $arguments += '--stress' }
$probe = Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru
if (-not $probe.WaitForExit(90000)) {
    $probe.Kill()
    throw 'Owned render probe timed out after 90 seconds.'
}
$lines = Get-Content -LiteralPath $probeLog -Raw
Write-Output $lines
if ($probe.ExitCode -ne 0 -or $lines -match '(?m)^\s*(?:SCRIPT ERROR|ERROR|Parse Error):' -or
    $lines -notmatch '3D RENDER PROBE: PASS') {
    throw "Render probe failed. See $probeLog"
}
