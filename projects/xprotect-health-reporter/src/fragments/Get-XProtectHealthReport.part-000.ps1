#requires -Version 5.1
<#
.SYNOPSIS
    Creates a point-in-time XProtect hardware and camera health report.

.DESCRIPTION
    Uses the official MilestonePSTools module to collect all hardware and camera
    configuration, current recorder-side status, stream information, storage
    information, and optional retention / recording statistics.

    Output is written to a timestamped folder as:
      - XProtect-Health-Report.html
      - XProtect-Camera-Status.csv
      - XProtect-Hardware-Status.csv
      - XProtect-Camera-Inventory-Full.csv
      - XProtect-Run-Summary.json

    No camera passwords are requested or exported.

.NOTES
    Run with Windows PowerShell 5.1 (powershell.exe), not PowerShell 7 (pwsh.exe).
    Recorder-side status requires TCP 7563 from the computer running this script
    to each XProtect Recording Server.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [uri]$ServerAddress,

    [Parameter()]
    [pscredential]$Credential,

    [Parameter()]
    [switch]$BasicUser,

    [Parameter()]
    [switch]$SecureOnly,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ConnectionProfile = 'default',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'XProtectReports'),

    [Parameter()]
    [switch]$IncludeRetentionInfo,

    [Parameter()]
    [switch]$IncludeRecordingStats,

    [Parameter()]
    [switch]$InstallModule,

    [Parameter()]
    [switch]$OpenReport
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Get-XpProperty {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        $Object,

        [Parameter(Mandatory)]
        [string[]]$Name,

        [Parameter()]
        [AllowNull()]
        $Default = $null
    )

    if ($null -eq $Object) {
        return $Default
    }

    foreach ($propertyName in $Name) {
        $property = $Object.PSObject.Properties[$propertyName]
        if (($null -ne $property) -and ($null -ne $property.Value)) {
            return $property.Value
        }
    }

    return $Default
}

function ConvertTo-XpBool {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [bool]) {
        return [bool]$Value
    }

    $parsed = $false
    if ([bool]::TryParse([string]$Value, [ref]$parsed)) {
        return $parsed
    }

    switch -Regex ([string]$Value) {
        '^(1|yes|y|on|enabled)$'  { return $true }
        '^(0|no|n|off|disabled)$' { return $false }
        default                   { return $null }
    }
}

function Get-XpKey {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return ''
    }

    return ([string]$Value).Trim().ToLowerInvariant()
}

function ConvertTo-XpDisplayText {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return ''
    }

    if ($Value -is [datetime]) {
        return $Value.ToString('yyyy-MM-dd HH:mm:ss')
    }

    if ($Value -is [bool]) {
        if ($Value) { return 'Yes' }
        return 'No'
    }

    if (($Value -is [System.Collections.IEnumerable]) -and -not ($Value -is [string])) {
        return (($Value | ForEach-Object { [string]$_ }) -join ', ')
    }

    return [string]$Value
}

function ConvertTo-XpHtmlText {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        $Value
    )

    $displayValue = ConvertTo-XpDisplayText -Value $Value
    return [System.Net.WebUtility]::HtmlEncode($displayValue)
}

function Get-XpStatusSlug {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        $Status
    )

    $slug = ([string]$Status).Trim().ToLowerInvariant() -replace '[^a-z0-9]+', '-'
    $slug = $slug.Trim('-')
    if ([string]::IsNullOrWhiteSpace($slug)) {
        return 'unknown'
    }
    return $slug
}

function Get-XpCameraHealth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Camera
    )

    $enabled = ConvertTo-XpBool (Get-XpProperty -Object $Camera -Name @('Enabled'))
    $started = ConvertTo-XpBool (Get-XpProperty -Object $Camera -Name @('IsStarted', 'Started'))
    $overflow = ConvertTo-XpBool (Get-XpProperty -Object $Camera -Name @('IsInOverflow', 'ErrorOverflow'))
    $dbRepair = ConvertTo-XpBool (Get-XpProperty -Object $Camera -Name @('IsInDbRepair', 'DbRepairInProgress'))
    $writeError = ConvertTo-XpBool (Get-XpProperty -Object $Camera -Name @('ErrorWritingGOP', 'ErrorWritingGop'))
    $notLicensed = ConvertTo-XpBool (Get-XpProperty -Object $Camera -Name @('ErrorNotLicensed'))
    $noConnection = ConvertTo-XpBool (Get-XpProperty -Object $Camera -Name @('ErrorNoConnection'))
    $genericError = ConvertTo-XpBool (Get-XpProperty -Object $Camera -Name @('Error'))
    $statusTime = Get-XpProperty -Object $Camera -Name @('StatusTime', 'Time')
    $eventState = [string](Get-XpProperty -Object $Camera -Name @('State') -Default '')

    if ($enabled -eq $false) {
        return [pscustomobject][ordered]@{
            Status   = 'DISABLED'
            Severity = 900
            Online   = 'N/A'
            Issue    = 'Camera or parent hardware is disabled in XProtect'
        }
    }

    if ($notLicensed -eq $true) {
        return [pscustomobject][ordered]@{
            Status   = 'UNLICENSED'
            Severity = 10
            Online   = 'No'
            Issue    = 'Device is not licensed or its grace period has expired'
        }
    }

    if ($noConnection -eq $true) {
        return [pscustomobject][ordered]@{
            Status   = 'OFFLINE'
            Severity = 20
            Online   = 'No'
            Issue    = 'Recording Server cannot receive the camera stream'
        }
    }

    if (($writeError -eq $true) -or ($overflow -eq $true)) {
        $issues = New-Object 'System.Collections.Generic.List[string]'
        if ($writeError -eq $true) { $issues.Add('Recording Server cannot write GOP data to the media database') }
        if ($overflow -eq $true) { $issues.Add('Storage is not keeping up with incoming media') }
        return [pscustomobject][ordered]@{
            Status   = 'STORAGE ERROR'
            Severity = 30
            Online   = 'Yes'
            Issue    = ($issues -join '; ')
        }
    }

    if ($dbRepair -eq $true) {
        return [pscustomobject][ordered]@{
            Status   = 'DB REPAIR'
            Severity = 40
            Online   = 'Yes'
            Issue    = 'Recording Server is repairing the camera media database'
        }
    }

    if ($eventState -match '(?i)offline|not.?respond|connection.?lost|unavailable|stopped') {
        return [pscustomobject][ordered]@{
            Status   = 'NOT STARTED'
            Severity = 50
            Online   = 'No'
            Issue    = 'Event Server reports that the enabled camera is not responding or stopped'
        }
    }

    # A false value alone is not proof that a recorder status request succeeded;
    # some failed requests can leave default Boolean values behind. StatusTime,
    # a positive Started result, or a true fault flag proves status was returned.
    $hasRecorderStatus = ($null -ne $statusTime) -or ($started -eq $true) -or
                         ($noConnection -eq $true) -or ($notLicensed -eq $true) -or
                         ($writeError -eq $true) -or ($overflow -eq $true) -or
                         ($dbRepair -eq $true) -or ($genericError -eq $true)

    if (-not $hasRecorderStatus) {
        return [pscustomobject][ordered]@{
            Status   = 'UNKNOWN'
            Severity = 70
            Online   = 'Unknown'
            Issue    = 'Recorder-side status was unavailable; verify TCP 7563 to the Recording Server'
        }
    }

    if ($started -eq $false) {
        return [pscustomobject][ordered]@{
