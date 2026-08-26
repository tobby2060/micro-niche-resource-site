XProtect Health Reporter
========================

WHAT IT DOES
------------
Creates a point-in-time XProtect hardware and camera health report using the
MilestonePSTools module. It sorts problem devices first and writes:

- XProtect-Health-Report.html
- XProtect-Camera-Status.csv
- XProtect-Hardware-Status.csv
- XProtect-Camera-Inventory-Full.csv
- XProtect-Run-Summary.json

It does not request or export camera passwords.

REQUIREMENTS
------------
- Windows PowerShell 5.1: use powershell.exe, not pwsh.exe
- An XProtect account with permission to read configuration and device status
- Network access to the Management Server
- TCP 7563 from the script computer to every Recording Server for live status

FASTEST FIRST RUN
-----------------
Double-click:

Run-XProtect-Health-Report.cmd

The launcher uses Windows PowerShell 5.1, installs MilestonePSTools if needed,
opens the Milestone login dialog, creates/uses the connection profile named
"default", generates the files, and opens the HTML report.

PowerShell equivalent:

powershell.exe -ExecutionPolicy Bypass -File .\Get-XProtectHealthReport.ps1 -InstallModule -OpenReport

NORMAL LATER RUNS
-----------------
.\Get-XProtectHealthReport.ps1 -OpenReport

NAMED CONNECTION PROFILE
------------------------
.\Get-XProtectHealthReport.ps1 -ConnectionProfile "Customer-Site" -OpenReport

The first run displays the login dialog and saves that profile. A saved profile
is protected for the current Windows user. A scheduled task must run as the same
Windows user that created the profile.

EXPLICIT MANAGEMENT SERVER
--------------------------
Windows / Active Directory account:

.\Get-XProtectHealthReport.ps1 `
  -ServerAddress "https://xprotect-management.example.local" `
  -Credential (Get-Credential) `
  -SecureOnly `
  -OpenReport

Milestone basic user:

.\Get-XProtectHealthReport.ps1 `
  -ServerAddress "https://xprotect-management.example.local" `
  -Credential (Get-Credential) `
  -BasicUser `
  -SecureOnly `
  -OpenReport

OPTIONAL DEEPER REPORTING
-------------------------
Add -IncludeRetentionInfo to calculate current retention information.
Add -IncludeRecordingStats to calculate recording percentage over the last
seven days. Recording statistics can make the report take substantially longer.

Example:

.\Get-XProtectHealthReport.ps1 `
  -IncludeRetentionInfo `
  -IncludeRecordingStats `
  -OpenReport

OUTPUT LOCATION
---------------
Default:

%USERPROFILE%\Desktop\XProtectReports\XProtect-Health-YYYYMMDD-HHMMSS

Custom location:

.\Get-XProtectHealthReport.ps1 -OutputPath "D:\Reports\Milestone" -OpenReport

STATUS LOGIC
------------
The report uses XProtect Recording Server status rather than treating ping as
proof that a camera is healthy. Key conditions include:

- OFFLINE: ErrorNoConnection
- UNLICENSED: ErrorNotLicensed
- STORAGE ERROR: ErrorWritingGOP or IsInOverflow
- DB REPAIR: IsInDbRepair
- NOT STARTED: enabled but not started by the Recording Server
- UNKNOWN: recorder-side status could not be obtained, commonly TCP 7563
- ONLINE: started with no current recorder-side fault flag

IsRecording=False is not treated as an outage because cameras configured for
motion or scheduled recording can legitimately be idle.

MODEL AND FIRMWARE NOTE
-----------------------
The Model and Firmware values are the last values known to XProtect Management
Client. Milestone notes that firmware may not refresh until Replace Hardware is
performed, so use the report as XProtect inventory rather than a vendor-live
firmware interrogation.

PROJECT FILES
-------------
- `Get-XProtectHealthReport.ps1` - report engine
- `Run-XProtect-Health-Report.cmd` - double-click launcher
- `XProtect-Health-Reporter.zip` - packaged copy of the same files
- `SHA256SUMS.txt` - integrity hashes for the published files

SUPPORT STATUS
--------------
This is an independently developed administrative utility. It is not an official
Milestone Systems product and must be validated in a test environment before
production use.

SOURCE LAYOUT
-------------
The exact PowerShell source is retained as ordered fragments under
`src/fragments` because this project was imported through a restricted GitHub
connector. Run `Build-XProtectHealthReporter.ps1` after cloning to regenerate
`Get-XProtectHealthReport.ps1` byte-for-byte, or use the packaged ZIP under
`release`.

```powershell
.\Build-XProtectHealthReporter.ps1
.\Get-XProtectHealthReport.ps1 -OpenReport
```
