# Proxmox Management Scripts

This directory contains scripts for managing Proxmox VE (Virtual Environment) infrastructure.

## Scripts

### `create-vm.sh`
Interactive script to create new VMs by cloning existing templates.

### `delete-vm.sh`
Interactive script to safely delete VMs with confirmation prompts and automatic shutdown handling.

### `task-manager.sh`
Real-time monitoring dashboard displaying host statistics and VM information in formatted tables.

**What it does:**
- Lists available templates in your Proxmox environment
- Prompts for VM configuration:
  - Template ID to clone from
  - New VM ID (or auto-assigns next available)
  - VM name
  - Clone mode (Full or Linked)
- Creates the VM on `local-lvm` storage
- Provides next steps for configuration

**Usage:**
```bash
chmod +x create-vm.sh
./create-vm.sh
```

**Interactive Prompts:**
1. **Template ID**: Select from displayed list of available templates
2. **New VM ID**: Enter specific ID or press Enter for next available
3. **VM Name**: Hostname/identifier for the new VM
4. **Clone Mode**:
   - **(F)ull Clone**: Complete independent copy (uses more storage)
   - **(L)inked Clone**: Space-efficient linked clone (faster creation)

**Example Session:**
```
Available Templates:
VMID  NAME            STATUS    MEM      BOOTDISK  PID
100   ubuntu-template template  2048     20G       -

Enter Template ID: 100
Enter new VM ID (or press Enter for next available):
Using next available VM ID: 101
Enter VM Name: webserver-01
Clone Mode - (F)ull Clone or (L)inked Clone [F/L]: F

Confirm VM Creation:
  Template ID:      100
  New VM ID:        101
  VM Name:          webserver-01
  Clone Mode:       full
  Storage:          local-lvm

Proceed with VM creation? [Y/n]: y
```

**After Creation:**
1. Configure cloud-init settings (if template supports it)
2. Adjust CPU/memory resources if needed
3. Start the VM
4. Access via console or SSH

**Requirements:**
- Proxmox VE environment
- At least one VM template created
- SSH access to Proxmox host or run directly on Proxmox shell
- Appropriate permissions to create VMs

**Storage:**
- All VMs are created on `local-lvm` storage
- To modify target storage, edit the script's `--storage` parameter

---

### `delete-vm.sh`
Interactive script to safely delete VMs with multiple confirmation prompts and automatic shutdown handling.

**What it does:**
- Lists all VMs (excludes templates for safety)
- Validates VM selection
- Displays detailed VM information
- Handles running VMs with graceful or force shutdown options
- Requires name confirmation before deletion
- Purges all VM disks and configuration

**Usage:**
```bash
chmod +x delete-vm.sh
./delete-vm.sh
```

**Interactive Flow:**
1. **Select VM**: Choose from list of available VMs
2. **Review Info**: View VM details (name, status, resources)
3. **Confirm Name**: Type exact VM name to proceed
4. **Stop VM** (if running):
   - **(Y)es**: Graceful shutdown (waits up to 60 seconds)
   - **(F)orce**: Force stop immediately
   - **(N)o**: Cancel operation
5. **Final Confirmation**: Type "yes" to complete deletion

**Example Session:**
```
Available VMs:
VMID  NAME            STATUS    MEM      BOOTDISK  PID
101   webserver-01    running   2048     20G       12345
102   test-vm         stopped   1024     10G       -

Enter VM ID to delete (or 'q' to quit): 101

VM Information:
  VM ID:        101
  Name:         webserver-01
  Status:       running
  Memory:       2048MB
  CPU Cores:    2
  Disks:        1

WARNING: You are about to delete this VM permanently!

Type the VM name 'webserver-01' to confirm deletion: webserver-01
Are you absolutely sure you want to delete VM 101? [yes/NO]: yes

VM 101 is currently running
Stop the VM before deletion? (Y)es/(N)o/(F)orce stop: Y
Shutdown command sent. Waiting for VM to stop...
VM stopped successfully

FINAL WARNING: Last chance to cancel!
Proceed with deletion of VM 101 (webserver-01)? [yes/NO]: yes
VM 101 deleted successfully!
```

**Safety Features:**
- Templates are excluded from deletion list
- Requires typing exact VM name to confirm
- Multiple confirmation prompts
- Automatic shutdown handling for running VMs
- Graceful shutdown with 60-second timeout
- Force stop option if graceful shutdown fails
- `--purge` flag ensures all disks are removed

**Shutdown Options:**
- **(Y)es**: Attempts graceful shutdown via ACPI
  - Waits up to 60 seconds for clean shutdown
  - Offers force stop if timeout occurs
- **(F)orce**: Immediately kills VM process
  - No clean shutdown, similar to power off
- **(N)o**: Cancels the deletion operation

**Requirements:**
- Proxmox VE environment
- SSH access to Proxmox host or run directly on Proxmox shell
- Appropriate permissions to delete VMs
- VMs must be stopped (script can handle this automatically)

