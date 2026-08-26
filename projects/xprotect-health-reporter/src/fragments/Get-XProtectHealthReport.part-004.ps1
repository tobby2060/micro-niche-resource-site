        CurrentRecordedCodec         = Get-XpProperty -Object $camera -Name @('CurrentRecordedCodec')
        CurrentRecordedFPS           = Get-XpProperty -Object $camera -Name @('CurrentRecordedFPS')
        CurrentRecordedBitrate       = Get-XpProperty -Object $camera -Name @('CurrentRecordedBitrate')
        RecordingStorageName         = Get-XpProperty -Object $camera -Name @('RecordingStorageName')
        RecordingPath                = Get-XpProperty -Object $camera -Name @('RecordingPath')
        ExpectedRetentionDays        = Get-XpProperty -Object $camera -Name @('ExpectedRetentionDays')
        ActualRetentionDays          = Get-XpProperty -Object $camera -Name @('ActualRetentionDays')
        MeetsRetentionPolicy         = Get-XpProperty -Object $camera -Name @('MeetsRetentionPolicy')
        UsedSpaceInGB                = Get-XpProperty -Object $camera -Name @('UsedSpaceInGB')
        PercentRecordedOneWeek       = Get-XpProperty -Object $camera -Name @('PercentRecordedOneWeek')
        MediaDatabaseBegin           = Get-XpProperty -Object $camera -Name @('MediaDatabaseBegin')
        MediaDatabaseEnd             = Get-XpProperty -Object $camera -Name @('MediaDatabaseEnd')
    }

    $cameraRows.Add($cameraRow)
}

$cameraRowsByHardwareId = @{}
foreach ($cameraRow in $cameraRows) {
    $cameraHardwareId = Get-XpKey $cameraRow.HardwareId
    if (-not $cameraRowsByHardwareId.ContainsKey($cameraHardwareId)) {
        $cameraRowsByHardwareId[$cameraHardwareId] = New-Object 'System.Collections.Generic.List[object]'
    }
    $cameraRowsByHardwareId[$cameraHardwareId].Add($cameraRow)
}

