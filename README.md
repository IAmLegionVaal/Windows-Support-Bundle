# Windows Support Bundle

A single-run PowerShell diagnostic collector for Windows support, troubleshooting and escalation. It gathers useful system evidence into a timestamped folder and creates a ZIP archive that can be reviewed or attached to a support case.

> **Testing note:** This was tested by me to be working. User experience may vary.

## Actual script included

The repository includes the functional collector:

```text
Collect-WindowsSupportBundle.ps1
```

This is not a placeholder or README-only repository. The script performs the collection, logging, validation and archive creation described below.

## What it collects

- Windows version, build, architecture, install date and last boot time
- Manufacturer, model, domain status, processor and memory information
- BIOS details and hardware serial information
- Logical and physical disk information
- Device Manager devices reporting errors
- Local IP configuration, routes, proxy settings and network adapters
- Installed applications and Windows hotfixes
- Windows services and startup commands
- Microsoft Defender, BitLocker and Windows Firewall status
- Pending-restart indicators
- Recent critical, error and warning events from the System and Application logs
- A transcript, warning report, JSON manifest and privacy notice

The script does **not** collect passwords, browser data, saved credentials, email content or personal document contents.

## Requirements

- Windows 10, Windows 11, or a supported Windows Server edition
- Windows PowerShell 5.1 or PowerShell 7+
- Administrative PowerShell is recommended for the most complete results

## Quick start

Open PowerShell in the cloned repository and run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Collect-WindowsSupportBundle.ps1
```

The default output location is:

```text
C:\Users\Public\Documents\WindowsSupportBundles
```

The default result is a file similar to:

```text
WindowsSupportBundle_PC-NAME_20260622_183000.zip
```

## Examples

Collect the default three days of event information:

```powershell
.\Collect-WindowsSupportBundle.ps1
```

Collect seven days and keep both the ZIP and working folder:

```powershell
.\Collect-WindowsSupportBundle.ps1 -EventLogDays 7 -KeepWorkingFolder
```

Write the bundle to another directory:

```powershell
.\Collect-WindowsSupportBundle.ps1 -OutputPath 'C:\Support\Bundles'
```

Skip event logs:

```powershell
.\Collect-WindowsSupportBundle.ps1 -SkipEventLogs
```

Create an uncompressed evidence folder:

```powershell
.\Collect-WindowsSupportBundle.ps1 -SkipCompression
```

Preview the target operation without collecting anything:

```powershell
.\Collect-WindowsSupportBundle.ps1 -WhatIf
```

## Parameters

| Parameter | Purpose |
|---|---|
| `-OutputPath` | Parent folder for generated bundles |
| `-EventLogDays` | Previous days of event data to collect; valid range is 1-30 |
| `-MaxEventsPerLog` | Maximum records collected from each event log |
| `-SkipEventLogs` | Skips System and Application event collection |
| `-SkipCompression` | Leaves the support bundle as a folder |
| `-KeepWorkingFolder` | Keeps the folder after creating the ZIP |
| `-WhatIf` | Shows the collection target without making output files |

## Generated structure

```text
WindowsSupportBundle_<Computer>_<Timestamp>/
├── CollectionContext.json
├── Manifest.json
├── README_FIRST.txt
├── System/
├── Hardware/
├── Storage/
├── Network/
├── Security/
├── Software/
├── Services/
├── Events/
└── Logs/
```

## Exit codes

| Code | Meaning |
|---:|---|
| `0` | All requested sections were collected |
| `1` | A fatal error prevented successful completion |
| `2` | The bundle was created, but one or more sections produced warnings |

A code of `2` can occur when a Windows edition, device type, permissions level or security product does not provide one of the requested data sources. Review `Logs\CollectionErrors.csv` for details.

## Safety and privacy

This collector is read-only with respect to Windows configuration. It creates report files and may delete only its own temporary working folder after validating the ZIP archive.

Generated bundles can contain:

- Computer and user names
- BIOS and disk serial numbers
- Local IP and MAC addresses
- Installed software
- Service account names
- Windows event messages

Always review the output before uploading or sending it to another person. Do not publish real support bundles in this repository.

## Disclaimer

Use this project at your own risk. Results can differ between Windows versions, editions, hardware, permissions, security products and organisational policies. Test in a safe environment and review the generated data before sharing it.

## License

Released under the MIT License.