---

### `task-manager.sh`
Real-time monitoring dashboard that displays comprehensive host statistics and VM information.

**What it does:**
- Shows detailed host statistics:
  - CPU model, cores, usage percentage with visual bar
  - Load average
  - Memory total, used, free with visual bar
  - Root disk usage with visual bar
  - Storage pool (local-lvm) usage with visual bar
  - System uptime
  - Network IP address
  - Proxmox version
- Displays all VMs in a formatted table:
  - VMID, name, status (color-coded)
  - Memory allocation (current/max for running VMs)
  - CPU usage percentage (running VMs only)
  - Disk size
  - VM uptime (running VMs only)
- Summary counts: Running, Stopped, Templates, Total
- Optional watch mode for continuous monitoring

**Usage:**
```bash
chmod +x task-manager.sh

# Single display
./task-manager.sh

# Watch mode (auto-refresh every 5 seconds)
./task-manager.sh --watch

# Watch mode with custom interval (10 seconds)
./task-manager.sh --watch 10

# Show help
./task-manager.sh --help
```

**Example Output:**
```
╔══════════════════════════════════════════════════════════════════════════════╗
║                         PROXMOX HOST STATISTICS                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

Hostname:            pve-host-01                Proxmox:        8.1.3
IP Address:          192.168.1.100              Uptime:         3 days, 5 hours

CPU Information:
  Model: Intel(R) Xeon(R) CPU E5-2680 v4 @ 2.40GHz
  Cores: 8           Usage: [████████░░░░░░░░░░] 35.2%
  Load Average: 1.23, 1.45, 1.67

Memory Usage:
  Total: 32G         Used: 18G          Free: 14G
  Usage: [██████████████████░░░░░░░░░░] 56.3%

Root Disk Usage:
  Total: 100G        Used: 45G          Free: 55G
  Usage: [█████████████████░░░░░░░░░░░] 45%

Storage (local-lvm):
  Total: 500.0G      Used: 250.5G       Avail: 249.5G
  Usage: [█████████████████████████░░░] 50.1%

╔══════════════════════════════════════════════════════════════════════════════╗
║                           VIRTUAL MACHINES                                   ║
╚══════════════════════════════════════════════════════════════════════════════╝

VMID     NAME                 STATUS       MEMORY     CPU      DISK       UPTIME
────────────────────────────────────────────────────────────────────────────────
100      ubuntu-template      template     2048M      -        20G        -
101      webserver-01         running      1856M/4096M 12.3%   50G        2d 5h
102      db-primary           running      7234M/8192M 45.1%   100G       15d 3h
103      test-vm              stopped      2048M      -        20G        -
104      docker-host          running      2048M/4096M 8.7%    80G        6h 23m
────────────────────────────────────────────────────────────────────────────────
Summary: Running: 3  Stopped: 1  Templates: 1  Total: 5

Legend:
  Green  = Running VM
  Yellow = Stopped VM
  Blue   = Template

Quick Actions:
  Start VM:    qm start <VMID>
  Stop VM:     qm shutdown <VMID>
  Console:     qm terminal <VMID>
  VM Config:   qm config <VMID>

Last updated: 2025-01-22 14:30:45
```

**Features:**
- **Color-coded status**: Green (running), Yellow (stopped), Blue (template)
- **Visual progress bars**: CPU, memory, and disk usage indicators
- **Real-time metrics**: Current CPU and memory usage for running VMs
- **Watch mode**: Continuous monitoring with customizable refresh interval
- **Comprehensive stats**: Both host-level and VM-level information
- **Quick reference**: Shows common commands at bottom

**Status Colors:**
- **Progress Bars**:
  - Green: < 60% usage (healthy)
  - Yellow: 60-80% usage (warning)
  - Red: > 80% usage (critical)
- **VM Status**:
  - Green: Running VMs
  - Yellow: Stopped VMs
  - Blue: Templates

**Requirements:**
- Proxmox VE environment
- SSH access to Proxmox host or run directly on Proxmox shell
- `bc` package for calculations (usually pre-installed)

**Tips:**
- Use watch mode for monitoring: `./task-manager.sh --watch`
- Press Ctrl+C to exit watch mode
- Adjust refresh interval based on your needs (shorter for real-time, longer to reduce load)
- Combine with other monitoring tools for comprehensive system analysis

## Creating Templates

Before using `create-vm.sh`, you need VM templates. See the related scripts:

- **Ubuntu Server Template**: [../ubuntu-server/prepare-template.sh](../ubuntu-server/prepare-template.sh)
  - Prepares Ubuntu VMs for templating with cloud-init support
  - See [Ubuntu Server Scripts README](../ubuntu-server/README.md)

**Quick template creation:**
```bash
# 1. Install Ubuntu Server on a VM
# 2. Run the preparation script
sudo ../ubuntu-server/prepare-template.sh

# 3. Shut down the VM
shutdown -h now

# 4. Convert to template in Proxmox
qm template <VMID>
```