$hardwareRows = New-Object 'System.Collections.Generic.List[object]'
foreach ($hardwareItem in $hardwareItems) {
    $hardwareIdValue = Get-XpProperty -Object $hardwareItem -Name @('Id', 'HardwareId')
    $hardwareIdKey = Get-XpKey $hardwareIdValue
    $childCameraRows = @()
    if ($cameraRowsByHardwareId.ContainsKey($hardwareIdKey)) {
        $childCameraRows = @($cameraRowsByHardwareId[$hardwareIdKey])
    }

    $directHardwareStatus = $null
    if ($directHardwareStatusById.ContainsKey($hardwareIdKey)) {
        $directHardwareStatus = $directHardwareStatusById[$hardwareIdKey]
    }

    $hardwareHealth = Get-XpHardwareHealth -Hardware $hardwareItem -CameraRows $childCameraRows -DirectStatus $directHardwareStatus
    $firstCamera = $childCameraRows | Select-Object -First 1

    $hardwareSettings = $null
    $needsHardwareSettings = ($null -eq $firstCamera) -or
                             [string]::IsNullOrWhiteSpace([string](Get-XpProperty -Object $firstCamera -Name @('MAC'))) -or
                             [string]::IsNullOrWhiteSpace([string](Get-XpProperty -Object $firstCamera -Name @('Model'))) -or
                             [string]::IsNullOrWhiteSpace([string](Get-XpProperty -Object $firstCamera -Name @('Firmware')))
    if ($needsHardwareSettings -and ($null -ne (Get-Command -Name Get-HardwareSetting -ErrorAction SilentlyContinue))) {
        try {
            $hardwareSettings = $hardwareItem | Get-HardwareSetting -ErrorAction Stop
        }
        catch {
            $hardwareSettings = $null
        }
    }

    $recorderIdValue = Get-XpProperty -Object $hardwareItem -Name @('RecorderId', 'RecordingServerId')
    if ($null -eq $recorderIdValue) {
        $recorderIdValue = Get-XpProperty -Object $firstCamera -Name @('RecorderId')
    }
    $recorderName = Get-XpProperty -Object $firstCamera -Name @('RecordingServer')
    if ([string]::IsNullOrWhiteSpace([string]$recorderName)) {
        $recorderIdKey = Get-XpKey $recorderIdValue
        if ($recordingServerById.ContainsKey($recorderIdKey)) {
            $recorderName = Get-XpProperty -Object $recordingServerById[$recorderIdKey] -Name @('Name')
        }
    }

    $enabledChildCameras = @($childCameraRows | Where-Object { $_.Enabled -eq $true })
    $onlineChildCameras = @($enabledChildCameras | Where-Object { $_.Status -eq 'ONLINE' })
    $offlineChildCameras = @($enabledChildCameras | Where-Object { $_.Status -in @('OFFLINE', 'NOT STARTED', 'UNLICENSED') })
    $problemChildCameras = @($enabledChildCameras | Where-Object { $_.Status -notin @('ONLINE', 'DISABLED') })
    $unknownChildCameras = @($enabledChildCameras | Where-Object { $_.Status -eq 'UNKNOWN' })

    $hardwareRow = [pscustomobject][ordered]@{
        Status                   = $hardwareHealth.Status
        Severity                 = $hardwareHealth.Severity
        Online                   = $hardwareHealth.Online
        Issue                    = $hardwareHealth.Issue
        StatusSource             = $hardwareHealth.StatusSource
        HardwareName             = Get-XpProperty -Object $hardwareItem -Name @('Name')
        Enabled                  = ConvertTo-XpBool (Get-XpProperty -Object $hardwareItem -Name @('Enabled'))
        HardwareId               = $hardwareIdValue
        Address                  = Get-XpProperty -Object $hardwareItem -Name @('Address') -Default (Get-XpProperty -Object $firstCamera -Name @('Address'))
        MAC                      = Get-XpProperty -Object $firstCamera -Name @('MAC') -Default (Get-XpProperty -Object $hardwareSettings -Name @('MACAddress', 'MAC'))
        Model                    = Get-XpProperty -Object $firstCamera -Name @('Model') -Default (Get-XpProperty -Object $hardwareSettings -Name @('Model', 'ModelName'))
        Firmware                 = Get-XpProperty -Object $firstCamera -Name @('Firmware') -Default (Get-XpProperty -Object $hardwareSettings -Name @('Firmware', 'FirmwareVersion'))
        HTTPSEnabled             = Get-XpProperty -Object $firstCamera -Name @('HTTPSEnabled')
        DriverFamily             = Get-XpProperty -Object $firstCamera -Name @('DriverFamily')
        Driver                   = Get-XpProperty -Object $firstCamera -Name @('Driver')
        DriverNumber             = Get-XpProperty -Object $firstCamera -Name @('DriverNumber')
        DriverVersion            = Get-XpProperty -Object $firstCamera -Name @('DriverVersion')
        RecordingServer          = $recorderName
        RecorderId               = $recorderIdValue
        CameraChannels           = $childCameraRows.Count
        EnabledCameraChannels    = $enabledChildCameras.Count
        OnlineCameraChannels     = $onlineChildCameras.Count
        OfflineCameraChannels    = $offlineChildCameras.Count
        ProblemCameraChannels    = $problemChildCameras.Count
        UnknownCameraChannels    = $unknownChildCameras.Count
        RecorderHardwareStarted  = ConvertTo-XpBool (Get-XpProperty -Object $directHardwareStatus -Name @('IsStarted', 'Started'))
        ErrorNoConnection        = ConvertTo-XpBool (Get-XpProperty -Object $directHardwareStatus -Name @('ErrorNoConnection'))
        ErrorNotLicensed         = ConvertTo-XpBool (Get-XpProperty -Object $directHardwareStatus -Name @('ErrorNotLicensed'))
        RecorderHardwareStatusAt = Get-XpProperty -Object $directHardwareStatus -Name @('StatusTime', 'Time')
    }

    $hardwareRows.Add($hardwareRow)
}

$sortedCameraRows = @($cameraRows | Sort-Object Severity, RecordingServer, HardwareName, Channel, CameraName)
$sortedHardwareRows = @($hardwareRows | Sort-Object Severity, RecordingServer, HardwareName)

$timestamp = Get-Date
$runFolder = Join-Path -Path $OutputPath -ChildPath ('XProtect-Health-{0}' -f $timestamp.ToString('yyyyMMdd-HHmmss'))
$null = New-Item -ItemType Directory -Path $runFolder -Force

$cameraStatusCsv = Join-Path $runFolder 'XProtect-Camera-Status.csv'
$hardwareStatusCsv = Join-Path $runFolder 'XProtect-Hardware-Status.csv'
$fullInventoryCsv = Join-Path $runFolder 'XProtect-Camera-Inventory-Full.csv'
$htmlReportPath = Join-Path $runFolder 'XProtect-Health-Report.html'
$summaryJsonPath = Join-Path $runFolder 'XProtect-Run-Summary.json'

$sortedCameraRows | Export-Csv -Path $cameraStatusCsv -NoTypeInformation -Encoding UTF8
$sortedHardwareRows | Export-Csv -Path $hardwareStatusCsv -NoTypeInformation -Encoding UTF8
