            $propertyName = [string](Get-XpProperty -Object $column -Name @('Property'))
            $value = Get-XpProperty -Object $item -Name @($propertyName)

            if ($propertyName -eq 'Status') {
                [void]$builder.AppendLine(('<td><span class="badge badge-{0}">{1}</span></td>' -f $statusSlug, (ConvertTo-XpHtmlText $value)))
            }
            else {
                [void]$builder.AppendLine(('<td>{0}</td>' -f (ConvertTo-XpHtmlText $value)))
            }
        }

        [void]$builder.AppendLine('</tr>')
    }

    [void]$builder.AppendLine('</tbody></table></div>')
    return $builder.ToString()
}

if ($PSVersionTable.PSEdition -ne 'Desktop') {
    throw 'MilestonePSTools requires Windows PowerShell 5.1. Run this script using powershell.exe, not pwsh.exe.'
}

if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    throw ('PowerShell language mode is {0}. MilestonePSTools requires FullLanguage mode.' -f $ExecutionContext.SessionState.LanguageMode)
}

if ($BasicUser -and ($null -eq $ServerAddress)) {
    throw '-BasicUser can only be used with -ServerAddress and a Milestone basic-user credential.'
}

if ($BasicUser -and ($null -eq $Credential)) {
    throw '-BasicUser requires -Credential. Example: -Credential (Get-Credential) -BasicUser'
}

