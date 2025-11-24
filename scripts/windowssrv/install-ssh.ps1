# OpenSSH Server Installation Script
# Automatically requests elevation if not running as Administrator.

#Requires -Version 5.0

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "This script requires Administrator privileges." -ForegroundColor Yellow
    Write-Host "Attempting to restart with elevation..." -ForegroundColor Cyan

    try {
        # Get the current script path
        $scriptPath = $MyInvocation.MyCommand.Path

        # Start a new elevated process
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

        # Exit the current non-elevated process
        exit
    } catch {
        Write-Host "Failed to elevate. Please run this script as Administrator manually." -ForegroundColor Red
        Write-Host "Right-click PowerShell and select 'Run as Administrator', then run this script again." -ForegroundColor Yellow
        pause
        exit 1
    }
}

Write-Host "--- OpenSSH Server Installation ---" -ForegroundColor Yellow
Write-Host "Running with Administrator privileges ✓" -ForegroundColor Green

# Configure SSH Access for PowerShell
# Installs OpenSSH Server and configures the service and firewall rule.

Write-Host "`nConfiguring SSH Access for PowerShell (Port 22)..." -ForegroundColor Cyan
Write-Host "   (This may take several minutes - installing OpenSSH Server...)" -ForegroundColor Yellow
$SSHServiceName = 'sshd'
$SSHFirewallRuleName = 'OpenSSH-Server-Inbound'

try {
    # Install OpenSSH Server Feature (if not already installed)
    if (-not (Get-WindowsCapability -Online | Where-Object { $_.Name -eq 'OpenSSH.Server~~~~0.0.1.0' -and $_.State -eq 'Installed' })) {
        Write-Host "   Installing OpenSSH Server Feature..." -ForegroundColor Yellow
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction Stop
        Write-Host "   ✅ OpenSSH Server installed." -ForegroundColor Green
    } else {
        Write-Host "   OpenSSH Server Feature is already installed." -ForegroundColor Green
    }

    # Set up and start the SSHD service
    Set-Service -Name $SSHServiceName -StartupType 'Automatic' -ErrorAction Stop
    Start-Service -Name $SSHServiceName -ErrorAction Stop

    # Configure Firewall Rule (usually done by the installer, but we ensure it's enabled)
    Enable-NetFirewallRule -DisplayName $SSHFirewallRuleName -ErrorAction Stop | Out-Null

    Write-Host "   ✅ OpenSSH Server is running and firewall is open on Port 22." -ForegroundColor Green
} catch {
    Write-Host "   ❌ Error configuring OpenSSH: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "      (You may need to manually install OpenSSH Server via Settings/Optional Features.)" -ForegroundColor Yellow
}

Write-Host "`n--- Installation Complete ---" -ForegroundColor Yellow
Write-Host "You can now connect using SSH:" -ForegroundColor White
Write-Host "  - Standard SSH: ssh username@hostname" -ForegroundColor White
Write-Host "  - Remote PowerShell via SSH: ssh username@hostname -t powershell.exe" -ForegroundColor White

Write-Host "`nPress any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")