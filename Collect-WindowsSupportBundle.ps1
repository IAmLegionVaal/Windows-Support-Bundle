<#
.SYNOPSIS
Collects a read-only Windows support bundle.

.DESCRIPTION
Creates a timestamped diagnostic folder and ZIP archive containing Windows,
hardware, storage, networking, software, services, security status and recent
event information. The script does not perform repairs or change Windows
configuration.

.PARAMETER OutputPath
Parent folder for generated bundles.

.PARAMETER EventLogDays
Number of previous days of warning, error and critical events to collect.

.PARAMETER MaxEventsPerLog
Maximum events collected from each log.

.PARAMETER SkipEventLogs
Skips Application and System event collection.

.PARAMETER SkipCompression
Leaves the collected files in a folder instead of creating a ZIP archive.

.PARAMETER KeepWorkingFolder
Keeps the uncompressed folder after the ZIP archive is created.

.EXAMPLE
.\Collect-WindowsSupportBundle.ps1

.EXAMPLE
.\Collect-WindowsSupportBundle.ps1 -EventLogDays 7 -KeepWorkingFolder

.NOTES
Run from an elevated PowerShell window for the most complete results.
Review the bundle before sharing it because it contains system identifiers and
local network information.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath = "$env:PUBLIC\Documents\WindowsSupportBundles",

    [ValidateRange(1, 30)]
    [int]$EventLogDays = 3,

    [ValidateRange(10, 5000)]
    [int]$MaxEventsPerLog = 500,

    [switch]$SkipEventLogs,
    [switch]$SkipCompression,
    [switch]$KeepWorkingFolder
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$script:Errors = New-Object System.Collections.Generic.List[object]
$script:TranscriptStarted = $false
$startedAt = Get-Date

function Write-Status {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )

    $prefix = switch ($Level) {
        'Success' { '[OK]' }
        'Warning' { '[WARN]' }
        'Error'   { '[ERROR]' }
        default   { '[INFO]' }
    }
    $colour = switch ($Level) {
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error'   { 'Red' }
        default   { 'Cyan' }
    }
    Write-Host "$prefix $Message" -ForegroundColor $colour
}

function Test-IsAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Add-CollectionError {
    param([string]$Section, [System.Management.Automation.ErrorRecord]$Record)

    $script:Errors.Add([pscustomobject]@{
        Time     = Get-Date
        Section  = $Section
        Message  = $Record.Exception.Message
        Category = [string]$Record.CategoryInfo.Category
    })
    Write-Status "$Section failed: $($Record.Exception.Message)" Warning
}

function Save-TextResult {
    param([string]$Name, [string]$Path, [scriptblock]$Action)

    try {
        Write-Status "Collecting $Name..."
        & $Action | Out-File -FilePath $Path -Encoding UTF8 -Width 4096
    }
    catch {
        Add-CollectionError -Section $Name -Record $_
        "Collection failed: $($_.Exception.Message)" |
            Out-File -FilePath $Path -Encoding UTF8
    }
}

function Save-CsvResult {
    param([string]$Name, [string]$Path, [scriptblock]$Action)

    try {
        Write-Status "Collecting $Name..."
        $rows = @(& $Action)
        if ($rows.Count -eq 0) {
            'No records returned.' | Out-File -FilePath $Path -Encoding UTF8
        }
        else {
            $rows | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
        }
    }
    catch {
        Add-CollectionError -Section $Name -Record $_
        "Collection failed: $($_.Exception.Message)" |
            Out-File -FilePath $Path -Encoding UTF8
    }
}

function Get-InstalledApplication {
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    foreach ($path in $paths) {
        Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName } |
            Select-Object DisplayName, DisplayVersion, Publisher, InstallDate,
                InstallLocation
    }
}

function Get-PendingRebootState {
    $cbs = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
    $wu = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    $rename = $false

    try {
        $value = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' `
            -Name PendingFileRenameOperations -ErrorAction Stop
        $rename = $null -ne $value.PendingFileRenameOperations
    }
    catch {
        $rename = $false
    }

    [pscustomobject]@{
        ComponentBasedServicing = $cbs
        WindowsUpdate           = $wu
        PendingFileRename       = $rename
        RebootPending           = ($cbs -or $wu -or $rename)
    }
}

