#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path $PSScriptRoot 'Get-XProtectHealthReport.ps1')
)

$ErrorActionPreference = 'Stop'
$fragmentPath = Join-Path $PSScriptRoot 'src\fragments'
$fragments = @(Get-ChildItem -LiteralPath $fragmentPath -Filter 'Get-XProtectHealthReport.part-*.ps1' -File | Sort-Object Name)

if ($fragments.Count -eq 0) {
    throw "No source fragments were found under $fragmentPath"
}

$builder = New-Object System.Text.StringBuilder
foreach ($fragment in $fragments) {
    [void]$builder.Append([IO.File]::ReadAllText($fragment.FullName, [Text.Encoding]::UTF8))
}

[IO.File]::WriteAllText($OutputPath, $builder.ToString(), (New-Object Text.UTF8Encoding($false)))
Write-Host "Rebuilt: $OutputPath"
