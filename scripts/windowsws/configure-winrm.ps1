# This script configures a Windows machine for comprehensive remote management.
# Automatically requests elevation if not running as Administrator.
# NOTE: Removed the '-Force' parameter from NetFirewallRule cmdlets for compatibility with older PowerShell versions.

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

Write-Host "--- Starting Remote Management Configuration ---" -ForegroundColor Yellow
Write-Host "Running with Administrator privileges ✓" -ForegroundColor Green

# 1. Enable PowerShell Remoting (WinRM)
# This starts the WinRM service, sets it to auto-start, and creates the default firewall rules
# on ports 5985 (HTTP) and 5986 (HTTPS).

Write-Host "`n[1/5] Configuring PowerShell Remoting (WinRM)..." -ForegroundColor Cyan
try {
    # The -Force parameter is supported here and suppresses the confirmation prompt
    Enable-PSRemoting -Force
    Write-Host "   ✅ PSRemoting (WinRM) enabled successfully." -ForegroundColor Green
} catch {
    Write-Host "   ❌ Error enabling PSRemoting (WinRM): $($_.Exception.Message)" -ForegroundColor Red
}


# 2. Enable Remote Desktop Protocol (RDP)
# RDP requires a Registry key modification AND firewall rules.

Write-Host "`n[2/5] Configuring Remote Desktop (RDP)..." -ForegroundColor Cyan
try {
    # Enable RDP in the Registry (Set fDenyTSConnections to 0)
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' `
        -Name 'fDenyTSConnections' -Value 0 -Force | Out-Null
    
    # Enable the built-in firewall rules for RDP (TCP port 3389)
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop" | Out-Null
    
    Write-Host "   ✅ RDP enabled successfully (Registry and Firewall)." -ForegroundColor Green
} catch {
    Write-Host "   ❌ Error enabling RDP: $($_.Exception.Message)" -ForegroundColor Red
}


# 3. Enable Ping Replies (ICMP Echo Request) - *REVISED*
# This directly creates a robust rule allowing inbound ICMPv4 (ping) traffic on all profiles.

Write-Host "`n[3/5] Allowing Ping (ICMP Echo Requests) with new rule..." -ForegroundColor Cyan
$ICMPRuleName = "Custom_Allow_ICMPv4_Ping_Inbound"
try {
    # Check if the rule already exists to avoid errors. Use -Confirm:$false instead of -Force
    if (Get-NetFirewallRule -Name $ICMPRuleName -ErrorAction SilentlyContinue) {
        Remove-NetFirewallRule -Name $ICMPRuleName -Confirm:$false | Out-Null
        Write-Host "   (Existing custom ICMP rule removed.)" -ForegroundColor Yellow
    }

    # Create a new, explicit rule for ICMPv4 Echo Request
    New-NetFirewallRule -DisplayName $ICMPRuleName `
        -Name $ICMPRuleName `
        -Direction Inbound `
        -Protocol ICMPv4 `
        -IcmpType 8 `
        -Action Allow `
        -Profile Any | Out-Null
        
    Write-Host "   ✅ Ping (ICMPv4) replies enabled successfully for ALL profiles." -ForegroundColor Green
} catch {
    Write-Host "   ❌ Error creating Ping rule: $($_.Exception.Message)" -ForegroundColor Red
}


# 4. Check Network Profile Status (Troubleshooting Step)
Write-Host "`n[4/4] Verifying Network Profile Type..." -ForegroundColor Cyan
try {
    $Profile = Get-NetConnectionProfile | Select-Object -First 1
    Write-Host "   Current Network Profile is: $($Profile.NetworkCategory)" -ForegroundColor White
} catch {
    Write-Host "   Could not retrieve network profile information." -ForegroundColor Yellow
}


Write-Host "`n--- Configuration Complete ---" -ForegroundColor Yellow
Write-Host "You should now be able to connect using:" -ForegroundColor White
Write-Host "  - Remote PowerShell via WinRM (PS): Enter-PSSession -ComputerName <hostname>" -ForegroundColor White
Write-Host "  - Remote Desktop (RDP): mstsc.exe" -ForegroundColor White
Write-Host "  - Ping: ping <hostname>" -ForegroundColor White
Write-Host ""
Write-Host "Additional scripts available:" -ForegroundColor Cyan
Write-Host "  - .\install-ssh.ps1        - Install OpenSSH Server" -ForegroundColor White
Write-Host "  - .\add-scripts-share.ps1  - Map scripts share as S: drive" -ForegroundColor White

Write-Host "`nPress any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")