## Common Workflows

### Creating a Full Clone VM
```bash
./create-vm.sh
# Choose template
# Enter VM name
# Select (F)ull Clone
```

**Use full clones when:**
- Creating production VMs
- Need complete independence from template
- Template might be deleted/modified later
- Storage space is not a concern

### Creating a Linked Clone VM
```bash
./create-vm.sh
# Choose template
# Enter VM name
# Select (L)inked Clone
```

**Use linked clones when:**
- Creating test/dev environments
- Need fast VM provisioning
- Template will remain static
- Want to save storage space

**Warning**: Linked clones depend on the original template. If you delete the template, linked clones will fail.

## Proxmox CLI Reference

### List all VMs and templates
```bash
qm list
```

### Check VM status
```bash
qm status <VMID>
```

### View VM configuration
```bash
qm config <VMID>
```

### Modify VM resources
```bash
# Change memory (in MB)
qm set <VMID> --memory 4096

# Change CPU cores
qm set <VMID> --cores 4

# Change network
qm set <VMID> --net0 virtio,bridge=vmbr0
```

### VM power operations
```bash
# Start VM
qm start <VMID>

# Stop VM gracefully
qm shutdown <VMID>

# Stop VM forcefully
qm stop <VMID>

# Reboot VM
qm reboot <VMID>
```

### Cloud-Init configuration
```bash
# Set SSH key
qm set <VMID> --sshkey ~/.ssh/id_rsa.pub

# Set IP configuration
qm set <VMID> --ipconfig0 ip=192.168.1.100/24,gw=192.168.1.1

# Set nameserver
qm set <VMID> --nameserver 8.8.8.8

# Regenerate cloud-init image
qm cloudinit dump <VMID> user
```

### Template management
```bash
# Convert VM to template
qm template <VMID>

# Clone template (full)
qm clone <TEMPLATE_ID> <NEW_VMID> --name <NAME> --storage local-lvm

# Clone template (linked)
qm clone <TEMPLATE_ID> <NEW_VMID> --name <NAME> --storage local-lvm --full 0
```

### Delete VM
```bash
qm destroy <VMID>
```

## Storage Locations

**local-lvm**: Default LVM-thin storage
- Path: `/dev/pve/data`
- Type: LVM-Thin
- Content: Disk images, containers
- Best for: VM disks (better performance)

**local**: Directory-based storage
- Path: `/var/lib/vz`
- Type: Directory
- Content: ISO images, templates, backups
- Best for: ISO files, backups, CT templates

## Troubleshooting

### Script won't execute
```bash
# Make script executable
chmod +x create-vm.sh
```

### "Command not found: qm"
- Ensure you're running on a Proxmox host
- Or SSH into your Proxmox server first

### "Permission denied"
- Run as root or with sudo privileges
- Check Proxmox user permissions

### "Storage 'local-lvm' does not exist"
```bash
# List available storage
pvesm status

# Modify script to use different storage
# Edit create-vm.sh and change --storage parameter
```

### Template not found
```bash
# List all VMs and templates
qm list | grep template

# Verify template ID
qm config <TEMPLATE_ID> | grep template
```

### VM creation fails
```bash
# Check available disk space
df -h

# Check LVM space
lvs

# View detailed error
journalctl -xe
```

## Best Practices

1. **Use descriptive VM names**
   - Include purpose: `webserver-01`, `db-primary`, `docker-host-01`
   - Include environment: `prod-app-01`, `dev-app-01`, `test-app-01`

2. **Plan VM IDs**
   - Use ranges: 100-199 for templates, 200-299 for production, etc.
   - Document your numbering scheme

3. **Template maintenance**
   - Keep templates updated monthly
   - Test templates before using in production
   - Version template names: `ubuntu-2404-v1`, `ubuntu-2404-v2`

4. **Resource allocation**
   - Start conservative (2GB RAM, 2 cores)
   - Scale up based on actual usage
   - Monitor resource usage after deployment

5. **Clone mode selection**
   - **Production**: Always use full clones
   - **Development/Testing**: Linked clones acceptable
   - **Templates**: Keep original template, never modify

6. **Cloud-init usage**
   - Set default SSH keys in template cloud-init config
   - Configure network settings per VM after creation
   - Use cloud-init for initial setup automation

## Future Enhancements

Planned additions to this directory:
- Bulk VM creation script
- VM resource adjustment script
- VM backup automation
- Template update script
- VM migration helper
- Snapshot management script

---

## References

- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)
- [QEMU/KVM Management (qm)](https://pve.proxmox.com/pve-docs/qm.1.html)
- [Cloud-Init Support](https://pve.proxmox.com/wiki/Cloud-Init_Support)
- [Proxmox CLI](https://pve.proxmox.com/wiki/Proxmox_VE_API)
