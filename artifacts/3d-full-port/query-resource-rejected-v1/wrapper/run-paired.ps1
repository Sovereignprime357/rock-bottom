#requires -Version 7.2
[CmdletBinding()]
param([Parameter(Mandatory)][ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9_-]{0,46}$')][string]$RunName)
$ErrorActionPreference='Stop'
$pins=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'pins.json') -Raw|ConvertFrom-Json -AsHashtable
if((Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $pins.paired_wrapper_sha256){throw 'Paired wrapper pin changed.'}
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$parent=Join-Path $repo '.build/full-port/query-resource-performance'
$summaryPath=Join-Path $parent ($RunName+'-comparison.json')
if((Test-Path -LiteralPath $summaryPath) -or (Test-Path -LiteralPath (Join-Path $parent ($RunName+'-baseline'))) -or (Test-Path -LiteralPath (Join-Path $parent ($RunName+'-query_resource')))){throw 'All paired output paths must be fresh.'}
# In-process sequential script calls; each reviewed child launcher owns its own hidden children.
foreach($variant in @('baseline','query_resource')){& (Join-Path $PSScriptRoot 'profile-one.ps1') -Variant $variant -RunName ($RunName+'-'+$variant)}
$helper=Join-Path $PSScriptRoot 'compare-pair.py'
if((Get-FileHash -LiteralPath $helper -Algorithm SHA256).Hash.ToLowerInvariant() -ne $pins.comparison_helper_sha256){throw 'Comparison helper changed.'}
& python $helper --run-name $RunName
if($LASTEXITCODE -ne 0){throw 'Strict diagnostic comparison refused the pair; raw run evidence retained.'}
Write-Output "QUERY RESOURCE PERFORMANCE PAIR: complete diagnostic; original failure lists retained; $summaryPath"
