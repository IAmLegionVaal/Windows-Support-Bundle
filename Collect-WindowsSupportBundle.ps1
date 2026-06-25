#requires -Version 5.1

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

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:CollectionErrors = New-Object System.Collections.Generic.List[object]
$script:TranscriptStarted = $false
$startedAt = Get-Date

function Write-Status {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Info','Success','Warning','Error')][string]$Level = 'Info'
    )

    $prefix = switch ($Level) {
        Success { '[OK]' }
        Warning { '[WARN]' }
        Error   { '[ERROR]' }
        default { '[INFO]' }
    }
    Write-Host "$prefix $Message"
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

function Protect-SensitiveText {
    param([AllowNull()][string]$Text)

    if ([string]::IsNullOrEmpty($Text)) {
        return $Text
    }

    $redacted = $Text -replace '(?i)(password|passwd|pwd|token|api[-_]?key|secret|client[-_]?secret)\s*([=:])\s*("[^"]*"|''[^'']*''|[^\s;,]+)', '$1$2<redacted>'
    $redacted = $redacted -replace '(?i)(--?(?:password|passwd|pwd|token|api[-_]?key|secret|client[-_]?secret)|/(?:password|passwd|pwd|token))\s+("[^"]*"|''[^'']*''|[^\s;,]+)', '$1 <redacted>'
    return $redacted
}

function Add-CollectionError {
    param(
        [Parameter(Mandatory)][string]$Section,
        [Parameter(Mandatory)][System.Management.Automation.ErrorRecord]$Record
    )

    $script:CollectionErrors.Add([pscustomobject]@{
        Time = Get-Date
        Section = $Section
        Message = Protect-SensitiveText $Record.Exception.Message
        Category = [string]$Record.CategoryInfo.Category
    })
    Write-Status "$Section failed: $($Record.Exception.Message)" Warning
}

function Save-TextResult {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][scriptblock]$Action
    )

    try {
        Write-Status "Collecting $Name..."
        $content = (& $Action | Out-String -Width 4096)
        Protect-SensitiveText $content | Out-File -LiteralPath $Path -Encoding UTF8 -Width 4096
    }
    catch {
        Add-CollectionError -Section $Name -Record $_
        "Collection failed. Review Logs\CollectionErrors.csv." |
            Out-File -LiteralPath $Path -Encoding UTF8
    }
}

function Save-CsvResult {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][scriptblock]$Action
    )

    try {
        Write-Status "Collecting $Name..."
        $rows = @(& $Action)

        if ($rows.Count -eq 0) {
            @([pscustomobject]@{
                CollectionStatus = 'NoData'
                Details = 'No records returned.'
            }) | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
        }
        else {
            $rows | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
        }
    }
    catch {
        Add-CollectionError -Section $Name -Record $_
        @([pscustomobject]@{
            CollectionStatus = 'Failed'
            Details = 'Collection failed. Review Logs\CollectionErrors.csv.'
        }) | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
    }
}

function Get-InstalledApplication {
    foreach ($path in @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )) {
        Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName } |
            Select-Object -Property DisplayName,DisplayVersion,Publisher,InstallDate,InstallLocation
    }
}

function Get-PendingRebootState {
    $cbs = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
    $windowsUpdate = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    $pendingRename = $false

    try {
        $sessionManager = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' `
            -Name PendingFileRenameOperations -ErrorAction Stop
        $pendingRename = $null -ne $sessionManager.PendingFileRenameOperations
    }
    catch {
        $pendingRename = $false
    }

    [pscustomobject]@{
        ComponentBasedServicing = $cbs
        WindowsUpdate = $windowsUpdate
        PendingFileRename = $pendingRename
        RebootPending = ($cbs -or $windowsUpdate -or $pendingRename)
    }
}

