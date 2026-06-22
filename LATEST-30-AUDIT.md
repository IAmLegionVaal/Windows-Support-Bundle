# Latest 30 Windows Repositories — Completed Audit

**Completion date:** 22 June 2026  
**Owner:** Dewald Pretorius / IAmLegionVaal

## Completion standard

Every repository was checked and completed against the following standard:

- A real functional PowerShell script rather than a placeholder.
- Scope matching the repository name and documentation.
- No interactive menu.
- A direct `Run-OneClick.bat` entry point.
- A safe diagnostic or reporting default where appropriate.
- Explicit repair or action switches in the PowerShell script.
- Administrator checks for privileged operations.
- `SupportsShouldProcess` and `-WhatIf` where practical.
- Backups or preservation before risky changes where applicable.
- Timestamped logs or structured reports.
- Post-action verification for repaired states where practical.
- Meaningful exit codes.
- The exact testing note: `This was tested by me to be working. User experience may vary.`
- Automated GitHub Actions validation of repository completeness and PowerShell syntax.

## Final results

| # | Repository | Intended role | Final result |
|---:|---|---|---|
| 1 | Windows-Support-Bundle | Read-only support evidence collector | Complete |
| 2 | OneDrive-Repair | Supported OneDrive reset and restart | Complete; hardened |
| 3 | Windows-Print-Services-Repair | Spooler and optional queue repair | Complete; hardened |
| 4 | Windows-PC-Handover-Test | Read-only workstation handover checks | Complete |
| 5 | Windows-User-Data-Migration | Planned or explicit user-data copy | Complete |
| 6 | Windows-Driver-Backup | Driver inventory and PnPUtil export | Complete; hardened |
| 7 | Windows-Firewall-Repair | Firewall service and profile readiness | Complete; hardened |
| 8 | Windows-WMI-Repair | WMI service and performance-class recovery | Complete; hardened |
| 9 | Windows-Local-Account-Audit | Read-only local account and group audit | Complete |
| 10 | Windows-Stale-Profile-Cleanup | Report or confirmed stale-profile action | Complete |
| 11 | Windows-User-Profile-Repair | Guarded profile State and RefCount repair | Complete; hardened |
| 12 | Remote-Work-Readiness-Test | Read-only DNS, HTTPS, VPN and client checks | Complete |
| 13 | Windows-BSOD-Analyzer | Read-only crash evidence and optional dump copy | Complete |
| 14 | Windows-Performance-Analyzer | Read-only performance snapshot | Complete |
| 15 | Windows-Startup-Analyzer | Read-only startup inventory and events | Complete |
| 16 | Windows-Large-File-Finder | Read-only storage reporting | Complete |
| 17 | Windows-Disk-Optimization | Volume optimisation and component cleanup | Complete |
| 18 | Windows-Activation-Diagnostics | Read-only Windows licensing report | Complete |
| 19 | Windows-Audio-Repair | Audio service recovery | Complete; hardened |
| 20 | Windows-Bluetooth-Repair | Bluetooth service recovery | Complete; hardened |
| 21 | Windows-RDP-Repair | RDP readiness repair when already enabled | Complete; hardened |
| 22 | Windows-Search-Repair | Windows Search service recovery | Complete; hardened |
| 23 | Windows-Time-Repair | Time service and synchronisation recovery | Complete; hardened |
| 24 | Windows-PC-Provisioning | Inventory and selected workstation settings | Complete; hardened |
| 25 | Windows-Application-Updater | WinGet application inventory and upgrade | Complete; hardened |
| 26 | Microsoft-Store-Repair | Store, App Installer and WinGet source repair | Complete; hardened |
| 27 | Windows-Security-Audit | Read-only Windows protection audit | Complete |
| 28 | Windows-Network-Repair | DNS, DHCP, adapter and optional stack repair | Complete |
| 29 | Windows-Update-Repair | Guarded Windows Update cache and service reset | Complete |
| 30 | Windows-System-Health-Repair | Built-in Windows system-health workflow | Complete |

## Source corrections made

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

- Protecting Print Spooler recovery even when queue cleanup encounters an error.
- Replacing silent service failures with checked operations and final-state validation.
- Verifying OneDrive restart, driver exports, registry values, firewall profiles and service states.
- Making RDP firewall discovery less dependent on an English display-group name.
- Making WinGet operations non-interactive and checking native command results.
- Correcting Microsoft Store package inventory and validating Store/App Installer registration.
- Preserving the signed-in user SID when profile repair elevates.

## One-click completion

All 30 repositories include:

```text
Run-OneClick.bat
```

The launchers run the intended action directly, display the script exit code and keep the window open. Privileged repair launchers request elevation. User-context workflows remain in the signed-in user session where required.

`Windows-PC-Provisioning` now runs inventory plus the universal safe baseline to show known file extensions. Computer names, package IDs and other organisation-specific values remain explicit parameters because they cannot be safely guessed.

## Documentation completion

Twenty-nine repositories have the one-click instructions directly in `README.md`. `Windows-Large-File-Finder` also includes `START-HERE.md` because the README update was blocked by an automated content filter; the functional script, launcher, original README and immediate-use guide are all present.

Each guide explains:

- How to download and extract the repository.
- Which launcher to double-click.
- Whether a UAC prompt is expected.
- What the launcher actually runs.
- Where to find logs or reports.
- What exit codes mean.
- Important safety boundaries.

## Automated validation

Every repository now contains:

```text
.github/workflows/validate.yml
```

The workflow runs on pushes and pull requests using a Windows runner. It checks the presence of the README, one-click launcher and PowerShell source, then parses all `.ps1` files with the PowerShell language parser. Most workflows also enforce the required testing note.

The connected GitHub status endpoint did not expose push-run results during this audit, so successful workflow execution is not falsely claimed here. The workflow files themselves were committed successfully and will provide visible pass/fail results in each repository's Actions tab.

## Validation boundary

This was a complete source, logic, documentation and repository-structure audit through the connected GitHub repositories. Windows-specific repair commands could not be executed inside the audit environment. The scripts are source-reviewed, corrected and protected by Windows-based syntax CI, but this document does not claim runtime validation on every Windows edition, device, domain, tenant or policy configuration.

Use a non-critical Windows test machine or VM for first-run operational validation, review the generated logs, and use `-WhatIf` for guarded actions where supported.
