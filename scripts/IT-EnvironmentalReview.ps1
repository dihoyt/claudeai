<#
.SYNOPSIS
    IT Environmental Review Script - Comprehensive system assessment tool

.DESCRIPTION
    Performs a comprehensive IT environmental review including:
    - System Information (Hardware, OS, Network)
    - Installed Software Inventory
    - Security Configuration Assessment
    - Performance Metrics
    - Disk Space and Health
    - Service Status
    - Network Configuration
    - User and Group Analysis
    - Security Updates Status
    - Event Log Analysis

.PARAMETER OutputPath
    Path where the review report will be saved. Default: Current directory with timestamp

.PARAMETER IncludeSoftware
    Include detailed software inventory (can be time-consuming)

.PARAMETER IncludeEventLogs
    Include event log analysis for errors and warnings

.PARAMETER ExportFormat
    Output format: HTML, JSON, or Both. Default: Both

.EXAMPLE
    .\IT-EnvironmentalReview.ps1

.EXAMPLE
    .\IT-EnvironmentalReview.ps1 -OutputPath "C:\Reports" -ExportFormat HTML -IncludeSoftware -IncludeEventLogs

.NOTES
    Author: IT Operations
    Version: 1.0
    Requires: PowerShell 5.1 or higher, Administrator privileges recommended
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = $PSScriptRoot,

    [Parameter(Mandatory=$false)]
    [switch]$IncludeSoftware,

    [Parameter(Mandatory=$false)]
    [switch]$IncludeEventLogs,

    [Parameter(Mandatory=$false)]
    [ValidateSet('HTML', 'JSON', 'Both')]
    [string]$ExportFormat = 'Both'
)

# Initialize
$ErrorActionPreference = 'Continue'
$InformationPreference = 'Continue'
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$computerName = $env:COMPUTERNAME
$reportName = "ITEnvironmentalReview_${computerName}_${timestamp}"

# Default switches to true if not explicitly set to false
if (-not $PSBoundParameters.ContainsKey('IncludeSoftware')) {
    $IncludeSoftware = $true
}
if (-not $PSBoundParameters.ContainsKey('IncludeEventLogs')) {
    $IncludeEventLogs = $true
}

Write-Information "========================================" -InformationAction Continue
Write-Information "IT Environmental Review Tool" -InformationAction Continue
Write-Information "========================================" -InformationAction Continue
Write-Information "Computer: $computerName" -InformationAction Continue
Write-Information "Started: $(Get-Date)" -InformationAction Continue
Write-Information "" -InformationAction Continue

# Create report object
$report = @{
    GeneratedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ComputerName = $computerName
    Sections = @{}
}

#region System Information
Write-Information "[1/10] Gathering System Information..." -InformationAction Continue

$osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
$csInfo = Get-CimInstance -ClassName Win32_ComputerSystem
$biosInfo = Get-CimInstance -ClassName Win32_BIOS
$processorInfo = Get-CimInstance -ClassName Win32_Processor

$report.Sections.SystemInfo = @{
    OperatingSystem = @{
        Name = $osInfo.Caption
        Version = $osInfo.Version
        BuildNumber = $osInfo.BuildNumber
        Architecture = $osInfo.OSArchitecture
        InstallDate = $osInfo.InstallDate
        LastBootUpTime = $osInfo.LastBootUpTime
        UptimeDays = ((Get-Date) - $osInfo.LastBootUpTime).Days
    }
    Hardware = @{
        Manufacturer = $csInfo.Manufacturer
        Model = $csInfo.Model
        TotalPhysicalMemoryGB = [math]::Round($csInfo.TotalPhysicalMemory / 1GB, 2)
        NumberOfProcessors = $csInfo.NumberOfProcessors
        NumberOfLogicalProcessors = $csInfo.NumberOfLogicalProcessors
        Domain = $csInfo.Domain
        DomainRole = switch($csInfo.DomainRole) {
            0 {"Standalone Workstation"}
            1 {"Member Workstation"}
            2 {"Standalone Server"}
            3 {"Member Server"}
            4 {"Backup Domain Controller"}
            5 {"Primary Domain Controller"}
        }
    }
    BIOS = @{
        Manufacturer = $biosInfo.Manufacturer
        Version = $biosInfo.SMBIOSBIOSVersion
        ReleaseDate = $biosInfo.ReleaseDate
    }
    Processor = @{
        Name = $processorInfo.Name
        Cores = $processorInfo.NumberOfCores
        LogicalProcessors = $processorInfo.NumberOfLogicalProcessors
        MaxClockSpeedMHz = $processorInfo.MaxClockSpeed
    }
}
#endregion