try {
    if ($env:OS -ne 'Windows_NT') {
        throw 'This script can only run on Microsoft Windows.'
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

    foreach ($folder in @(
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
    )) {
        New-Item -Path $folder -ItemType Directory -Force | Out-Null
    }

    try {
        Start-Transcript -Path (Join-Path $bundleRoot 'Logs\Transcript.txt') -Force | Out-Null
        $script:TranscriptStarted = $true
    }
    catch {
        Write-Status "Transcript could not start: $($_.Exception.Message)" Warning
    }

    [pscustomobject]@{
        ComputerName = $computer
        StartedAt = $startedAt
        IsAdministrator = $isAdmin
        UserName = [Environment]::UserName
        PowerShellVersion = [string]$PSVersionTable.PSVersion
    } | ConvertTo-Json | Out-File (Join-Path $bundleRoot 'CollectionContext.json') -Encoding UTF8

    Save-TextResult 'operating system' (Join-Path $bundleRoot 'System\OperatingSystem.txt') {
        Get-CimInstance Win32_OperatingSystem |
            Format-List -Property Caption,Version,BuildNumber,OSArchitecture,InstallDate,LastBootUpTime,WindowsDirectory,Locale,OSLanguage
    }
    Save-TextResult 'computer system' (Join-Path $bundleRoot 'System\ComputerSystem.txt') {
        Get-CimInstance Win32_ComputerSystem |
            Format-List -Property Manufacturer,Model,SystemType,Domain,PartOfDomain,TotalPhysicalMemory,NumberOfProcessors,NumberOfLogicalProcessors,HypervisorPresent
    }
    Save-TextResult 'pending reboot state' (Join-Path $bundleRoot 'System\PendingReboot.txt') { Get-PendingRebootState | Format-List }
    Save-TextResult 'BIOS' (Join-Path $bundleRoot 'Hardware\BIOS.txt') {
        Get-CimInstance Win32_BIOS | Format-List -Property Manufacturer,SMBIOSBIOSVersion,ReleaseDate,SerialNumber
    }
    Save-CsvResult 'processors' (Join-Path $bundleRoot 'Hardware\Processors.csv') {
        Get-CimInstance Win32_Processor | Select-Object -Property Name,Manufacturer,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed,LoadPercentage,Status
    }
    Save-CsvResult 'memory modules' (Join-Path $bundleRoot 'Hardware\Memory.csv') {
        Get-CimInstance Win32_PhysicalMemory | Select-Object -Property DeviceLocator,Manufacturer,PartNumber,SerialNumber,Capacity,Speed,ConfiguredClockSpeed
    }
    Save-CsvResult 'device errors' (Join-Path $bundleRoot 'Hardware\DeviceErrors.csv') {
        Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 } |
            Select-Object -Property Name,PNPClass,Manufacturer,Status,ConfigManagerErrorCode,DeviceID
    }
    Save-CsvResult 'logical disks' (Join-Path $bundleRoot 'Storage\LogicalDisks.csv') {
        Get-CimInstance Win32_LogicalDisk | Select-Object -Property DeviceID,VolumeName,FileSystem,DriveType,Size,FreeSpace,Status
    }
    Save-CsvResult 'physical disks' (Join-Path $bundleRoot 'Storage\PhysicalDisks.csv') {
        Get-CimInstance Win32_DiskDrive | Select-Object -Property Index,Model,InterfaceType,MediaType,SerialNumber,FirmwareRevision,Size,Status
    }
    Save-TextResult 'IP configuration' (Join-Path $bundleRoot 'Network\IPConfiguration.txt') { ipconfig.exe /all 2>&1 }
    Save-TextResult 'routing table' (Join-Path $bundleRoot 'Network\RoutingTable.txt') { route.exe print 2>&1 }
    Save-TextResult 'proxy configuration' (Join-Path $bundleRoot 'Network\ProxyConfiguration.txt') {
        netsh.exe winhttp show proxy 2>&1
        Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue |
            Select-Object -Property ProxyEnable,ProxyServer,AutoConfigURL,AutoDetect | Format-List
    }
    Save-CsvResult 'network adapters' (Join-Path $bundleRoot 'Network\NetworkAdapters.csv') {
        Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.PhysicalAdapter -or $_.NetEnabled } |
            Select-Object -Property Name,Manufacturer,MACAddress,AdapterType,NetEnabled,NetConnectionStatus,Speed
    }
    Save-CsvResult 'installed applications' (Join-Path $bundleRoot 'Software\InstalledApplications.csv') {
        Get-InstalledApplication | Sort-Object -Property DisplayName,DisplayVersion -Unique
    }
    Save-CsvResult 'installed hotfixes' (Join-Path $bundleRoot 'Software\InstalledHotfixes.csv') {
        Get-HotFix | Sort-Object -Property InstalledOn -Descending | Select-Object -Property HotFixID,Description,InstalledBy,InstalledOn
    }
    Save-CsvResult 'services' (Join-Path $bundleRoot 'Services\Services.csv') {
        Get-CimInstance Win32_Service | Select-Object -Property Name,DisplayName,State,StartMode,Status,StartName,ProcessId,ExitCode
    }
    Save-CsvResult 'startup commands' (Join-Path $bundleRoot 'Services\StartupCommands.csv') {
        Get-CimInstance Win32_StartupCommand | ForEach-Object {
            [pscustomobject]@{
                Name = $_.Name
                Command = Protect-SensitiveText -Text ([string]$_.Command)
                Location = $_.Location
                User = $_.User
            }
        }
    }
    Save-TextResult 'Microsoft Defender status' (Join-Path $bundleRoot 'Security\DefenderStatus.txt') {
        if (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue) {
            Get-MpComputerStatus | Format-List -Property AMServiceEnabled,AntivirusEnabled,RealTimeProtectionEnabled,BehaviorMonitorEnabled,AntivirusSignatureVersion,AntivirusSignatureLastUpdated,QuickScanAge,FullScanAge
        }
        else { 'Microsoft Defender PowerShell cmdlets are unavailable.' }
    }
    Save-TextResult 'BitLocker status' (Join-Path $bundleRoot 'Security\BitLockerStatus.txt') {
        if (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue) {
            Get-BitLockerVolume | Format-List -Property MountPoint,VolumeStatus,ProtectionStatus,EncryptionMethod,EncryptionPercentage,LockStatus
        }
        else { manage-bde.exe -status 2>&1 }
    }
    Save-CsvResult 'firewall profiles' (Join-Path $bundleRoot 'Security\FirewallProfiles.csv') {
        Get-NetFirewallProfile | Select-Object -Property Name,Enabled,DefaultInboundAction,DefaultOutboundAction,NotifyOnListen,LogFileName
    }

    if (-not $SkipEventLogs) {
        $cutoff = (Get-Date).AddDays(-$EventLogDays)
        foreach ($logName in @('System','Application')) {
            Save-CsvResult "$logName events" (Join-Path $bundleRoot "Events\${logName}_CriticalErrorWarning.csv") {
                try {
                    Get-WinEvent -FilterHashtable @{LogName=$logName;StartTime=$cutoff;Level=1,2,3} `
                        -MaxEvents $MaxEventsPerLog -ErrorAction Stop |
                        Select-Object -Property TimeCreated,Id,LevelDisplayName,ProviderName,TaskDisplayName,@{
                            Name='Message';Expression={ Protect-SensitiveText -Text ([string]$_.Message) }
                        }
                }
                catch {
                    if ($_.FullyQualifiedErrorId -notlike '*NoMatchingEventsFound*') { throw }
                }
            }
        }
    }

    $script:CollectionErrors | Export-Csv (Join-Path $bundleRoot 'Logs\CollectionErrors.csv') -NoTypeInformation -Encoding UTF8

    $files = @(Get-ChildItem $bundleRoot -File -Recurse -ErrorAction SilentlyContinue)
    [ordered]@{
        BundleName = $bundleName
        ComputerName = $computer
        StartedAt = $startedAt
        CompletedAt = Get-Date
        IsAdministrator = $isAdmin
        FileCount = $files.Count
        CollectionErrorCount = $script:CollectionErrors.Count
    } | ConvertTo-Json -Depth 4 | Out-File (Join-Path $bundleRoot 'Manifest.json') -Encoding UTF8

    $privacyNotice = @(
        'Windows Support Bundle'
        '======================'
        "Computer: $computer"
        "Created:  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss K')"
        "Warnings: $($script:CollectionErrors.Count)"
        ''
        'Privacy notice'
        '--------------'
        'This collector does not intentionally query password stores, browser data, saved'
        'credentials, email bodies or personal document contents. Diagnostic command lines,'
        'proxy output and Windows event messages can nevertheless contain sensitive values.'
        'Common password/token key-value patterns are redacted, but redaction is not'
        'exhaustive. Review every file before sharing the bundle.'
    ) -join [Environment]::NewLine
    $privacyNotice | Out-File (Join-Path $bundleRoot 'README_FIRST.txt') -Encoding UTF8

    if ($script:TranscriptStarted) {
        Stop-Transcript | Out-Null
        $script:TranscriptStarted = $false
    }

    if (-not $SkipCompression) {
        Compress-Archive -Path $bundleRoot -DestinationPath $archivePath -CompressionLevel Optimal -Force
        $archive = Get-Item -LiteralPath $archivePath -ErrorAction Stop
        if ($archive.Length -le 0) { throw 'ZIP archive validation failed because the archive is empty.' }
        if (-not $KeepWorkingFolder) { Remove-Item $bundleRoot -Recurse -Force }
        Write-Status "Support bundle created: $archivePath" Success
    }
    else {
        Write-Status "Support bundle folder created: $bundleRoot" Success
    }

    if ($script:CollectionErrors.Count -gt 0) {
        Write-Status "$($script:CollectionErrors.Count) section(s) produced warnings." Warning
        exit 2
    }
    exit 0
}
catch {
    if ($script:TranscriptStarted) { try { Stop-Transcript | Out-Null } catch {} }
    Write-Status $_.Exception.Message Error
    exit 1
}
