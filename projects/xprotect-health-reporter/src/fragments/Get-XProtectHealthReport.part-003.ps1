                    HardwareId       = Get-XpProperty -Object $failedHardwareItem -Name @('Id', 'HardwareId')
                    Model            = $null
                    Address          = Get-XpProperty -Object $failedHardwareItem -Name @('Address')
                    Username         = $null
                    HTTPSEnabled     = $null
                    MAC              = $null
                    Firmware         = $null
                    DriverFamily     = $null
                    Driver           = $null
                    DriverNumber     = $null
                    DriverVersion    = $null
                    DriverRevision   = $null
                    RecorderName     = $failedRecorderName
                    RecorderUri      = Get-XpProperty -Object $failedRecorder -Name @('Address', 'Uri')
                    RecorderId       = $failedRecorderId
                    RecordingEnabled = $null
                    RecordingStorageName = $null
                    RecordingPath    = $null
                }
                $rawCameraReportList.Add($fallbackRow)
            }
        }
    }
    catch {
        Write-Warning ("Configuration-only camera fallback also failed for {0}. {1}" -f $failedRecorderName, $_.Exception.Message)
    }
}

$rawCameraReport = @($rawCameraReportList)

if (($hardwareItems.Count -eq 0) -and ($rawCameraReport.Count -eq 0)) {
    throw 'XProtect returned no hardware and no cameras. Check permissions and the connected site.'
}

$directHardwareStatusById = @{}
if ($null -ne (Get-Command -Name Get-CurrentDeviceStatus -ErrorAction SilentlyContinue)) {
    try {
        Write-Host 'Collecting direct hardware status from Recording Servers...' -ForegroundColor Cyan
        $directHardwareStatuses = @(Get-CurrentDeviceStatus -DeviceType Hardware -ErrorAction Stop)
        foreach ($hardwareStatus in $directHardwareStatuses) {
            $statusId = Get-XpKey (Get-XpProperty -Object $hardwareStatus -Name @('DeviceId', 'HardwareId', 'Id'))
            if (-not [string]::IsNullOrWhiteSpace($statusId)) {
                $directHardwareStatusById[$statusId] = $hardwareStatus
            }
        }
    }
    catch {
        Write-Warning ('Direct hardware status could not be collected. Hardware status will be derived from camera channels. {0}' -f $_.Exception.Message)
    }
}

$recordingServerById = @{}
foreach ($recordingServer in $recordingServers) {
    $recordingServerId = Get-XpKey (Get-XpProperty -Object $recordingServer -Name @('Id', 'RecorderId'))
    if (-not [string]::IsNullOrWhiteSpace($recordingServerId)) {
        $recordingServerById[$recordingServerId] = $recordingServer
    }
}

$hardwareById = @{}
foreach ($hardwareItem in $hardwareItems) {
    $hardwareId = Get-XpKey (Get-XpProperty -Object $hardwareItem -Name @('Id', 'HardwareId'))
    if (-not [string]::IsNullOrWhiteSpace($hardwareId)) {
        $hardwareById[$hardwareId] = $hardwareItem
    }
}