#region Disk Information
Write-Information "[2/10] Analyzing Disk Space and Health..." -InformationAction Continue

$disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    @{
        DeviceID = $_.DeviceID
        VolumeName = $_.VolumeName
        SizeGB = [math]::Round($_.Size / 1GB, 2)
        FreeSpaceGB = [math]::Round($_.FreeSpace / 1GB, 2)
        UsedSpaceGB = [math]::Round(($_.Size - $_.FreeSpace) / 1GB, 2)
        PercentFree = [math]::Round(($_.FreeSpace / $_.Size) * 100, 2)
        Status = if(($_.FreeSpace / $_.Size) -lt 0.1) {"CRITICAL - Less than 10% free"}
                 elseif(($_.FreeSpace / $_.Size) -lt 0.2) {"WARNING - Less than 20% free"}
                 else {"OK"}
    }
}

$report.Sections.DiskInfo = $disks
#endregion

#region Memory Information
Write-Information "[3/10] Checking Memory Usage..." -InformationAction Continue

$memoryUsage = @{
    TotalMemoryGB = [math]::Round($osInfo.TotalVisibleMemorySize / 1MB, 2)
    FreeMemoryGB = [math]::Round($osInfo.FreePhysicalMemory / 1MB, 2)
    UsedMemoryGB = [math]::Round(($osInfo.TotalVisibleMemorySize - $osInfo.FreePhysicalMemory) / 1MB, 2)
    PercentUsed = [math]::Round((($osInfo.TotalVisibleMemorySize - $osInfo.FreePhysicalMemory) / $osInfo.TotalVisibleMemorySize) * 100, 2)
}

$report.Sections.MemoryInfo = $memoryUsage
#endregion

#region Network Configuration
Write-Information "[4/10] Reviewing Network Configuration..." -InformationAction Continue

$networkAdapters = Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | ForEach-Object {
    $adapter = $_
    $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue

    @{
        Name = $adapter.Name
        InterfaceDescription = $adapter.InterfaceDescription
        Status = $adapter.Status
        MacAddress = $adapter.MacAddress
        LinkSpeed = $adapter.LinkSpeed
        IPv4Addresses = ($ipConfig | Where-Object {$_.AddressFamily -eq 'IPv4'}).IPAddress
        IPv6Addresses = ($ipConfig | Where-Object {$_.AddressFamily -eq 'IPv6'}).IPAddress
    }
}

$dnsServers = (Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object {$_.ServerAddresses}).ServerAddresses | Select-Object -Unique

$report.Sections.NetworkInfo = @{
    Adapters = $networkAdapters
    DNSServers = $dnsServers
    DefaultGateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue).NextHop
}
#endregion

#region Installed Software
if($IncludeSoftware) {
    Write-Information "[5/10] Inventorying Installed Software (this may take a moment)..." -InformationAction Continue

    $software = @()

    # Get software from registry (64-bit)
    $software += Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue |
        Where-Object {$_.DisplayName} |
        Select-Object DisplayName, DisplayVersion, Publisher, InstallDate

    # Get software from registry (32-bit on 64-bit systems)
    if(Test-Path 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*') {
        $software += Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue |
            Where-Object {$_.DisplayName} |
            Select-Object DisplayName, DisplayVersion, Publisher, InstallDate
    }

    $report.Sections.InstalledSoftware = $software | Sort-Object DisplayName -Unique | ForEach-Object {
        @{
            Name = $_.DisplayName
            Version = $_.DisplayVersion
            Publisher = $_.Publisher
            InstallDate = $_.InstallDate
        }
    }
} else {
    Write-Information "[5/10] Skipping Software Inventory (use -IncludeSoftware to enable)..." -InformationAction Continue
    $report.Sections.InstalledSoftware = @{Note = "Skipped - use -IncludeSoftware parameter"}
}
#endregion

