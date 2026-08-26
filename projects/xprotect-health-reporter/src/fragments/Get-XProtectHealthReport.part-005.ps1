$rawCameraReport | Export-Csv -Path $fullInventoryCsv -NoTypeInformation -Encoding UTF8

$cameraTotal = $sortedCameraRows.Count
$cameraOnline = @($sortedCameraRows | Where-Object { $_.Status -eq 'ONLINE' }).Count
$cameraOffline = @($sortedCameraRows | Where-Object { $_.Status -eq 'OFFLINE' }).Count
$cameraDisabled = @($sortedCameraRows | Where-Object { $_.Status -eq 'DISABLED' }).Count
$cameraUnknown = @($sortedCameraRows | Where-Object { $_.Status -eq 'UNKNOWN' }).Count
$cameraAttention = @($sortedCameraRows | Where-Object { $_.Status -notin @('ONLINE', 'DISABLED') }).Count

$hardwareTotal = $sortedHardwareRows.Count
$hardwareOnline = @($sortedHardwareRows | Where-Object { $_.Status -eq 'ONLINE' }).Count
$hardwareOffline = @($sortedHardwareRows | Where-Object { $_.Status -eq 'OFFLINE' }).Count
$hardwareDisabled = @($sortedHardwareRows | Where-Object { $_.Status -eq 'DISABLED' }).Count
$hardwareUnknown = @($sortedHardwareRows | Where-Object { $_.Status -eq 'UNKNOWN' }).Count
$hardwareAttention = @($sortedHardwareRows | Where-Object { $_.Status -notin @('ONLINE', 'DISABLED', 'NO ENABLED CAMERAS') }).Count

$attentionCameraRows = @($sortedCameraRows | Where-Object { $_.Status -notin @('ONLINE', 'DISABLED') })

$hardwareColumns = @(
    [pscustomobject]@{ Label = 'Status'; Property = 'Status' }
    [pscustomobject]@{ Label = 'Hardware'; Property = 'HardwareName' }
    [pscustomobject]@{ Label = 'Address'; Property = 'Address' }
    [pscustomobject]@{ Label = 'Model'; Property = 'Model' }
    [pscustomobject]@{ Label = 'Firmware'; Property = 'Firmware' }
    [pscustomobject]@{ Label = 'MAC'; Property = 'MAC' }
    [pscustomobject]@{ Label = 'Recording Server'; Property = 'RecordingServer' }
    [pscustomobject]@{ Label = 'Cameras'; Property = 'CameraChannels' }
    [pscustomobject]@{ Label = 'Online'; Property = 'OnlineCameraChannels' }
    [pscustomobject]@{ Label = 'Problems'; Property = 'ProblemCameraChannels' }
    [pscustomobject]@{ Label = 'Issue'; Property = 'Issue' }
)

$cameraAttentionColumns = @(
    [pscustomobject]@{ Label = 'Status'; Property = 'Status' }
    [pscustomobject]@{ Label = 'Camera'; Property = 'CameraName' }
    [pscustomobject]@{ Label = 'Hardware'; Property = 'HardwareName' }
    [pscustomobject]@{ Label = 'Address'; Property = 'Address' }
    [pscustomobject]@{ Label = 'Recording Server'; Property = 'RecordingServer' }
    [pscustomobject]@{ Label = 'State'; Property = 'EventServerState' }
    [pscustomobject]@{ Label = 'Started'; Property = 'IsStarted' }
    [pscustomobject]@{ Label = 'Last Status'; Property = 'StatusTime' }
    [pscustomobject]@{ Label = 'Issue'; Property = 'Issue' }
)

$cameraColumns = @(
    [pscustomobject]@{ Label = 'Status'; Property = 'Status' }
    [pscustomobject]@{ Label = 'Camera'; Property = 'CameraName' }
    [pscustomobject]@{ Label = 'Channel'; Property = 'Channel' }
    [pscustomobject]@{ Label = 'Hardware'; Property = 'HardwareName' }
    [pscustomobject]@{ Label = 'Address'; Property = 'Address' }
    [pscustomobject]@{ Label = 'Model'; Property = 'Model' }
    [pscustomobject]@{ Label = 'Firmware'; Property = 'Firmware' }
    [pscustomobject]@{ Label = 'Recording Server'; Property = 'RecordingServer' }
    [pscustomobject]@{ Label = 'Live'; Property = 'CurrentLiveResolution' }
    [pscustomobject]@{ Label = 'Live FPS'; Property = 'CurrentLiveFPS' }
    [pscustomobject]@{ Label = 'Recording'; Property = 'CurrentRecordedResolution' }
    [pscustomobject]@{ Label = 'Rec FPS'; Property = 'CurrentRecordedFPS' }
    [pscustomobject]@{ Label = 'Storage'; Property = 'RecordingStorageName' }
    [pscustomobject]@{ Label = 'Last Status'; Property = 'StatusTime' }
    [pscustomobject]@{ Label = 'Issue'; Property = 'Issue' }
)

