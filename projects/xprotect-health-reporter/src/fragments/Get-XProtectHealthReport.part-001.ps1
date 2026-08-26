            Status   = 'NOT STARTED'
            Severity = 50
            Online   = 'No'
            Issue    = 'Camera is enabled but has not been started by the Recording Server'
        }
    }

    if ($genericError -eq $true) {
        return [pscustomobject][ordered]@{
            Status   = 'ERROR'
            Severity = 60
            Online   = 'Unknown'
            Issue    = 'Recording Server reports a device error'
        }
    }

    return [pscustomobject][ordered]@{
        Status   = 'ONLINE'
        Severity = 800
        Online   = 'Yes'
        Issue    = ''
    }
}

function Get-XpHardwareHealth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Hardware,

        [Parameter()]
        [object[]]$CameraRows = @(),

        [Parameter()]
        [AllowNull()]
        $DirectStatus
    )

    $hardwareEnabled = ConvertTo-XpBool (Get-XpProperty -Object $Hardware -Name @('Enabled'))
    if ($hardwareEnabled -eq $false) {
        return [pscustomobject][ordered]@{
            Status       = 'DISABLED'
            Severity     = 900
            Online       = 'N/A'
            Issue        = 'Hardware is disabled in XProtect'
            StatusSource = 'Configuration'
        }
    }

    $enabledRows = @($CameraRows | Where-Object { $_.Enabled -eq $true })
    $onlineRows = @($enabledRows | Where-Object { $_.Status -eq 'ONLINE' })
    $offlineRows = @($enabledRows | Where-Object { $_.Status -in @('OFFLINE', 'NOT STARTED', 'UNLICENSED') })
    $problemRows = @($enabledRows | Where-Object { $_.Status -notin @('ONLINE', 'DISABLED') })
    $unknownRows = @($enabledRows | Where-Object { $_.Status -eq 'UNKNOWN' })

    if ($null -ne $DirectStatus) {
        $started = ConvertTo-XpBool (Get-XpProperty -Object $DirectStatus -Name @('IsStarted', 'Started'))
        $notLicensed = ConvertTo-XpBool (Get-XpProperty -Object $DirectStatus -Name @('ErrorNotLicensed'))
        $noConnection = ConvertTo-XpBool (Get-XpProperty -Object $DirectStatus -Name @('ErrorNoConnection'))
        $genericError = ConvertTo-XpBool (Get-XpProperty -Object $DirectStatus -Name @('Error'))
        $writeError = ConvertTo-XpBool (Get-XpProperty -Object $DirectStatus -Name @('ErrorWritingGOP', 'ErrorWritingGop'))
        $overflow = ConvertTo-XpBool (Get-XpProperty -Object $DirectStatus -Name @('IsInOverflow', 'ErrorOverflow'))

        if ($notLicensed -eq $true) {
            return [pscustomobject][ordered]@{
                Status       = 'UNLICENSED'
                Severity     = 10
                Online       = 'No'
                Issue        = 'Hardware is not licensed or its grace period has expired'
                StatusSource = 'Recorder hardware status'
            }
        }

        if ($noConnection -eq $true) {
            return [pscustomobject][ordered]@{
                Status       = 'OFFLINE'
                Severity     = 20
                Online       = 'No'
                Issue        = 'Recording Server cannot communicate with the hardware'
                StatusSource = 'Recorder hardware status'
            }
        }

        if (($writeError -eq $true) -or ($overflow -eq $true)) {
            return [pscustomobject][ordered]@{
                Status       = 'STORAGE ERROR'
                Severity     = 30
                Online       = 'Yes'
                Issue        = 'Recorder reports a storage write or overflow condition'
                StatusSource = 'Recorder hardware status'
            }
        }

        if (($started -eq $false) -or ($genericError -eq $true)) {
            return [pscustomobject][ordered]@{
                Status       = 'NOT STARTED'
                Severity     = 50
                Online       = 'No'
                Issue        = 'Hardware is enabled but the Recording Server has not started it successfully'
                StatusSource = 'Recorder hardware status'
            }
        }

        if ($started -eq $true) {
            if ($problemRows.Count -gt 0) {
                return [pscustomobject][ordered]@{
                    Status       = 'DEGRADED'
                    Severity     = 60
                    Online       = 'Yes'
                    Issue        = ('Hardware responds, but {0} enabled camera channel(s) have a problem' -f $problemRows.Count)
                    StatusSource = 'Recorder hardware status plus camera channels'
                }
            }

            return [pscustomobject][ordered]@{
                Status       = 'ONLINE'
                Severity     = 800
                Online       = 'Yes'
                Issue        = ''
                StatusSource = 'Recorder hardware status'
            }
        }
    }

    if ($enabledRows.Count -eq 0) {
        if ($CameraRows.Count -eq 0) {
            return [pscustomobject][ordered]@{
                Status       = 'UNKNOWN'
                Severity     = 70
                Online       = 'Unknown'
                Issue        = 'No camera channels or direct recorder hardware status were available'
                StatusSource = 'Configuration only'
            }
        }

        return [pscustomobject][ordered]@{
            Status       = 'NO ENABLED CAMERAS'
            Severity     = 850
            Online       = 'N/A'
            Issue        = 'Hardware is enabled, but all camera channels are disabled'
            StatusSource = 'Camera channel aggregate'
        }
    }

    if ($onlineRows.Count -eq $enabledRows.Count) {
        return [pscustomobject][ordered]@{
            Status       = 'ONLINE'
            Severity     = 800
            Online       = 'Yes'
            Issue        = ''
            StatusSource = 'Camera channel aggregate'
        }
    }

    if (($offlineRows.Count -eq $enabledRows.Count) -and ($enabledRows.Count -gt 0)) {
        return [pscustomobject][ordered]@{
            Status       = 'OFFLINE'
            Severity     = 20
            Online       = 'No'
            Issue        = 'Every enabled camera channel on this hardware is offline, unlicensed, or not started'
            StatusSource = 'Camera channel aggregate'
        }
    }

    if (($unknownRows.Count -eq $enabledRows.Count) -and ($enabledRows.Count -gt 0)) {
        return [pscustomobject][ordered]@{
            Status       = 'UNKNOWN'
            Severity     = 70
            Online       = 'Unknown'
            Issue        = 'Recorder-side status was unavailable for every enabled camera channel'
            StatusSource = 'Camera channel aggregate'
        }
    }

    return [pscustomobject][ordered]@{
        Status       = 'DEGRADED'
        Severity     = 60
        Online       = 'Partial'
        Issue        = ('{0} of {1} enabled camera channel(s) require attention' -f $problemRows.Count, $enabledRows.Count)
        StatusSource = 'Camera channel aggregate'
    }
}

function New-XpHtmlTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Items,

        [Parameter(Mandatory)]
        [object[]]$Columns,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Id
    )

    if ($Items.Count -eq 0) {
        return '<p class="empty">Nothing to show.</p>'
    }

    $builder = New-Object System.Text.StringBuilder
    [void]$builder.AppendLine(('<div class="table-wrap"><table class="data-table" id="{0}"><thead><tr>' -f (ConvertTo-XpHtmlText $Id)))

    foreach ($column in $Columns) {
        [void]$builder.AppendLine(('<th>{0}</th>' -f (ConvertTo-XpHtmlText (Get-XpProperty -Object $column -Name @('Label')))))
    }

    [void]$builder.AppendLine('</tr></thead><tbody>')

    foreach ($item in $Items) {
        $status = [string](Get-XpProperty -Object $item -Name @('Status') -Default 'UNKNOWN')
        $statusSlug = Get-XpStatusSlug -Status $status
        [void]$builder.AppendLine(('<tr class="row-{0}">' -f $statusSlug))

        foreach ($column in $Columns) {