#region Windows Updates
Write-Information "[6/10] Checking Windows Update Status..." -InformationAction Continue

try {
    $updateSession = New-Object -ComObject Microsoft.Update.Session
    $updateSearcher = $updateSession.CreateUpdateSearcher()
    $pendingUpdates = $updateSearcher.Search("IsInstalled=0 and Type='Software'").Updates

    $report.Sections.WindowsUpdates = @{
        PendingUpdatesCount = $pendingUpdates.Count
        LastSearchSuccessDate = $updateSearcher.GetTotalHistoryCount()
        PendingUpdates = @($pendingUpdates | ForEach-Object {
            @{
                Title = $_.Title
                IsDownloaded = $_.IsDownloaded
                IsMandatory = $_.IsMandatory
                SecurityBulletin = $_.SecurityBulletinIDs
            }
        })
    }
} catch {
    $report.Sections.WindowsUpdates = @{
        Error = "Unable to retrieve Windows Update information: $($_.Exception.Message)"
    }
}
#endregion

#region Services
Write-Information "[7/10] Reviewing Windows Services..." -InformationAction Continue

$criticalServices = @('wuauserv', 'BITS', 'EventLog', 'W32Time', 'Winmgmt', 'Schedule', 'Dhcp', 'Dnscache')
$services = Get-Service | ForEach-Object {
    @{
        Name = $_.Name
        DisplayName = $_.DisplayName
        Status = $_.Status.ToString()
        StartType = $_.StartType.ToString()
        IsCritical = $criticalServices -contains $_.Name
    }
}

$stoppedCriticalServices = $services | Where-Object {$_.IsCritical -and $_.Status -ne 'Running'}

$report.Sections.Services = @{
    TotalServices = $services.Count
    RunningServices = ($services | Where-Object {$_.Status -eq 'Running'}).Count
    StoppedServices = ($services | Where-Object {$_.Status -eq 'Stopped'}).Count
    CriticalServicesStopped = @($stoppedCriticalServices)
    AllServices = $services
}
#endregion

#region Security Configuration
Write-Information "[8/10] Assessing Security Configuration..." -InformationAction Continue

$firewall = Get-NetFirewallProfile | ForEach-Object {
    @{
        Name = $_.Name
        Enabled = $_.Enabled
        DefaultInboundAction = $_.DefaultInboundAction.ToString()
        DefaultOutboundAction = $_.DefaultOutboundAction.ToString()
    }
}

$antivirusProducts = @()
try {
    $antivirusProducts = Get-CimInstance -Namespace "root\SecurityCenter2" -ClassName AntiVirusProduct -ErrorAction SilentlyContinue | ForEach-Object {
        @{
            DisplayName = $_.displayName
            ProductState = $_.productState
            PathToSignedProductExe = $_.pathToSignedProductExe
        }
    }
} catch {
    $antivirusProducts = @{Note = "Unable to retrieve antivirus information"}
}

$report.Sections.Security = @{
    FirewallProfiles = $firewall
    AntivirusProducts = $antivirusProducts
    UAC = @{
        Enabled = (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name EnableLUA -ErrorAction SilentlyContinue).EnableLUA -eq 1
    }
    WindowsDefender = @{
        ServiceRunning = (Get-Service -Name WinDefend -ErrorAction SilentlyContinue).Status -eq 'Running'
    }
}
#endregion

