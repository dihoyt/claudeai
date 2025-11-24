# Set execution policy to allow script to run
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# --- Configuration Variables ---
# NOTE: Update $VirtIOCDPath if your virtio-win.iso is mounted to a different drive letter
$VirtIOCDPath = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -like 'D:\' -or $_.Root -like 'E:\' } | Select-Object -First 1
if (-not $VirtIOCDPath) {
    Write-Error "Could not find the VirtIO ISO drive. Please ensure the virtio-win.iso is mounted."
    exit 1
}
$VirtIOCDPath = $VirtIOCDPath.Root

$CloudbaseInitInstaller = "CloudbaseInitSetup_Stable_x64.msi"
$CloudbaseInitDownloadURL = "https://www.cloudbase.it/downloads/$CloudbaseInitInstaller"
$TempDir = "C:\Temp\ProxmoxSetup"

# --- 1. Install VirtIO Drivers and QEMU Guest Agent ---
Write-Host "--- 1. Installing VirtIO Drivers and QEMU Guest Agent ---"
# The virtio-win-gt-x64.msi installer on the ISO handles all drivers (disk, network, balloon) and the QEMU Guest Agent.
$VirtIOInstallerPath = Join-Path -Path $VirtIOCDPath -ChildPath "virtio-win-gt-x64.msi"

if (Test-Path $VirtIOInstallerPath) {
    # Use msiexec for silent, unattended installation
    # /qn: Quiet mode (no user interface)
    Write-Host "Installing VirtIO Guest Tools (includes QEMU Guest Agent)..."
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$VirtIOInstallerPath`" /qn /norestart" -Wait
    Write-Host "VirtIO Guest Tools installed successfully."
} else {
    Write-Error "Could not find VirtIO Guest Tools installer: $VirtIOInstallerPath. Please check the drive letter."
    exit 1
}

# --- 2. Install Cloudbase-Init ---
Write-Host "--- 2. Downloading and Installing Cloudbase-Init ---"

# Create temp directory
if (-not (Test-Path $TempDir)) {
    New-Item -Path $TempDir -ItemType Directory | Out-Null
}

$DownloadPath = Join-Path -Path $TempDir -ChildPath $CloudbaseInitInstaller

try {
    # Download the Cloudbase-Init Stable MSI
    Write-Host "Downloading Cloudbase-Init from $CloudbaseInitDownloadURL..."
    Invoke-WebRequest -Uri $CloudbaseInitDownloadURL -OutFile $DownloadPath -UseBasicParsing

    # Install Cloudbase-Init silently
    # /qn: Quiet mode
    # /L*v: Enable verbose logging
    # RUN_SETUP_AT_EXIT=1: The key step for Sysprep, forces the installer to run the setup wizard on the next boot (OOBE)
    # The Cloudbase-Init setup wizard handles the final Sysprep reseal step if not done manually.
    Write-Host "Installing Cloudbase-Init..."
    $InstallArgs = "/i `"$DownloadPath`" /qn /norestart RUN_SETUP_AT_EXIT=1"
    Start-Process -FilePath "msiexec.exe" -ArgumentList $InstallArgs -Wait

    Write-Host "Cloudbase-Init installed successfully. It is configured to run on next boot."

} catch {
    Write-Error "Failed to download or install Cloudbase-Init: $($_.Exception.Message)"
    exit 1
}

# --- 3. Final Sysprep Preparation Command ---
Write-Host "--- 3. Sysprep Command Preparation ---"
Write-Host "The system is now ready for Sysprep. Do NOT reboot."
Write-Host "The final step is to execute Sysprep with the following command (requires an unattend.xml for full automation):"
Write-Host ""
Write-Host "C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown /unattend:C:\Windows\System32\Sysprep\unattend.xml"
Write-Host ""

# Clean up the downloaded Cloudbase-Init installer
Remove-Item -Path $TempDir -Recurse -Force | Out-Null
Write-Host "Script finished. Review the output and proceed with Sysprep manually."