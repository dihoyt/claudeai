# Scripts Share Mapping Script
# Maps a network share as drive S: using stored SMB credentials
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

Write-Host "--- Map Scripts Share ---" -ForegroundColor Yellow
Write-Host "Running with Administrator privileges ✓" -ForegroundColor Green

# Configuration
$ShareServer = "10.50.1.100"  # Change this to your server IP/FQDN
$ShareName = "scripts"        # Change this to your share name
$DriveLetter = "S"
$CredentialFile = "$PSScriptRoot\smb-credentials.xml"

Write-Host "`nMapping network share as drive ${DriveLetter}:..." -ForegroundColor Cyan
Write-Host "Server: $ShareServer" -ForegroundColor White
Write-Host "Share:  $ShareName" -ForegroundColor White
Write-Host ""

try {
    # Check if credential file exists
    if (-not (Test-Path $CredentialFile)) {
        Write-Host "Credential file not found at: $CredentialFile" -ForegroundColor Yellow
        Write-Host "Creating credential file..." -ForegroundColor Cyan
        Write-Host ""

        $Username = Read-Host "Enter username (e.g., DOMAIN\user or user)"
        $SecurePassword = Read-Host "Enter password" -AsSecureString

        # Create credential object
        $Credential = New-Object System.Management.Automation.PSCredential($Username, $SecurePassword)

        # Save encrypted credential to file
        $Credential | Export-Clixml -Path $CredentialFile
        Write-Host "✅ Credentials saved to: $CredentialFile" -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host "Using existing credentials from: $CredentialFile" -ForegroundColor Green
        Write-Host ""
    }

    # Load credentials
    $Credential = Import-Clixml -Path $CredentialFile

    # Remove existing mapping if present
    if (Test-Path "${DriveLetter}:") {
        Write-Host "Removing existing ${DriveLetter}: mapping..." -ForegroundColor Yellow
        Remove-PSDrive -Name $DriveLetter -ErrorAction SilentlyContinue
        net use "${DriveLetter}:" /delete /y 2>&1 | Out-Null
    }

    # Map the network drive for PowerShell (New-PSDrive)
    Write-Host "Mapping \\$ShareServer\$ShareName to ${DriveLetter}: (PowerShell)..." -ForegroundColor Cyan
    New-PSDrive -Name $DriveLetter `
                -PSProvider FileSystem `
                -Root "\\$ShareServer\$ShareName" `
                -Credential $Credential `
                -Persist `
                -Scope Global | Out-Null

    # Map the network drive for File Explorer (net use) - makes it persistent
    Write-Host "Mapping ${DriveLetter}: for File Explorer (persistent)..." -ForegroundColor Cyan
    $NetworkPath = "\\$ShareServer\$ShareName"
    $Username = $Credential.UserName
    $Password = $Credential.GetNetworkCredential().Password

    net use "${DriveLetter}:" "$NetworkPath" /user:$Username $Password /persistent:yes 2>&1 | Out-Null

    # Verify the mapping
    if (Test-Path "${DriveLetter}:") {
        Write-Host ""
        Write-Host "✅ Scripts share mapped successfully to ${DriveLetter}:" -ForegroundColor Green
        Write-Host "   Path: \\$ShareServer\$ShareName" -ForegroundColor White
        Write-Host "   Drive is visible in:" -ForegroundColor White
        Write-Host "     - PowerShell (${DriveLetter}:)" -ForegroundColor White
        Write-Host "     - File Explorer" -ForegroundColor White
        Write-Host "     - Will reconnect on reboot" -ForegroundColor White
    } else {
        Write-Host "❌ Failed to verify ${DriveLetter}: mapping" -ForegroundColor Red
    }

} catch {
    Write-Host "❌ Error mapping network share: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Check server availability and credentials." -ForegroundColor Yellow
}

Write-Host "`nPress any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")