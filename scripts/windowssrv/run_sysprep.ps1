<#
.SYNOPSIS
    Runs Windows Sysprep with generalization, OOBE, and shutdown options.

.DESCRIPTION
    This script is intended to be run inside a Windows 11 IoT VM (or any Windows VM)
    before taking a snapshot or creating a Proxmox template. It uses the required
    unattend.xml file located in the same directory to automate the Out-of-Box
    Experience (OOBE).

.PARAMETER UnattendFilePath
    Optional path to the unattend.xml file. Defaults to '.\unattend.xml'.

.NOTES
    Requires elevated (Administrator) privileges.
#>
[CmdletBinding()]
param(
    [string]$UnattendFilePath = ".\unattend.xml"
)

# --- Configuration ---
$SysprepDir = "$env:windir\System32\Sysprep"
$SysprepLogPath = "$SysprepDir\Panther\setupact.log"

# Set a trap for terminating errors
trap {
    Write-Error "A terminating error occurred: $($_.Exception.Message)"
    Write-Host "Sysprep failed to execute. Review logs at $SysprepLogPath"
    Exit 1
}

Write-Host "--- Windows System Preparation Tool (Sysprep) ---" -ForegroundColor Cyan

# 1. Validate Admin Privileges (Recommended)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run with elevated (Administrator) privileges."
    Exit 1
}

# 2. Check for unattend.xml
if (-not (Test-Path $UnattendFilePath)) {
    Write-Error "ERROR: The unattend.xml file was not found at the specified path: '$UnattendFilePath'"
    Write-Host "Please ensure the unattend.xml is in the same directory or provide the correct path."
    Exit 1
}

$UnattendFile = Resolve-Path $UnattendFilePath

Write-Host "Unattended Answer File found: $UnattendFile" -ForegroundColor Green

# 3. Execute Sysprep
Write-Host "Executing Sysprep. This process will generalize the installation and shut down the system..." -ForegroundColor Yellow

# Use Push-Location/Pop-Location for cleaner command execution
Push-Location $SysprepDir

# The arguments:
# /generalize : Removes unique system information (like SID).
# /oobe       : Sets the system to boot to OOBE (using the unattended file).
# /shutdown   : Shuts down the computer after Sysprep finishes.
# /unattend   : Specifies the path to the answer file.
$SysprepProcess = Start-Process -FilePath ".\sysprep.exe" `
    -ArgumentList "/generalize", "/oobe", "/shutdown", "/unattend:`"$UnattendFile`"" `
    -Wait -PassThru -NoNewWindow

Pop-Location

# 4. Check Exit Code and Report
if ($SysprepProcess.ExitCode -eq 0) {
    Write-Host "`nSysprep executed successfully. The system will now be shut down." -ForegroundColor Green
} else {
    Write-Error "`nSysprep completed with an error (Exit Code: $($SysprepProcess.ExitCode))."
    Write-Host "Review the setupact.log for details: $SysprepLogPath" -ForegroundColor Red
    Exit 1
}