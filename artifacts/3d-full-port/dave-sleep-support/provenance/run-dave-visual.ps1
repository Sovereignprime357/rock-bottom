# Root-owned finite runner for already-staged Dave visual commands.
param([Parameter(Mandatory)][string]$RunRoot)
$ErrorActionPreference='Stop'
$rootPath=(Resolve-Path -LiteralPath $RunRoot).Path
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$stage=Join-Path $repo '.build/3d/dave-sleep-validation-draft/stage.py'
$manifest=Get-Content -LiteralPath (Join-Path $rootPath 'staging.json') -Raw|ConvertFrom-Json
if($manifest.mode -notin @('Native','Web') -or $manifest.commands.Count -ne 2){throw 'Unexpected visual stage'}
$resultPath=Join-Path $rootPath 'root-run.json'
if(Test-Path -LiteralPath $resultPath){throw 'Retain prior run; fresh output required'}
$utf8=[Text.UTF8Encoding]::new($false)
$result=[ordered]@{mode=$manifest.mode;status='running';stages=@()}
function SaveResult { [IO.File]::WriteAllText($resultPath,($result|ConvertTo-Json -Depth 15),$utf8) }
SaveResult
try {
 foreach($row in $manifest.commands){
  & python $stage --verify $rootPath
  if($LASTEXITCODE -ne 0){throw 'Staged source changed'}
  if((Get-FileHash -LiteralPath $row.executable -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifest.engine_sha256){throw 'Engine changed'}
  $log=Join-Path $rootPath ($row.name+'.godot.log')
  $arguments=[Collections.Generic.List[string]]::new()
  $arguments.Add('--log-file');$arguments.Add($log)
  foreach($item in $row.arguments){$arguments.Add([string]$item)}
  $psi=[Diagnostics.ProcessStartInfo]::new();$psi.FileName=$row.executable;$psi.WorkingDirectory=$manifest.project
  $psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
  $psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
  foreach($item in $arguments){$psi.ArgumentList.Add($item)}
  foreach($pair in @(@('APPDATA','Roaming'),@('LOCALAPPDATA','Local'))){$local=Join-Path $rootPath ('userdata/'+$row.name+'/'+$pair[1]);New-Item -ItemType Directory -Path $local -Force|Out-Null;$psi.Environment[$pair[0]]=$local}
  $child=[Diagnostics.Process]::new();$child.StartInfo=$psi;$watch=[Diagnostics.Stopwatch]::StartNew();$stdout=$null;$stderr=$null
  try {
   if(-not $child.Start()){throw 'Child failed to launch'}
   $stdout=$child.StandardOutput.ReadToEndAsync();$stderr=$child.StandardError.ReadToEndAsync()
   $limit=if($row.name -eq 'native'){180}else{300}
   while(-not $child.WaitForExit(10000)){Write-Output "$($row.name) active $([int]$watch.Elapsed.TotalSeconds)s";if($watch.Elapsed.TotalSeconds -gt $limit){throw 'Finite child timeout'}}
   $child.WaitForExit()
   $out=$stdout.GetAwaiter().GetResult();$err=$stderr.GetAwaiter().GetResult()
   [IO.File]::WriteAllText((Join-Path $rootPath ($row.name+'.stdout.log')),$out,$utf8)
   [IO.File]::WriteAllText((Join-Path $rootPath ($row.name+'.stderr.log')),$err,$utf8)
   $result.stages+=@{name=$row.name;pid=$child.Id;exit_code=$child.ExitCode;elapsed_ms=$watch.ElapsedMilliseconds;arguments=@($arguments)};SaveResult
   $raw=$out+"`n"+$err+"`n"+(Get-Content -LiteralPath $log -Raw)
   if($child.ExitCode -ne 0 -or $raw -match '(?im)^\s*(SCRIPT ERROR|ERROR|Parse Error):'){throw "Stage failed: $($row.name)"}
   if($row.pass_marker -and -not $raw.Contains($row.pass_marker)){throw 'Missing completion marker'}
   Write-Output ($out -split "`n" | Select-Object -Last 4)
  } finally {
   try{if(-not $child.HasExited){$child.Kill($true);$null=$child.WaitForExit(10000)}}catch{}
   foreach($stream in @(@{task=$stdout;name='stdout'},@{task=$stderr;name='stderr'})){if($null -ne $stream.task -and $stream.task.IsCompletedSuccessfully){$path=Join-Path $rootPath ($row.name+'.'+$stream.name+'.log');if(-not(Test-Path -LiteralPath $path)){[IO.File]::WriteAllText($path,$stream.task.GetAwaiter().GetResult(),$utf8)}}}
   $child.Dispose()
  }
  & python $stage --verify $rootPath
  if($LASTEXITCODE -ne 0){throw 'Staged source changed after execution'}
 }
 $result.status='pass';SaveResult
 Write-Output "DAVE $($manifest.mode) COMMANDS: PASS; visual review separate"
}catch{$result.status='failed';$result.error=$_.Exception.Message;SaveResult;throw}