$module = Get-Module -Name MilestonePSTools -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
if ($null -eq $module) {
    if (-not $InstallModule) {
        throw "MilestonePSTools is not installed. Re-run with -InstallModule, or run: Install-Module MilestonePSTools -Scope CurrentUser"
    }

    Write-Host 'Installing MilestonePSTools for the current Windows user...' -ForegroundColor Cyan

    # Older Windows PowerShell builds commonly default to TLS 1.0, which the
    # PowerShell Gallery no longer accepts.
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    if ($null -eq (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force -Confirm:$false -ErrorAction Stop | Out-Null
    }

    Install-Module -Name MilestonePSTools -Scope CurrentUser -Force -AllowClobber -Confirm:$false -ErrorAction Stop
    $module = Get-Module -Name MilestonePSTools -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
}

Import-Module -Name MilestonePSTools -Force -ErrorAction Stop

if ($null -eq (Get-Command -Name Get-VmsCameraReport -ErrorAction SilentlyContinue)) {
    throw 'The installed MilestonePSTools version does not contain Get-VmsCameraReport. Run Update-Module MilestonePSTools.'
}

$moduleVersion = [string]$module.Version
Write-Host ("Using MilestonePSTools {0}" -f $moduleVersion) -ForegroundColor DarkCyan

$connectParameters = @{
    AcceptEula  = $true
    ErrorAction = 'Stop'
}

if ($null -ne $ServerAddress) {
    $connectParameters.ServerAddress = $ServerAddress
    if ($null -ne $Credential) { $connectParameters.Credential = $Credential }
    if ($BasicUser) { $connectParameters.BasicUser = $true }
    if ($SecureOnly) { $connectParameters.SecureOnly = $true }
}
else {
    $connectParameters.Name = $ConnectionProfile
}

Write-Host 'Connecting to XProtect...' -ForegroundColor Cyan
$managementServer = Connect-Vms @connectParameters

if ($null -eq $managementServer) {
    throw 'Connect-Vms did not return a Management Server object.'
}

$managementServerName = [string](Get-XpProperty -Object $managementServer -Name @('Name', 'Address', 'HostName') -Default $ServerAddress)
Write-Host ("Connected to {0}" -f $managementServerName) -ForegroundColor Green

$reportParameters = @{
    EnableFilter = 'All'
    ErrorAction  = 'Stop'
}
if ($IncludeRetentionInfo) { $reportParameters.IncludeRetentionInfo = $true }
if ($IncludeRecordingStats) { $reportParameters.IncludeRecordingStats = $true }

Write-Host 'Collecting recording servers and hardware...' -ForegroundColor Cyan
$recordingServers = @(Get-VmsRecordingServer -ErrorAction Stop)
$hardwareItems = @(Get-VmsHardware -EnableFilter All -ErrorAction Stop)

Write-Host 'Collecting detailed camera configuration and live recorder status...' -ForegroundColor Cyan
$rawCameraReportList = New-Object 'System.Collections.Generic.List[object]'
$cameraReportFailures = New-Object 'System.Collections.Generic.List[object]'

if ($recordingServers.Count -gt 0) {
    foreach ($recordingServer in $recordingServers) {
        $recorderDisplayName = [string](Get-XpProperty -Object $recordingServer -Name @('Name', 'HostName', 'Address') -Default 'Unknown Recording Server')
        Write-Host ("  Querying {0}" -f $recorderDisplayName) -ForegroundColor DarkCyan

        $recorderReportParameters = @{}
        foreach ($key in $reportParameters.Keys) {
            $recorderReportParameters[$key] = $reportParameters[$key]
        }
        $recorderReportParameters.RecordingServer = @($recordingServer)

        try {
            $recorderCameraRows = @(Get-VmsCameraReport @recorderReportParameters)
            foreach ($recorderCameraRow in $recorderCameraRows) {
                $rawCameraReportList.Add($recorderCameraRow)
            }
        }
        catch {
            $failure = [pscustomobject][ordered]@{
                RecordingServer = $recorderDisplayName
                RecorderId      = Get-XpProperty -Object $recordingServer -Name @('Id', 'RecorderId')
                Error           = $_.Exception.Message
                Object          = $recordingServer
            }
            $cameraReportFailures.Add($failure)
            Write-Warning ("Camera report failed for {0}. A configuration-only fallback will be attempted. {1}" -f $recorderDisplayName, $_.Exception.Message)
        }
    }
}
else {
    try {
        foreach ($cameraReportRow in @(Get-VmsCameraReport @reportParameters)) {
            $rawCameraReportList.Add($cameraReportRow)
        }
    }
    catch {
        throw ("Camera report failed and no Recording Server list was available for fallback. {0}" -f $_.Exception.Message)
    }
}

# If a Recording Server rejected the detailed report, retain configuration-only
# inventory for its cameras. These rows deliberately classify as UNKNOWN rather
# than falsely claiming the cameras are online.
foreach ($failure in $cameraReportFailures) {
    $failedRecorder = $failure.Object
    $failedRecorderName = $failure.RecordingServer
    $failedRecorderId = $failure.RecorderId

    try {
        $failedHardware = @(Get-VmsHardware -RecordingServer $failedRecorder -EnableFilter All -ErrorAction Stop)
        foreach ($failedHardwareItem in $failedHardware) {
            $fallbackCameras = @($failedHardwareItem | Get-VmsCamera -EnableFilter All -ErrorAction Stop)
            foreach ($fallbackCamera in $fallbackCameras) {
                $fallbackRow = [pscustomobject][ordered]@{
                    Name             = Get-XpProperty -Object $fallbackCamera -Name @('Name')
                    Channel          = Get-XpProperty -Object $fallbackCamera -Name @('Channel')
                    Enabled          = ConvertTo-XpBool (Get-XpProperty -Object $fallbackCamera -Name @('Enabled'))
                    State            = $null
                    LastModified     = Get-XpProperty -Object $fallbackCamera -Name @('LastModified')
                    Id               = Get-XpProperty -Object $fallbackCamera -Name @('Id')
                    IsStarted        = $null
                    IsRecording      = $null
                    IsInOverflow     = $null
                    IsInDbRepair     = $null
                    ErrorWritingGOP  = $null
                    ErrorNotLicensed = $null
                    ErrorNoConnection = $null
                    StatusTime       = $null
                    HardwareName     = Get-XpProperty -Object $failedHardwareItem -Name @('Name')
