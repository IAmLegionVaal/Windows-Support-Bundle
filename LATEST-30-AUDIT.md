# Latest 30 Windows Repositories — Audit

**Audit date:** 22 June 2026  
**Owner:** Dewald Pretorius / IAmLegionVaal

## Audit standard

Each repository was checked for:

- A real PowerShell script rather than a placeholder.
- Scope matching the repository name and README.
- A safe diagnostic or inventory default where appropriate.
- Explicit switches for repair, removal, copy, export, optimisation, upgrade or apply actions.
- `SupportsShouldProcess` / `-WhatIf` where practical for changes.
- Administrator checks for privileged operations.
- Logging or timestamped reports.
- Meaningful exit codes.
- Safety boundaries for destructive or disruptive operations.
- A no-menu `Run-OneClick.bat` launcher.

## Results

| # | Repository | Intended role | Result |
|---:|---|---|---|
| 1 | Windows-Support-Bundle | Read-only support evidence collector | Passed |
| 2 | OneDrive-Repair | Supported OneDrive reset and restart | Passed; hardened |
| 3 | Windows-Print-Services-Repair | Spooler and optional queue repair | Passed; hardened |
| 4 | Windows-PC-Handover-Test | Read-only workstation handover checks | Passed |
| 5 | Windows-User-Data-Migration | Planned or explicit user-data copy | Passed |
| 6 | Windows-Driver-Backup | Driver inventory and PnPUtil export | Passed; hardened |
| 7 | Windows-Firewall-Repair | Firewall service and profile readiness | Passed; hardened |
| 8 | Windows-WMI-Repair | WMI service and performance-class recovery | Passed; hardened |
| 9 | Windows-Local-Account-Audit | Read-only local account and group audit | Passed |
| 10 | Windows-Stale-Profile-Cleanup | Report or confirmed stale-profile removal | Passed |
| 11 | Windows-User-Profile-Repair | Guarded profile State and RefCount repair | Passed; hardened |
| 12 | Remote-Work-Readiness-Test | Read-only DNS, HTTPS, VPN and client checks | Passed |
| 13 | Windows-BSOD-Analyzer | Read-only crash evidence and optional dump copy | Passed |
| 14 | Windows-Performance-Analyzer | Read-only performance snapshot | Passed |
| 15 | Windows-Startup-Analyzer | Read-only startup inventory and events | Passed |
| 16 | Windows-Large-File-Finder | Read-only large-file reporting | Passed |
| 17 | Windows-Disk-Optimization | Volume optimisation and component cleanup | Passed |
| 18 | Windows-Activation-Diagnostics | Read-only Windows licensing report | Passed |
| 19 | Windows-Audio-Repair | Audio service recovery | Passed; hardened |
| 20 | Windows-Bluetooth-Repair | Bluetooth service recovery | Passed; hardened |
| 21 | Windows-RDP-Repair | RDP readiness repair when already enabled | Passed; hardened |
| 22 | Windows-Search-Repair | Windows Search service recovery | Passed; hardened |
| 23 | Windows-Time-Repair | Time service, sync and optional timezone repair | Passed; hardened |
| 24 | Windows-PC-Provisioning | Inventory and explicitly selected provisioning settings | Passed; hardened |
| 25 | Windows-Application-Updater | WinGet application inventory and upgrade | Passed; hardened |
| 26 | Microsoft-Store-Repair | Store, App Installer and WinGet source repair | Passed; hardened |
| 27 | Windows-Security-Audit | Read-only Windows protection audit | Passed |
| 28 | Windows-Network-Repair | DNS, DHCP, adapter and optional full stack repair | Passed |
| 29 | Windows-Update-Repair | Guarded Windows Update cache and service reset | Passed |
| 30 | Windows-System-Health-Repair | DISM, SFC and CHKDSK health workflow | Passed |

## Corrections made during this audit

Fourteen repositories received source corrections or stronger verification:

- OneDrive-Repair
- Windows-Print-Services-Repair
- Windows-Driver-Backup
- Windows-Firewall-Repair
- Windows-WMI-Repair
- Windows-User-Profile-Repair
- Windows-Audio-Repair
- Windows-Bluetooth-Repair
- Windows-RDP-Repair
- Windows-Search-Repair
- Windows-Time-Repair
- Windows-PC-Provisioning
- Windows-Application-Updater
- Microsoft-Store-Repair

Key corrections included:

- Preventing the Print Spooler from being left stopped after a failed queue cleanup.
- Replacing silent service-start failures with checked operations and post-repair validation.
- Verifying OneDrive restart, driver exports, profile registry values, firewall profiles and service states.
- Making RDP firewall-rule discovery work without depending only on an English display-group name.
- Making WinGet application operations non-interactive and checking their exit codes.
- Correcting Microsoft Store package inventory and validating Store/App Installer registration.
- Preserving the original signed-in user SID when the profile-repair launcher elevates.

## One-click use

Every repository now includes:

```text
Run-OneClick.bat
```

The launcher runs the intended safe action directly, displays the resulting exit code, and keeps the window open. Privileged repair launchers request elevation. User-context repairs such as OneDrive and Microsoft Store remain in the signed-in user context.

`Windows-PC-Provisioning` intentionally runs its safe inventory through the one-click launcher. Computer names, package IDs and organisation-specific provisioning choices must still be supplied explicitly rather than guessed.

## Important validation boundary

This was a complete source and logic audit through the connected GitHub repositories. The Windows-specific commands could not be executed from the audit environment. The scripts are therefore source-reviewed and corrected, but this report is not a claim that every workflow was runtime-tested on every Windows edition, hardware model, domain, tenant or policy configuration.

Use a non-critical Windows test machine or VM for the first run, review the generated logs, and use `-WhatIf` for guarded actions where supported.