#region Event Logs
if($IncludeEventLogs) {
    Write-Information "[9/10] Analyzing Event Logs (last 24 hours)..." -InformationAction Continue

    $last24Hours = (Get-Date).AddHours(-24)

    $systemErrors = Get-WinEvent -FilterHashtable @{LogName='System'; Level=2; StartTime=$last24Hours} -MaxEvents 50 -ErrorAction SilentlyContinue
    $applicationErrors = Get-WinEvent -FilterHashtable @{LogName='Application'; Level=2; StartTime=$last24Hours} -MaxEvents 50 -ErrorAction SilentlyContinue

    $report.Sections.EventLogs = @{
        TimeRange = "Last 24 hours"
        SystemErrors = @($systemErrors | ForEach-Object {
            @{
                TimeCreated = $_.TimeCreated
                Id = $_.Id
                Message = $_.Message
                ProviderName = $_.ProviderName
            }
        })
        ApplicationErrors = @($applicationErrors | ForEach-Object {
            @{
                TimeCreated = $_.TimeCreated
                Id = $_.Id
                Message = $_.Message
                ProviderName = $_.ProviderName
            }
        })
        SystemErrorCount = if($systemErrors) {$systemErrors.Count} else {0}
        ApplicationErrorCount = if($applicationErrors) {$applicationErrors.Count} else {0}
    }
} else {
    Write-Information "[9/10] Skipping Event Log Analysis (use -IncludeEventLogs to enable)..." -InformationAction Continue
    $report.Sections.EventLogs = @{Note = "Skipped - use -IncludeEventLogs parameter"}
}
#endregion

#region User Accounts
Write-Information "[10/10] Reviewing User Accounts..." -InformationAction Continue

$localUsers = Get-LocalUser | ForEach-Object {
    @{
        Name = $_.Name
        Enabled = $_.Enabled
        LastLogon = $_.LastLogon
        PasswordLastSet = $_.PasswordLastSet
        PasswordExpires = $_.PasswordExpires
        UserMayChangePassword = $_.UserMayChangePassword
    }
}

$localAdmins = Get-LocalGroupMember -Group "Administrators" -ErrorAction SilentlyContinue | ForEach-Object {
    @{
        Name = $_.Name
        ObjectClass = $_.ObjectClass
        PrincipalSource = $_.PrincipalSource
    }
}

$report.Sections.UserAccounts = @{
    LocalUsers = $localUsers
    LocalAdministrators = $localAdmins
    TotalUsers = $localUsers.Count
    EnabledUsers = ($localUsers | Where-Object {$_.Enabled}).Count
}
#endregion

# Generate Reports
Write-Information "" -InformationAction Continue
Write-Information "========================================" -InformationAction Continue
Write-Information "Generating Reports..." -InformationAction Continue
Write-Information "========================================" -InformationAction Continue