try {
    if ($env:OS -ne 'Windows_NT') {
        throw 'This script can only run on Microsoft Windows.'
    }
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        throw 'Windows PowerShell 5.1 or PowerShell 7 or newer is required.'
    }

    $isAdmin = Test-IsAdministrator
    if (-not $isAdmin) {
        Write-Status 'Not running as administrator. Some results may be incomplete.' Warning
    }

    $computer = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { 'UnknownComputer' }
    $safeComputer = $computer -replace '[^A-Za-z0-9._-]', '_'
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $bundleName = "WindowsSupportBundle_${safeComputer}_${stamp}"
    $bundleRoot = Join-Path $OutputPath $bundleName
    $archivePath = Join-Path $OutputPath ($bundleName + '.zip')

    if (-not $PSCmdlet.ShouldProcess($bundleRoot, 'Collect Windows diagnostic information')) {
        return
    }

    $folders = @(
        $OutputPath,
        $bundleRoot,
        (Join-Path $bundleRoot 'System'),
        (Join-Path $bundleRoot 'Hardware'),
        (Join-Path $bundleRoot 'Storage'),
        (Join-Path $bundleRoot 'Network'),
        (Join-Path $bundleRoot 'Security'),
        (Join-Path $bundleRoot 'Software'),
        (Join-Path $bundleRoot 'Services'),
        (Join-Path $bundleRoot 'Events'),
        (Join-Path $bundleRoot 'Logs')
    )
    foreach ($folder in $folders) {
        New-Item -Path $folder -ItemType Directory -Force | Out-Null
    }

    try {
        Start-Transcript -Path (Join-Path $bundleRoot 'Logs\Transcript.txt') -Force | Out-Null
        $script:TranscriptStarted = $true
    }
    catch {
        Write-Status "Transcript could not start: $($_.Exception.Message)" Warning
    }

    Write-Status "Creating support bundle for $computer"

    [pscustomobject]@{
        ComputerName      = $computer
        StartedAt         = $startedAt
        IsAdministrator   = $isAdmin
        UserName          = [Environment]::UserName
        PowerShellVersion = [string]$PSVersionTable.PSVersion
    } | ConvertTo-Json | Out-File (Join-Path $bundleRoot 'CollectionContext.json') -Encoding UTF8

    Save-TextResult 'operating system' (Join-Path $bundleRoot 'System\OperatingSystem.txt') {
        Get-CimInstance Win32_OperatingSystem |
            Format-List Caption, Version, BuildNumber, OSArchitecture, InstallDate,
                LastBootUpTime, WindowsDirectory, Locale, OSLanguage
    }

    Save-TextResult 'computer system' (Join-Path $bundleRoot 'System\ComputerSystem.txt') {
        Get-CimInstance Win32_ComputerSystem |
            Format-List Manufacturer, Model, SystemType, Domain, PartOfDomain,
                TotalPhysicalMemory, NumberOfProcessors, NumberOfLogicalProcessors,
                HypervisorPresent
    }

    Save-TextResult 'pending reboot state' (Join-Path $bundleRoot 'System\PendingReboot.txt') {
        Get-PendingRebootState | Format-List
    }

    Save-TextResult 'BIOS' (Join-Path $bundleRoot 'Hardware\BIOS.txt') {
        Get-CimInstance Win32_BIOS |
            Format-List Manufacturer, SMBIOSBIOSVersion, ReleaseDate, SerialNumber
    }

    Save-CsvResult 'processors' (Join-Path $bundleRoot 'Hardware\Processors.csv') {
        Get-CimInstance Win32_Processor |
            Select-Object Name, Manufacturer, NumberOfCores, NumberOfLogicalProcessors,
                MaxClockSpeed, LoadPercentage, Status
    }

    Save-CsvResult 'memory modules' (Join-Path $bundleRoot 'Hardware\Memory.csv') {
        Get-CimInstance Win32_PhysicalMemory |
            Select-Object DeviceLocator, Manufacturer, PartNumber, SerialNumber,
                Capacity, Speed, ConfiguredClockSpeed
    }

    Save-CsvResult 'device errors' (Join-Path $bundleRoot 'Hardware\DeviceErrors.csv') {
        Get-CimInstance Win32_PnPEntity |
            Where-Object { $_.ConfigManagerErrorCode -ne 0 } |
            Select-Object Name, PNPClass, Manufacturer, Status,
                ConfigManagerErrorCode, DeviceID
    }

    Save-CsvResult 'logical disks' (Join-Path $bundleRoot 'Storage\LogicalDisks.csv') {
        Get-CimInstance Win32_LogicalDisk |
            Select-Object DeviceID, VolumeName, FileSystem, DriveType,
                Size, FreeSpace, Status
    }

    Save-CsvResult 'physical disks' (Join-Path $bundleRoot 'Storage\PhysicalDisks.csv') {
        Get-CimInstance Win32_DiskDrive |
            Select-Object Index, Model, InterfaceType, MediaType,
                SerialNumber, FirmwareRevision, Size, Status
    }

    Save-TextResult 'IP configuration' (Join-Path $bundleRoot 'Network\IPConfiguration.txt') {
        ipconfig.exe /all 2>&1
    }

    Save-TextResult 'routing table' (Join-Path $bundleRoot 'Network\RoutingTable.txt') {
        route.exe print 2>&1
    }

    Save-TextResult 'proxy configuration' (Join-Path $bundleRoot 'Network\ProxyConfiguration.txt') {
        netsh.exe winhttp show proxy 2>&1
        Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' `
            -ErrorAction SilentlyContinue |
            Select-Object ProxyEnable, ProxyServer, AutoConfigURL, AutoDetect |
            Format-List
    }

    Save-CsvResult 'network adapters' (Join-Path $bundleRoot 'Network\NetworkAdapters.csv') {
        Get-CimInstance Win32_NetworkAdapter |
            Where-Object { $_.PhysicalAdapter -or $_.NetEnabled } |
            Select-Object Name, Manufacturer, MACAddress, AdapterType,
                NetEnabled, NetConnectionStatus, Speed
    }

    Save-CsvResult 'installed applications' (Join-Path $bundleRoot 'Software\InstalledApplications.csv') {
        Get-InstalledApplication | Sort-Object DisplayName, DisplayVersion -Unique
    }

    Save-CsvResult 'installed hotfixes' (Join-Path $bundleRoot 'Software\InstalledHotfixes.csv') {
        Get-HotFix | Sort-Object InstalledOn -Descending |
            Select-Object HotFixID, Description, InstalledBy, InstalledOn
    }

    Save-CsvResult 'services' (Join-Path $bundleRoot 'Services\Services.csv') {
        Get-CimInstance Win32_Service |
            Select-Object Name, DisplayName, State, StartMode, Status,
                StartName, ProcessId, ExitCode
    }

    Save-CsvResult 'startup commands' (Join-Path $bundleRoot 'Services\StartupCommands.csv') {
        Get-CimInstance Win32_StartupCommand |
            Select-Object Name, Command, Location, User
    }

    Save-TextResult 'Microsoft Defender status' (Join-Path $bundleRoot 'Security\DefenderStatus.txt') {
        if (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue) {
            Get-MpComputerStatus |
                Format-List AMServiceEnabled, AntivirusEnabled,
                    RealTimeProtectionEnabled, BehaviorMonitorEnabled,
                    AntivirusSignatureVersion, AntivirusSignatureLastUpdated,
                    QuickScanAge, FullScanAge
        }
        else {
            'Microsoft Defender PowerShell cmdlets are unavailable.'
        }
    }

    Save-TextResult 'BitLocker status' (Join-Path $bundleRoot 'Security\BitLockerStatus.txt') {
        if (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue) {
            Get-BitLockerVolume |
                Format-List MountPoint, VolumeStatus, ProtectionStatus,
                    EncryptionMethod, EncryptionPercentage, LockStatus
        }
        else {
            manage-bde.exe -status 2>&1
        }
    }

    Save-CsvResult 'firewall profiles' (Join-Path $bundleRoot 'Security\FirewallProfiles.csv') {
        if (-not (Get-Command Get-NetFirewallProfile -ErrorAction SilentlyContinue)) {
            throw 'Windows Firewall PowerShell cmdlets are unavailable.'
        }
        Get-NetFirewallProfile |
            Select-Object Name, Enabled, DefaultInboundAction,
                DefaultOutboundAction, NotifyOnListen, LogFileName
    }

    if (-not $SkipEventLogs) {
        $cutoff = (Get-Date).AddDays(-$EventLogDays)
        foreach ($logName in @('System', 'Application')) {
            Save-CsvResult "$logName events" `
                (Join-Path $bundleRoot "Events\${logName}_CriticalErrorWarning.csv") {
                try {
                    Get-WinEvent -FilterHashtable @{
                        LogName = $logName
                        StartTime = $cutoff
                        Level = 1, 2, 3
                    } -MaxEvents $MaxEventsPerLog -ErrorAction Stop |
                        Select-Object TimeCreated, Id, LevelDisplayName,
                            ProviderName, TaskDisplayName, Message
                }
                catch {
                    if ($_.FullyQualifiedErrorId -notlike '*NoMatchingEventsFound*') {
                        throw
                    }
                }
            }
        }
    }

    $script:Errors | Export-Csv (Join-Path $bundleRoot 'Logs\CollectionErrors.csv') `
        -NoTypeInformation -Encoding UTF8

    $files = @(Get-ChildItem $bundleRoot -File -Recurse -ErrorAction SilentlyContinue)
    [ordered]@{
        BundleName = $bundleName
        ComputerName = $computer
        StartedAt = $startedAt
        CompletedAt = Get-Date
        IsAdministrator = $isAdmin
        FileCount = $files.Count
        CollectionErrorCount = $script:Errors.Count
        ExitCodeMeaning = [ordered]@{
            Zero = 'All requested sections collected'
            One = 'Fatal error'
            Two = 'Bundle created with one or more collection warnings'
        }
    } | ConvertTo-Json -Depth 4 |
        Out-File (Join-Path $bundleRoot 'Manifest.json') -Encoding UTF8

    @"
Windows Support Bundle
======================
Computer: $computer
Created:  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss K')
Warnings: $($script:Errors.Count)

Privacy notice
--------------
This bundle may contain computer names, usernames, hardware serial numbers,
local IP addresses, MAC addresses, installed applications and event messages.
Review every file before sharing the bundle. The script does not collect
passwords, browser data, email content, personal documents or saved credentials.
"@ | Out-File (Join-Path $bundleRoot 'README_FIRST.txt') -Encoding UTF8

    if ($script:TranscriptStarted) {
        Stop-Transcript | Out-Null
        $script:TranscriptStarted = $false
    }

    if (-not $SkipCompression) {
        Write-Status 'Compressing support bundle...'
        Compress-Archive -Path $bundleRoot -DestinationPath $archivePath `
            -CompressionLevel Optimal -Force

        if (-not (Test-Path $archivePath)) {
            throw 'ZIP archive validation failed.'
        }

        if (-not $KeepWorkingFolder) {
            Remove-Item $bundleRoot -Recurse -Force
        }
        Write-Status "Support bundle created: $archivePath" Success
    }
    else {
        Write-Status "Support bundle folder created: $bundleRoot" Success
    }

    if ($script:Errors.Count -gt 0) {
        Write-Status "$($script:Errors.Count) section(s) produced warnings." Warning
        exit 2
    }
    exit 0
}
catch {
    if ($script:TranscriptStarted) {
        try { Stop-Transcript | Out-Null } catch { }
    }
    Write-Status $_.Exception.Message Error
    exit 1
}