$cameraRows = New-Object 'System.Collections.Generic.List[object]'
foreach ($camera in $rawCameraReport) {
    $health = Get-XpCameraHealth -Camera $camera
    $hardwareId = Get-XpKey (Get-XpProperty -Object $camera -Name @('HardwareId'))
    $hardwareObject = $null
    if ($hardwareById.ContainsKey($hardwareId)) {
        $hardwareObject = $hardwareById[$hardwareId]
    }

    $hardwareEnabled = ConvertTo-XpBool (Get-XpProperty -Object $hardwareObject -Name @('Enabled'))
    $cameraEnabledCombined = ConvertTo-XpBool (Get-XpProperty -Object $camera -Name @('Enabled'))

    $cameraRow = [pscustomobject][ordered]@{
        Status                       = $health.Status
        Severity                     = $health.Severity
        Online                       = $health.Online
        Issue                        = $health.Issue
        CameraName                   = Get-XpProperty -Object $camera -Name @('Name')
        Channel                      = Get-XpProperty -Object $camera -Name @('Channel')
        Enabled                      = $cameraEnabledCombined
        HardwareEnabled              = $hardwareEnabled
        CameraId                     = Get-XpProperty -Object $camera -Name @('Id')
        EventServerState             = Get-XpProperty -Object $camera -Name @('State')
        IsStarted                    = ConvertTo-XpBool (Get-XpProperty -Object $camera -Name @('IsStarted'))
        IsRecording                  = ConvertTo-XpBool (Get-XpProperty -Object $camera -Name @('IsRecording'))
        RecordingEnabled             = ConvertTo-XpBool (Get-XpProperty -Object $camera -Name @('RecordingEnabled'))
        ErrorNoConnection            = ConvertTo-XpBool (Get-XpProperty -Object $camera -Name @('ErrorNoConnection'))
        ErrorNotLicensed             = ConvertTo-XpBool (Get-XpProperty -Object $camera -Name @('ErrorNotLicensed'))
        ErrorWritingGOP              = ConvertTo-XpBool (Get-XpProperty -Object $camera -Name @('ErrorWritingGOP'))
        IsInOverflow                 = ConvertTo-XpBool (Get-XpProperty -Object $camera -Name @('IsInOverflow'))
        IsInDbRepair                 = ConvertTo-XpBool (Get-XpProperty -Object $camera -Name @('IsInDbRepair'))
        StatusTime                   = Get-XpProperty -Object $camera -Name @('StatusTime')
        LastModified                 = Get-XpProperty -Object $camera -Name @('LastModified')
        HardwareName                 = Get-XpProperty -Object $camera -Name @('HardwareName')
        HardwareId                   = Get-XpProperty -Object $camera -Name @('HardwareId')
        Model                        = Get-XpProperty -Object $camera -Name @('Model')
        Firmware                     = Get-XpProperty -Object $camera -Name @('Firmware')
        Address                      = Get-XpProperty -Object $camera -Name @('Address')
        Username                     = Get-XpProperty -Object $camera -Name @('Username')
        HTTPSEnabled                 = ConvertTo-XpBool (Get-XpProperty -Object $camera -Name @('HTTPSEnabled'))
        MAC                          = Get-XpProperty -Object $camera -Name @('MAC')
        DriverFamily                 = Get-XpProperty -Object $camera -Name @('DriverFamily')
        Driver                       = Get-XpProperty -Object $camera -Name @('Driver')
        DriverNumber                 = Get-XpProperty -Object $camera -Name @('DriverNumber')
        DriverVersion                = Get-XpProperty -Object $camera -Name @('DriverVersion')
        DriverRevision               = Get-XpProperty -Object $camera -Name @('DriverRevision')
        RecordingServer              = Get-XpProperty -Object $camera -Name @('RecorderName')
        RecorderUri                  = Get-XpProperty -Object $camera -Name @('RecorderUri')
        RecorderId                   = Get-XpProperty -Object $camera -Name @('RecorderId')
        ConfiguredLiveResolution     = Get-XpProperty -Object $camera -Name @('ConfiguredLiveResolution')
        ConfiguredLiveCodec          = Get-XpProperty -Object $camera -Name @('ConfiguredLiveCodec')
        ConfiguredLiveFPS            = Get-XpProperty -Object $camera -Name @('ConfiguredLiveFPS')
        CurrentLiveResolution        = Get-XpProperty -Object $camera -Name @('CurrentLiveResolution')
        CurrentLiveCodec             = Get-XpProperty -Object $camera -Name @('CurrentLiveCodec')
        CurrentLiveFPS               = Get-XpProperty -Object $camera -Name @('CurrentLiveFPS')
        CurrentLiveBitrate           = Get-XpProperty -Object $camera -Name @('CurrentLiveBitrate')
        ConfiguredRecordedResolution = Get-XpProperty -Object $camera -Name @('ConfiguredRecordedResolution')
        ConfiguredRecordedCodec      = Get-XpProperty -Object $camera -Name @('ConfiguredRecordedCodec')
        ConfiguredRecordedFPS        = Get-XpProperty -Object $camera -Name @('ConfiguredRecordedFPS')
        CurrentRecordedResolution    = Get-XpProperty -Object $camera -Name @('CurrentRecordedResolution')