$hardwareTable = New-XpHtmlTable -Items $sortedHardwareRows -Columns $hardwareColumns -Id 'hardware-table'
$attentionTable = New-XpHtmlTable -Items $attentionCameraRows -Columns $cameraAttentionColumns -Id 'attention-table'
$cameraTable = New-XpHtmlTable -Items $sortedCameraRows -Columns $cameraColumns -Id 'camera-table'

$css = @'
:root {
    color-scheme: dark;
    --bg: #0d0f12;
    --panel: #171a1f;
    --panel-2: #20242b;
    --text: #f3f4f6;
    --muted: #a5acb8;
    --line: #343a44;
    --red: #ed1c24;
    --green: #2dbf6f;
    --amber: #f1aa2b;
    --grey: #77808e;
}
* { box-sizing: border-box; }
body {
    margin: 0;
    font-family: "Segoe UI", Arial, sans-serif;
    background: var(--bg);
    color: var(--text);
}
header {
    padding: 28px 36px;
    border-bottom: 3px solid var(--red);
    background: linear-gradient(135deg, #111318, #1a1d23);
}
h1 { margin: 0 0 6px; font-size: 30px; letter-spacing: .2px; }
header p { margin: 4px 0; color: var(--muted); }
main { padding: 24px 36px 50px; }
.cards {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
    gap: 12px;
    margin: 0 0 24px;
}
.card {
    padding: 16px;
    background: var(--panel);
    border: 1px solid var(--line);
    border-top: 3px solid var(--red);
    border-radius: 6px;
}
.card strong { display: block; font-size: 26px; margin-bottom: 3px; }
.card span { color: var(--muted); font-size: 13px; }
section {
    background: var(--panel);
    border: 1px solid var(--line);
    border-radius: 7px;
    padding: 18px;
    margin: 0 0 22px;
}
h2 { margin: 0 0 12px; font-size: 20px; }
.note {
    border-left: 4px solid var(--amber);
    background: #222019;
    padding: 11px 14px;
    margin: 0 0 18px;
    color: #e9dfc5;
}
.search {
    width: min(520px, 100%);
    margin: 0 0 14px;
    padding: 10px 12px;
    color: var(--text);
    background: var(--panel-2);
    border: 1px solid var(--line);
    border-radius: 5px;
}
.table-wrap { width: 100%; overflow-x: auto; }
table { width: 100%; border-collapse: collapse; font-size: 12px; }
th {
    text-align: left;
    white-space: nowrap;
    position: sticky;
    top: 0;
    background: #252a31;
    color: #fff;
    border-bottom: 2px solid #555d69;
    padding: 9px 8px;
}
td {
    vertical-align: top;
    border-bottom: 1px solid #303640;
    padding: 8px;
    max-width: 360px;
    overflow-wrap: anywhere;
}
tr:hover td { background: rgba(255,255,255,.035); }
.row-offline td, .row-unlicensed td, .row-storage-error td { background: rgba(237, 28, 36, .09); }
.row-not-started td, .row-degraded td, .row-error td, .row-db-repair td { background: rgba(241, 170, 43, .08); }
.row-unknown td { background: rgba(119, 128, 142, .08); }
.row-disabled td, .row-no-enabled-cameras td { color: #9299a5; }
.badge {
    display: inline-block;
    padding: 3px 7px;
    border-radius: 999px;
    font-size: 10px;
    font-weight: 700;
    white-space: nowrap;
    background: #3a414c;
}
.badge-online { background: #155b39; color: #d9ffea; }
.badge-offline, .badge-unlicensed, .badge-storage-error { background: #7a1c22; color: #ffe0e2; }
.badge-not-started, .badge-degraded, .badge-error, .badge-db-repair { background: #795719; color: #fff0c8; }
.badge-unknown { background: #48505c; color: #f1f3f6; }
.badge-disabled, .badge-no-enabled-cameras { background: #30343b; color: #b8bec8; }
.empty { color: var(--muted); font-style: italic; }
footer { color: var(--muted); font-size: 12px; padding-top: 8px; }
@media print {
    body { color-scheme: light; background: #fff; color: #111; }
    header, section, .card { background: #fff; color: #111; }
    .search { display: none; }
    th { position: static; background: #eee; color: #111; }
}
'@

$javascript = @'
function filterTables() {
    const input = document.getElementById('global-search');
    const query = input.value.toLowerCase().trim();
    document.querySelectorAll('table.data-table tbody tr').forEach(function(row) {
        row.style.display = row.innerText.toLowerCase().includes(query) ? '' : 'none';
    });
}
'@

$html = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
