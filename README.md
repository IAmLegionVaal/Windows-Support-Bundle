# Windows Support Bundle

A single-run PowerShell diagnostic collector for Windows support, troubleshooting and escalation. It gathers system evidence into a timestamped folder and optionally creates a ZIP archive for review.

## One-click use

1. Download and extract the repository.
2. Double-click `Run-OneClick.bat`.
3. Approve the administrator prompt.
4. Review the exit code and generated bundle under `C:\Users\Public\Documents\WindowsSupportBundles`.

The launcher runs `Collect-WindowsSupportBundle.ps1` directly. There is no menu.

## What it collects

- Windows version, build, architecture, install date and last boot time
- Manufacturer, model, domain status, processor and memory information
- BIOS, logical disk and physical disk details
- Device Manager devices reporting errors
- IP configuration, routes, proxy settings and network adapters
- Installed applications and Windows hotfixes
- Services and startup commands
- Microsoft Defender, BitLocker and Windows Firewall status
- Pending-restart indicators
- Recent critical, error and warning events from System and Application logs
- A transcript, collection-error report, JSON manifest and privacy notice

## Data-handling boundary

The collector does not intentionally query browser history, email bodies, personal document contents, password stores or saved-credential APIs. However, diagnostic sources such as startup command lines, proxy output and Windows event messages can contain sensitive values supplied by third-party software.

The script redacts common password, token, API-key and secret key/value patterns before writing startup commands, text reports and event messages. Pattern-based redaction is not exhaustive. **Review every generated file before sharing or uploading the bundle.**

## Valid CSV behavior

Every generated `.csv` file remains syntactically valid:

- Normal collections contain their expected rows.
- Empty collections contain a `CollectionStatus=NoData` status row.
- Failed collections contain a `CollectionStatus=Failed` status row and direct the reviewer to `Logs\CollectionErrors.csv`.

This allows automation and spreadsheet tools to ingest the reports without encountering plain text inside files named `.csv`.

## Requirements

- Windows 10, Windows 11 or supported Windows Server
- Windows PowerShell 5.1 or PowerShell 7+
- Administrative PowerShell recommended for complete results

## PowerShell use

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Collect-WindowsSupportBundle.ps1
```

Examples:

```powershell
.\Collect-WindowsSupportBundle.ps1 -EventLogDays 7 -KeepWorkingFolder
.\Collect-WindowsSupportBundle.ps1 -OutputPath 'C:\Support\Bundles'
.\Collect-WindowsSupportBundle.ps1 -SkipEventLogs
.\Collect-WindowsSupportBundle.ps1 -SkipCompression
.\Collect-WindowsSupportBundle.ps1 -WhatIf
```

## Parameters

| Parameter | Purpose |
|---|---|
| `-OutputPath` | Parent folder for generated bundles |
| `-EventLogDays` | Previous days of event data to collect; valid range 1–30 |
| `-MaxEventsPerLog` | Maximum records collected from each event log |
| `-SkipEventLogs` | Skip System and Application event collection |
| `-SkipCompression` | Leave the support bundle as a folder |
| `-KeepWorkingFolder` | Keep the folder after creating the ZIP |
| `-WhatIf` | Show the collection target without writing files |

## Exit codes

| Code | Meaning |
|---:|---|
| `0` | All requested sections were collected |
| `1` | A fatal error prevented completion |
| `2` | Bundle created with one or more collection warnings |

## Validation

Pull requests and pushes to `main` run a Windows GitHub Actions workflow that:

- Parses every `.ps1` file with PowerShell's native AST parser
- Runs PSScriptAnalyzer and fails on error-severity findings

Runtime output must still be reviewed on representative Windows versions because available CIM classes, event logs and security cmdlets vary by edition and installed roles.

## Safety

The collector is read-only with respect to Windows configuration. It writes report files and deletes only its own working folder after the ZIP has been created and confirmed non-empty.

Generated bundles may contain computer/user names, serial numbers, IP/MAC addresses, installed software, service account names and event details. Never publish a real support bundle in this repository.

## License

Released under the MIT License.
