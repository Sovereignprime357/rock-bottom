#requires -Version 7.2
[CmdletBinding()]
param([Parameter(Mandatory)][ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$')][string]$RunName)
$ErrorActionPreference='Stop'
$repoRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$runRoot=Join-Path $repoRoot ('.build/full-port/dave-sleep-validation/'+$RunName)
$utf8=[Text.UTF8Encoding]::new($false)
$stageScript=Join-Path $PSScriptRoot 'stage.py'
& python $stageScript --run $RunName --mode Focused
if($LASTEXITCODE-ne 0){throw 'Fresh stage preparation failed'}
$manifest=Get-Content -LiteralPath (Join-Path $runRoot 'staging.json') -Raw|ConvertFrom-Json -AsHashtable
$result=[ordered]@{schema=1;status='running';staging_sha256=(Get-FileHash -LiteralPath (Join-Path $runRoot 'staging.json') -Algorithm SHA256).Hash.ToLowerInvariant();stages=@();engine_tests_pass=$false;visual_acceptance=$false;performance_acceptance=$false}
function SaveResult{[IO.File]::WriteAllText((Join-Path $runRoot 'focused-result.json'),($result|ConvertTo-Json -Depth 20),$utf8)}
function VerifySource{
 & python $stageScript --verify $runRoot
 if($LASTEXITCODE-ne 0){throw 'Prepared source verification failed'}
}
function RunStage($row){
 VerifySource
 if((Get-FileHash -LiteralPath $row.executable -Algorithm SHA256).Hash.ToLowerInvariant()-ne $manifest.engine_sha256){throw 'Engine hash changed'}
 $info=[Diagnostics.ProcessStartInfo]::new();$info.FileName=$row.executable;$info.WorkingDirectory=$manifest.project
 $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
 $info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
 foreach($argument in $row.arguments){$info.ArgumentList.Add([string]$argument)}
 foreach($pair in @(@('APPDATA','Roaming'),@('LOCALAPPDATA','Local'))){$path=Join-Path $runRoot ('userdata/'+$row.name+'/'+$pair[1]);New-Item -ItemType Directory -Path $path -Force|Out-Null;$info.Environment[$pair[0]]=$path}
 $child=[Diagnostics.Process]::new();$child.StartInfo=$info;$stdout=$null;$stderr=$null;$watch=[Diagnostics.Stopwatch]::StartNew()
 try{
  if(-not $child.Start()){throw 'Owned child launch failed'}
  $stdout=$child.StandardOutput.ReadToEndAsync();$stderr=$child.StandardError.ReadToEndAsync()
  while(-not $child.WaitForExit(10000)){Write-Host "$($row.name) active: $([int]$watch.Elapsed.TotalSeconds)s";if($watch.Elapsed.TotalSeconds-ge 600){$child.Kill($true);$null=$child.WaitForExit(10000);throw 'Owned stage timeout'}}
  if(-not [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($stdout,$stderr),10000)){throw 'Owned output streams did not close'}
  $out=$stdout.GetAwaiter().GetResult();$err=$stderr.GetAwaiter().GetResult();$joined=$out+"`n"+$err
  [IO.File]::WriteAllText((Join-Path $runRoot ($row.name+'.stdout.log')),$out,$utf8)
  [IO.File]::WriteAllText((Join-Path $runRoot ($row.name+'.stderr.log')),$err,$utf8)
  $result.stages+=@{name=$row.name;pid=$child.Id;arguments=$row.arguments;exit_code=$child.ExitCode;elapsed_ms=$watch.ElapsedMilliseconds};SaveResult
  VerifySource
  if($child.ExitCode-ne 0 -or $joined-match '(?im)^\s*(?:SCRIPT ERROR|ERROR|Parse Error):|ObjectDB instances leaked|resources still in use at exit|\bGATE: FAIL|DAVE (?:SLEEP SUPPORT|WALKTHROUGH CONTRACT): FAIL'){throw "Stage failed: $($row.name); raw output retained"}
  if($null-ne $row.pass_marker -and -not $joined.Contains([string]$row.pass_marker)){throw "Missing completion marker: $($row.name)"}
 }finally{
  try{if(-not $child.HasExited){$child.Kill($true);$null=$child.WaitForExit(10000)}}catch{}
  foreach($stream in @(@{task=$stdout;name='stdout'},@{task=$stderr;name='stderr'})){if($null-ne $stream.task -and $stream.task.IsCompletedSuccessfully){$path=Join-Path $runRoot ($row.name+'.'+$stream.name+'.log');if(-not(Test-Path -LiteralPath $path)){[IO.File]::WriteAllText($path,$stream.task.GetAwaiter().GetResult(),$utf8)}}}
  $child.Dispose()
 }
}
try{
 if($manifest.mode-ne 'Focused' -or $manifest.commands.Count-ne 6){throw 'Expected one import and five tests'}
 SaveResult
 foreach($row in $manifest.commands){RunStage $row}
 $result.status='pass';$result.engine_tests_pass=$true;SaveResult
 Write-Output "DAVE SLEEP FOCUSED: PASS 5/5; $runRoot; rendered acceptance remains pending"
}catch{$result.status='failed';$result.error=$_.Exception.Message;SaveResult;throw}
