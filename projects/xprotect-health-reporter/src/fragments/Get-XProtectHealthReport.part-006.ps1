<title>XProtect Health Report - $(ConvertTo-XpHtmlText $managementServerName)</title>
<style>$css</style>
</head>
<body>
<header>
    <h1>XProtect Hardware &amp; Camera Health</h1>
    <p><strong>Site:</strong> $(ConvertTo-XpHtmlText $managementServerName)</p>
    <p><strong>Generated:</strong> $(ConvertTo-XpHtmlText $timestamp) &nbsp; | &nbsp; <strong>MilestonePSTools:</strong> $(ConvertTo-XpHtmlText $moduleVersion)</p>
</header>
<main>
    <div class="cards">
        <div class="card"><strong>$cameraTotal</strong><span>Total cameras</span></div>
        <div class="card"><strong>$cameraOnline</strong><span>Cameras online</span></div>
        <div class="card"><strong>$cameraOffline</strong><span>Cameras offline</span></div>
        <div class="card"><strong>$cameraAttention</strong><span>Cameras requiring attention</span></div>
        <div class="card"><strong>$hardwareTotal</strong><span>Total hardware</span></div>
        <div class="card"><strong>$hardwareOnline</strong><span>Hardware online</span></div>
        <div class="card"><strong>$hardwareOffline</strong><span>Hardware offline</span></div>
        <div class="card"><strong>$hardwareAttention</strong><span>Hardware requiring attention</span></div>
    </div>

    <div class="note">
        Online/offline is based primarily on the Recording Server status service, not ICMP ping. UNKNOWN usually means this computer could not obtain recorder-side status; confirm TCP 7563 from this computer to the relevant Recording Server. IsRecording is shown in CSV but is not treated as an outage because motion and schedule-based recording can legitimately be idle.
    </div>

    <input id="global-search" class="search" type="search" placeholder="Filter every table by camera, address, recorder, status..." oninput="filterTables()">

    <section>
        <h2>Camera Action List ($cameraAttention)</h2>
        $attentionTable
    </section>

    <section>
        <h2>Hardware Summary ($hardwareTotal)</h2>
        $hardwareTable
    </section>

    <section>
        <h2>All Cameras ($cameraTotal)</h2>
        $cameraTable
    </section>

    <footer>
        Disabled cameras: $cameraDisabled | Unknown camera status: $cameraUnknown | Disabled hardware: $hardwareDisabled | Unknown hardware status: $hardwareUnknown<br>
        Detailed configuration, status flags, storage, stream and optional retention fields are available in the CSV files generated beside this report.
    </footer>
</main>
<script>$javascript</script>
</body>
</html>
"@

Set-Content -Path $htmlReportPath -Value $html -Encoding UTF8

$runSummary = [pscustomobject][ordered]@{
    GeneratedAt                = $timestamp
    ManagementServer          = $managementServerName
    MilestonePSToolsVersion    = $moduleVersion
    IncludeRetentionInfo       = [bool]$IncludeRetentionInfo
    IncludeRecordingStats      = [bool]$IncludeRecordingStats
    RecordingServers           = $recordingServers.Count
    CameraReportFailures       = $cameraReportFailures.Count
    HardwareTotal              = $hardwareTotal
    HardwareOnline             = $hardwareOnline
    HardwareOffline            = $hardwareOffline
    HardwareAttention          = $hardwareAttention
    HardwareDisabled           = $hardwareDisabled
    HardwareUnknown            = $hardwareUnknown
    CamerasTotal               = $cameraTotal
    CamerasOnline              = $cameraOnline
    CamerasOffline             = $cameraOffline
    CamerasAttention           = $cameraAttention
    CamerasDisabled            = $cameraDisabled
    CamerasUnknown             = $cameraUnknown
    OutputFolder               = $runFolder
    HtmlReport                 = $htmlReportPath
    CameraStatusCsv            = $cameraStatusCsv
    HardwareStatusCsv          = $hardwareStatusCsv
    FullCameraInventoryCsv     = $fullInventoryCsv
}

$runSummary | ConvertTo-Json -Depth 4 | Set-Content -Path $summaryJsonPath -Encoding UTF8

Write-Host ''
Write-Host 'XProtect health report complete.' -ForegroundColor Green
Write-Host ("  Cameras : {0} total | {1} online | {2} offline | {3} attention" -f $cameraTotal, $cameraOnline, $cameraOffline, $cameraAttention)
Write-Host ("  Hardware: {0} total | {1} online | {2} offline | {3} attention" -f $hardwareTotal, $hardwareOnline, $hardwareOffline, $hardwareAttention)
Write-Host ("  Report  : {0}" -f $htmlReportPath) -ForegroundColor Cyan

if ($OpenReport) {
    Start-Process -FilePath $htmlReportPath
}

[pscustomobject][ordered]@{
    OutputFolder           = $runFolder
    HtmlReport             = $htmlReportPath
    CameraStatusCsv        = $cameraStatusCsv
    HardwareStatusCsv      = $hardwareStatusCsv
    FullCameraInventoryCsv = $fullInventoryCsv
    SummaryJson            = $summaryJsonPath
}
