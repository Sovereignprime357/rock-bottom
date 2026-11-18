[CmdletBinding()]
param([ValidateRange(1024,65535)][int]$Port = 8073,
    [ValidateSet('Slice','Full')][string]$Entry = 'Slice')

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$webRoot = Join-Path $repoRoot '.build/3d/web'
if ($Entry -eq 'Full') { $webRoot = Join-Path $repoRoot '.build/3d/full/web' }
$htmlPath = Join-Path $webRoot 'index.html'
if (-not (Test-Path -LiteralPath $htmlPath)) { throw 'Build the Web export before starting the local preview.' }
$url = "http://127.0.0.1:$Port/"
$expected = [IO.File]::ReadAllText($htmlPath)
try {
    $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 2
    if ($response.Content -eq $expected) {
        Write-Output "3D PREVIEW: already serving $url"
        return
    }
    throw "Port $Port serves different content. Choose another -Port; no existing process was stopped."
} catch {
    if ($_.Exception.Message -like '*serves different content*') { throw }
}
$python = (Get-Command python -ErrorAction Stop).Source
$logRoot = Join-Path $repoRoot '.build/3d'
if ($Entry -eq 'Full') { $logRoot = Join-Path $logRoot 'full' }
$arguments = @('-m','http.server',"$Port",'--bind','127.0.0.1','--directory',('"{0}"' -f $webRoot))
# A detached hidden helper survives the interactive command session. It is local
# to this PC and does not install a service, startup task or public hosting.
$server = Start-Process -FilePath $python -ArgumentList $arguments -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput (Join-Path $logRoot 'web-server.stdout.log') `
    -RedirectStandardError (Join-Path $logRoot 'web-server.stderr.log')
[IO.File]::WriteAllText((Join-Path $logRoot 'web-server.pid'), [string]$server.Id)
for ($attempt = 0; $attempt -lt 10; $attempt++) {
    Start-Sleep -Milliseconds 200
    if ($server.HasExited) { throw 'Preview server exited; see .build/3d/web-server.stderr.log.' }
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 2
        if ($response.Content -eq $expected) {
            Write-Output "3D PREVIEW: $url (background process $($server.Id))"
            return
        }
    } catch { }
}
throw 'Preview did not respond with the exported HTML; inspect the local server logs.'
