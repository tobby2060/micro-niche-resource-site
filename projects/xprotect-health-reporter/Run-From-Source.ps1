#requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot 'Get-XProtectHealthReport.ps1'
& (Join-Path $PSScriptRoot 'Build-XProtectHealthReporter.ps1') -OutputPath $scriptPath
& $scriptPath @args
exit $LASTEXITCODE