# Ensure output directory exists
if(-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

# Export JSON
if($ExportFormat -eq 'JSON' -or $ExportFormat -eq 'Both') {
    $jsonPath = Join-Path $OutputPath "$reportName.json"
    $report | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding UTF8
    Write-Information "JSON Report saved to: $jsonPath" -InformationAction Continue
}

# Export HTML
if($ExportFormat -eq 'HTML' -or $ExportFormat -eq 'Both') {
    $htmlPath = Join-Path $OutputPath "$reportName.html"

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>IT Environmental Review - $computerName</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; background-color: #ecf0f1; padding: 10px; border-left: 4px solid #3498db; margin-top: 20px; }
        h3 { color: #7f8c8d; }
        table { border-collapse: collapse; width: 100%; margin: 15px 0; background-color: white; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        th { background-color: #3498db; color: white; padding: 12px; text-align: left; }
        td { border: 1px solid #ddd; padding: 10px; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .status-ok { color: green; font-weight: bold; }
        .status-warning { color: orange; font-weight: bold; }
        .status-critical { color: red; font-weight: bold; }
        .info-box { background-color: #e8f4f8; border: 1px solid #3498db; padding: 15px; margin: 10px 0; border-radius: 5px; }
        .summary { background-color: #fff; padding: 20px; margin: 20px 0; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    </style>
</head>
<body>
    <h1>IT Environmental Review Report</h1>
    <div class="info-box">
        <strong>Computer Name:</strong> $computerName<br>
        <strong>Generated:</strong> $($report.GeneratedDate)<br>
    </div>

    <div class="summary">
        <h2>Executive Summary</h2>
        <ul>
            <li><strong>OS:</strong> $($report.Sections.SystemInfo.OperatingSystem.Name) - Build $($report.Sections.SystemInfo.OperatingSystem.BuildNumber)</li>
            <li><strong>Uptime:</strong> $($report.Sections.SystemInfo.OperatingSystem.UptimeDays) days</li>
            <li><strong>Memory:</strong> $($report.Sections.MemoryInfo.UsedMemoryGB)GB / $($report.Sections.MemoryInfo.TotalMemoryGB)GB used ($($report.Sections.MemoryInfo.PercentUsed)%)</li>
            <li><strong>Critical Services Stopped:</strong> $($report.Sections.Services.CriticalServicesStopped.Count)</li>
        </ul>
    </div>

    <h2>System Information</h2>
    <table>
        <tr><th>Property</th><th>Value</th></tr>
        <tr><td>Operating System</td><td>$($report.Sections.SystemInfo.OperatingSystem.Name)</td></tr>
        <tr><td>Version</td><td>$($report.Sections.SystemInfo.OperatingSystem.Version)</td></tr>
        <tr><td>Architecture</td><td>$($report.Sections.SystemInfo.OperatingSystem.Architecture)</td></tr>
        <tr><td>Install Date</td><td>$($report.Sections.SystemInfo.OperatingSystem.InstallDate)</td></tr>
        <tr><td>Last Boot</td><td>$($report.Sections.SystemInfo.OperatingSystem.LastBootUpTime)</td></tr>
        <tr><td>Manufacturer</td><td>$($report.Sections.SystemInfo.Hardware.Manufacturer)</td></tr>
        <tr><td>Model</td><td>$($report.Sections.SystemInfo.Hardware.Model)</td></tr>
        <tr><td>Total Memory</td><td>$($report.Sections.SystemInfo.Hardware.TotalPhysicalMemoryGB) GB</td></tr>
        <tr><td>Domain Role</td><td>$($report.Sections.SystemInfo.Hardware.DomainRole)</td></tr>
    </table>

    <h2>Disk Information</h2>
    <table>
        <tr><th>Drive</th><th>Volume Name</th><th>Size (GB)</th><th>Used (GB)</th><th>Free (GB)</th><th>% Free</th><th>Status</th></tr>
        $(foreach($disk in $report.Sections.DiskInfo) {
            $statusClass = if($disk.Status -match "CRITICAL") {"status-critical"} elseif($disk.Status -match "WARNING") {"status-warning"} else {"status-ok"}
            "<tr><td>$($disk.DeviceID)</td><td>$($disk.VolumeName)</td><td>$($disk.SizeGB)</td><td>$($disk.UsedSpaceGB)</td><td>$($disk.FreeSpaceGB)</td><td>$($disk.PercentFree)%</td><td class='$statusClass'>$($disk.Status)</td></tr>"
        })
    </table>

    <h2>Memory Usage</h2>
    <table>
        <tr><th>Metric</th><th>Value</th></tr>
        <tr><td>Total Memory</td><td>$($report.Sections.MemoryInfo.TotalMemoryGB) GB</td></tr>
        <tr><td>Used Memory</td><td>$($report.Sections.MemoryInfo.UsedMemoryGB) GB</td></tr>
        <tr><td>Free Memory</td><td>$($report.Sections.MemoryInfo.FreeMemoryGB) GB</td></tr>
        <tr><td>Percent Used</td><td>$($report.Sections.MemoryInfo.PercentUsed)%</td></tr>
    </table>

    <h2>Services Summary</h2>
    <table>
        <tr><th>Metric</th><th>Count</th></tr>
        <tr><td>Total Services</td><td>$($report.Sections.Services.TotalServices)</td></tr>
        <tr><td>Running</td><td class="status-ok">$($report.Sections.Services.RunningServices)</td></tr>
        <tr><td>Stopped</td><td>$($report.Sections.Services.StoppedServices)</td></tr>
        <tr><td>Critical Services Stopped</td><td class="$(if($report.Sections.Services.CriticalServicesStopped.Count -gt 0){"status-critical"}else{"status-ok"})">$($report.Sections.Services.CriticalServicesStopped.Count)</td></tr>
    </table>

    $(if($report.Sections.Services.CriticalServicesStopped.Count -gt 0) {
        "<h3>Stopped Critical Services</h3><table><tr><th>Name</th><th>Display Name</th><th>Start Type</th></tr>"
        foreach($svc in $report.Sections.Services.CriticalServicesStopped) {
            "<tr><td>$($svc.Name)</td><td>$($svc.DisplayName)</td><td>$($svc.StartType)</td></tr>"
        }
        "</table>"
    })

    <h2>Security Configuration</h2>
    <h3>Firewall Status</h3>
    <table>
        <tr><th>Profile</th><th>Enabled</th><th>Inbound Action</th><th>Outbound Action</th></tr>
        $(foreach($fw in $report.Sections.Security.FirewallProfiles) {
            "<tr><td>$($fw.Name)</td><td>$($fw.Enabled)</td><td>$($fw.DefaultInboundAction)</td><td>$($fw.DefaultOutboundAction)</td></tr>"
        })
    </table>

    <h2>User Accounts</h2>
    <table>
        <tr><th>Metric</th><th>Value</th></tr>
        <tr><td>Total Users</td><td>$($report.Sections.UserAccounts.TotalUsers)</td></tr>
        <tr><td>Enabled Users</td><td>$($report.Sections.UserAccounts.EnabledUsers)</td></tr>
        <tr><td>Local Administrators</td><td>$($report.Sections.UserAccounts.LocalAdministrators.Count)</td></tr>
    </table>

    $(if($IncludeEventLogs -and $report.Sections.EventLogs.SystemErrorCount -gt 0) {
        "<h2>Recent System Errors (Last 24 Hours)</h2>"
        "<p><strong>Total Errors:</strong> $($report.Sections.EventLogs.SystemErrorCount)</p>"
        "<table><tr><th>Time</th><th>Event ID</th><th>Source</th><th>Message</th></tr>"
        foreach($evt in $report.Sections.EventLogs.SystemErrors | Select-Object -First 10) {
            "<tr><td>$($evt.TimeCreated)</td><td>$($evt.Id)</td><td>$($evt.ProviderName)</td><td>$($evt.Message -replace '<','&lt;' -replace '>','&gt;' | Out-String | ForEach-Object {$_.Substring(0, [Math]::Min(200, $_.Length))})</td></tr>"
        }
        "</table>"
    })

    <div class="info-box" style="margin-top: 40px;">
        <strong>Report generated by:</strong> IT Environmental Review PowerShell Script v1.0<br>
        <strong>Execution time:</strong> $(Get-Date)
    </div>
</body>
</html>
"@

    $html | Out-File -FilePath $htmlPath -Encoding UTF8
    Write-Information "HTML Report saved to: $htmlPath" -InformationAction Continue
}

Write-Information "" -InformationAction Continue
Write-Information "========================================" -InformationAction Continue
Write-Information "Review Complete!" -InformationAction Continue
Write-Information "========================================" -InformationAction Continue
Write-Information "" -InformationAction Continue
Write-Information "Key Findings:" -InformationAction Continue
Write-Information "  - System Uptime: $($report.Sections.SystemInfo.OperatingSystem.UptimeDays) days" -InformationAction Continue
Write-Information "  - Memory Usage: $($report.Sections.MemoryInfo.PercentUsed)%" -InformationAction Continue

foreach($disk in $report.Sections.DiskInfo) {
    Write-Information "  - Disk $($disk.DeviceID): $($disk.PercentFree)% free - $($disk.Status)" -InformationAction Continue
}

if($report.Sections.Services.CriticalServicesStopped.Count -gt 0) {
    Write-Information "  - WARNING: $($report.Sections.Services.CriticalServicesStopped.Count) critical service(s) stopped!" -InformationAction Continue
}

Write-Information "" -InformationAction Continue
