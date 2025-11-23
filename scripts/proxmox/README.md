# Proxmox Management Scripts

This directory contains scripts for managing Proxmox VE (Virtual Environment) infrastructure.

## Quick Reference

| Script | Purpose | Interactive |
|--------|---------|-------------|
| **VM Management** | | |
| `vm-create.sh` | Create VM from any template | Yes |
| `vm-delete.sh` | Delete VMs safely | Yes |
| `addhost-docker.sh` | Create Docker host (template 201) | No |
| `addhost-ubuntusrv.sh` | Create Ubuntu server (template 200) | No |
| `recover-vm-from-disk.sh` | Recover VM from existing disk | Yes |
| **Template Management** | | |
| `template-create.sh` | Convert VM to template | Yes |
| `template-delete.sh` | Delete templates (with/without disks) | Yes |
| **Cluster Management** | | |
| `cluster-management/cluster-removenode.sh` | Remove node from cluster | Yes |
| `cluster-management/fix-local-storage.sh` | Fix local storage after cluster removal | No |
| `cluster-management/add-nfs-storage.sh` | Add NFS storage to node | Yes |
| `cluster-management/task-manager.sh` | Monitor host and VMs | No |
| **Helper Scripts** | | |
| `jobs/ubuntu-vm-setup.sh` | Post-creation Ubuntu VM setup | No |

---

## VM Management Scripts

### `vm-create.sh`
**Interactive VM creation from any template**

Full-featured script for creating VMs with customizable options.

**Features:**
- Lists all available templates
- Prompts for template selection
- Customizable VM name
- Choice of full or linked clone
- Automatic VM startup with IP detection
- Automatically runs ubuntu-vm-setup.sh for post-creation configuration

**Usage:**
```bash
./vm-create.sh
```

**Interactive Prompts:**
1. **Template ID**: Select from displayed list
2. **New VM ID**: Enter specific ID or auto-assign
3. **VM Name**: Custom hostname
4. **Clone Mode**: Full or Linked
5. **Start VM**: Optionally start after creation

**Example:**
```
Available Templates:
VMID  NAME            STATUS    MEM      BOOTDISK
200   ubuntu-template template  2048     20G
201   docker-template template  4096     80G

Enter Template ID: 200
Enter new VM ID (or press Enter for next available): 301
Enter VM Name: webserver-01
Clone Mode - (F)ull Clone or (L)inked Clone [F/L]: F
Start the VM now? [Y/n]: y

[2025-01-23 14:30:15] VM IP address acquired: 192.168.1.50

===============================================================================
                    VM IP Address: 192.168.1.50
===============================================================================
```

**Post-Creation:**
If the VM is started and gets an IP address, the script automatically calls `jobs/ubuntu-vm-setup.sh` to:
- Wait for SSH to be ready
- Wait for cloud-init to complete
- Reboot the VM
- SSH into the VM as ubadmin

---

### `addhost-docker.sh`
**One-command Docker host creation from template 201**

Fully automated script that creates and configures a new Docker host VM with auto-incremented naming (`docker-01`, `docker-02`, etc.).

**Features:**
- No prompts - fully automated
- Uses template 201
- Auto-increments Docker host numbers (docker-01, docker-02, etc.)
- VM IDs start at 500
- Full clone for production use
- Automatically starts VM
- Waits for IP address
- Displays highlighted IP address
- Automatically runs ubuntu-vm-setup.sh for complete configuration

**Usage:**
```bash
./addhost-docker.sh
```

**Progress Display:**
```
[1/5] ✓ Cloning template 201 to create docker-01 (VM ID: 500)
[2/5] ✓ Starting VM 500
[3/5] ✓ Waiting for VM to boot
[4/5] ✓ VM IP address acquired: 192.168.1.105
[5/5] ✓ VM docker-01 is ready

===============================================================================
                    VM IP Address: 192.168.1.105
===============================================================================

[2025-01-23 14:30:00] Starting automated VM setup...
```

**Requirements:**
- Template 201 must exist
- Template 201 must have QEMU guest agent installed

---

### `addhost-ubuntusrv.sh`
**One-command Ubuntu server creation from template 200**

Fully automated script identical to addhost-docker.sh but for Ubuntu servers.

**Features:**
- No prompts - fully automated
- Uses template 200
- Auto-increments server numbers (ubuntusrv-01, ubuntusrv-02, etc.)
- VM IDs start at 400
- Full clone for production use
- Automatically starts VM and runs ubuntu-vm-setup.sh

**Usage:**
```bash
./addhost-ubuntusrv.sh
```

**Requirements:**
- Template 200 must exist

---

### `vm-delete.sh`
**Safe VM deletion with streamlined confirmation**

Interactive script with safety features to prevent accidental deletions.

**Features:**
- Excludes templates from deletion list
- Shows VM details before deletion
- Auto-stops running VMs (graceful 30s timeout, then force stop)
- Single confirmation by typing VM ID
- Purges all disks automatically

**Usage:**
```bash
./vm-delete.sh
```

**Workflow:**
1. Lists all non-template VMs
2. Prompts for VM ID to delete
3. Displays VM information
4. Auto-stops VM if running
5. Requires typing VM ID to confirm deletion
6. Deletes VM with all disks

**Example:**
```
Available VMs:
VMID  NAME           STATUS    MEM      BOOTDISK
301   webserver-01   running   2048     20G
500   docker-01      stopped   4096     80G

Enter VM ID to delete (or 'q' to quit): 301

===============================================================================
                    VM Information
===============================================================================

  VM ID:        301
  Name:         webserver-01
  Status:       running
  Memory:       2048MB
  CPU Cores:    2
  Disks:        1

===============================================================================

WARNING: VM 301 is currently running. It will be stopped before deletion.

[2025-01-23 14:30:00] Stopping VM 301...
[2025-01-23 14:30:15] VM stopped successfully

WARNING: You are about to delete this VM permanently!

You've selected 'webserver-01' - type the VM ID '301' to confirm deletion: 301
```

**Safety Features:**
- Templates cannot be deleted (use template-delete.sh)
- Shows complete VM information before deletion
- Requires typing exact VM ID to proceed
- Automatic graceful shutdown with force stop fallback

---

### `recover-vm-from-disk.sh`
**Recover or create VM from existing LVM disk**

Creates a new VM configuration using an existing disk that may have been orphaned or needs to be recovered.

**Features:**
- Lists available LVM volumes
- Creates new VM with existing disk
- Configures basic VM settings (memory, CPU, network)
- Generates proper UUIDs (works without uuidgen command)

**Usage:**
```bash
./recover-vm-from-disk.sh
```

**Use Cases:**
- Recovering VMs after accidental configuration deletion
- Migrating disks between VMs
- Importing disks from other systems

## Template Management Scripts

### `template-create.sh`
**Convert existing VM to template**

Interactive script to safely convert a VM into a reusable template.

**Features:**
- Lists all non-template VMs
- Shows VM information before conversion
- Auto-stops running VMs (graceful shutdown with fallback)
- Provides preparation recommendations
- Converts VM to template

**Usage:**
```bash
./template-create.sh
```

**Workflow:**
1. Lists all VMs (excluding existing templates)
2. Prompts for VM ID to convert
3. Displays VM information
4. Stops VM if running (graceful/force stop)
5. Confirms conversion
6. Converts to template

**Example:**
```
Available VMs:
VMID  NAME            STATUS    MEM      BOOTDISK
301   ubuntu-clean    stopped   2048     20G

Enter VM ID to convert to template: 301

===============================================================================
                    VM Information
===============================================================================

  VM ID:        301
  Name:         ubuntu-clean
  Status:       stopped
  Memory:       2048MB
  CPU Cores:    2

===============================================================================

IMPORTANT: Before converting to template, ensure:
  • System is fully updated (apt update && apt upgrade)
  • SSH host keys removed (rm /etc/ssh/ssh_host_*)
  • Machine ID cleared (truncate -s 0 /etc/machine-id)
  • Network configs use DHCP or cloud-init
  • User accounts cleaned up
  • History cleared (history -c)
  • QEMU Guest Agent installed

Proceed with template conversion? [Y/n]: y
```

**Best Practices:**
- Always prepare VMs before converting (generalize configuration)
- Install QEMU Guest Agent for IP detection
- Use cloud-init for automated configuration
- Document template version and purpose

---

### `template-delete.sh`
**Delete templates with optional disk preservation**

Interactive script to safely delete templates with choice to keep or remove disks.

**Features:**
- Lists only templates (excludes regular VMs)
- Shows template information and disk details
- Option to delete disks or preserve them
- Clear explanation of both deletion modes
- Requires typing template name to confirm

**Usage:**
```bash
./template-delete.sh
```

**Workflow:**
1. Lists all templates
2. Prompts for template ID
3. Displays template and disk information
4. Asks whether to delete or preserve disks
5. Requires typing template name to confirm
6. Deletes template

**Example:**
```
Available Templates:
VMID  NAME            STATUS    MEM      BOOTDISK
200   ubuntu-template template  2048     20G
201   docker-template template  4096     80G

Enter Template ID to delete: 200

===============================================================================
                    Template Information
===============================================================================

  Template ID:  200
  Name:         ubuntu-template
  Memory:       2048MB
  CPU Cores:    2
  Disks:        1

===============================================================================

Getting disk information for template 200...

scsi0: local-lvm:vm-200-disk-0,size=20G

===============================================================================
Disk Deletion Options:
===============================================================================

  1. Delete configuration AND disks (--purge)
     • Removes the template completely
     • Deletes all associated disk images
     • Frees up storage space

  2. Delete configuration ONLY (keep disks)
     • Removes the template configuration
     • Preserves disk images for potential recovery
     • Disks become orphaned and must be managed manually

===============================================================================

Do you want to delete the disks as well? [y/N]: y

WARNING: You are about to delete this template permanently!

Type the template name 'ubuntu-template' to confirm deletion: ubuntu-template
```

**Disk Preservation:**
When choosing to keep disks, the script provides commands to:
- View orphaned disks: `lvs | grep -E "vm-200-"`
- Remove orphaned disks later: `lvremove /dev/pve/vm-200-disk-X`

---

## Helper Scripts

### `jobs/ubuntu-vm-setup.sh`
**Post-creation Ubuntu VM setup automation**

Automated helper script called by vm-create.sh, addhost-docker.sh, and addhost-ubuntusrv.sh to complete VM setup.

**Features:**
- Waits for SSH to become available
- Waits for cloud-init to complete
- Reboots the VM
- Waits for VM to come back online
- Automatically SSHs into the VM as ubadmin

**Usage:**
```bash
# Called automatically by VM creation scripts
# Can also be run manually
./jobs/ubuntu-vm-setup.sh <VM_IP_ADDRESS>
```

**Example:**
```bash
./jobs/ubuntu-vm-setup.sh 192.168.1.50
```

**Progress Display:**
```
[2025-01-23 14:30:00] Starting Ubuntu VM setup for 192.168.1.50
[2025-01-23 14:30:05] ✓ SSH is ready
[2025-01-23 14:30:10] ✓ Cloud-init completed
[2025-01-23 14:30:15] Rebooting VM...
[2025-01-23 14:30:45] ✓ VM is back online
[2025-01-23 14:30:46] Connecting to VM via SSH...

Welcome to Ubuntu 24.04 LTS
ubadmin@webserver-01:~$
```

**Requirements:**
- VM must have SSH enabled
- VM must have cloud-init installed
- VM must have ubadmin user configured

---

## Cluster Management Scripts

### `cluster-management/cluster-removenode.sh`
**Remove a node from Proxmox cluster**

Interactive script to remove nodes from a cluster while keeping the cluster active.

**Features:**
- Displays all cluster nodes
- Select which node to remove (excluding current)
- Confirms selection before proceeding
- Shows updated cluster status after removal
- Cluster remains functional with remaining nodes

**Usage:**
```bash
# Run on the node you want to KEEP
./cluster-management/cluster-removenode.sh
```

**Example:**
```
Running on node: pve-main

Current Cluster Nodes:
Node     ID   Addr           Status
pve-main 1    192.168.1.100  online
pve-mini 2    192.168.1.101  online

Available nodes to remove (excluding current node pve-main):
 1. pve-mini

Enter the number of the node to remove: 1
Selected node to remove: pve-mini

Are you sure you want to remove pve-mini from the cluster? [y/N]: y

[2025-01-23 14:30:00] Removing node pve-mini from cluster
[2025-01-23 14:30:05] Node pve-mini removed from cluster successfully
```

**When to use:**
- Decommissioning a node
- Downsizing cluster
- Replacing a failed node

**After Removal:**
If the removed node was part of a cluster, you may need to run `fix-local-storage.sh` on the removed node to restore local storage access.

---

### `cluster-management/fix-local-storage.sh`
**Fix local storage after cluster removal**

Restores local storage functionality on a node that was removed from a cluster.

**Features:**
- Automatically detects node name
- Updates storage configuration
- Removes cluster-specific storage settings
- Restarts necessary services

**Usage:**
```bash
# Run on the node that was removed from cluster
./cluster-management/fix-local-storage.sh
```

**When to use:**
- After removing a node from a cluster
- When local storage is inaccessible after cluster disbanding
- When storage shows as unavailable in standalone mode

**Example:**
```
[2025-01-23 14:30:00] Fixing local storage configuration for node: pve-mini
[2025-01-23 14:30:01] Updating storage.cfg
[2025-01-23 14:30:02] Restarting PVE services
[2025-01-23 14:30:05] Local storage restored successfully
```

---

### `cluster-management/add-nfs-storage.sh`
**Add NFS storage to Proxmox node**

Interactive script to configure NFS storage on a Proxmox node.

**Features:**
- Prompts for NFS server details
- Validates NFS mount accessibility
- Configures storage in Proxmox
- Sets appropriate content types

**Usage:**
```bash
./cluster-management/add-nfs-storage.sh
```

**Interactive Prompts:**
1. **Storage ID**: Name for the storage in Proxmox
2. **NFS Server**: IP address or hostname of NFS server
3. **NFS Export Path**: Path to the NFS share
4. **Content Types**: What to store (images, backups, ISO, etc.)

**Example:**
```
Enter Storage ID: nfs-backup
Enter NFS Server IP/Hostname: 192.168.1.200
Enter NFS Export Path: /mnt/storage/proxmox
Select content types:
  [x] Images
  [x] Backups
  [ ] ISO
  [x] Container templates

[2025-01-23 14:30:00] Testing NFS connection...
[2025-01-23 14:30:02] NFS mount successful
[2025-01-23 14:30:03] Adding storage to Proxmox configuration
[2025-01-23 14:30:05] NFS storage 'nfs-backup' added successfully
```

**Requirements:**
- NFS server must be accessible
- NFS export must be configured with appropriate permissions
- Node must have network access to NFS server

---

### `cluster-management/task-manager.sh`
**Real-time Proxmox monitoring dashboard**

Displays comprehensive host statistics and VM information.

**Features:**
- Host CPU, memory, disk usage with visual bars
- VM list with status (color-coded)
- Running VM resource usage
- System uptime and network info
- Optional watch mode for continuous monitoring

**Usage:**
```bash
# Single display
./cluster-management/task-manager.sh

# Watch mode (refresh every 5 seconds)
./cluster-management/task-manager.sh --watch

# Custom refresh interval
./cluster-management/task-manager.sh --watch 10
```

**Example Output:**
```
╔══════════════════════════════════════════════════════════════╗
║                  PROXMOX HOST STATISTICS                     ║
╚══════════════════════════════════════════════════════════════╝

Hostname:    pve-main           Proxmox:  8.1.3
IP Address:  192.168.1.100      Uptime:   3 days, 5 hours

CPU Usage:   [████████░░░░░░░░] 35.2%
Memory:      [██████████░░░░░░] 56.3% (18G / 32G)
Root Disk:   [█████████░░░░░░░] 45% (45G / 100G)

VMID   NAME           STATUS    MEMORY        CPU    UPTIME
────────────────────────────────────────────────────────────
101    webserver-01   running   1856M/4096M   12.3%  2d 5h
102    docker-01      running   2048M/4096M   8.7%   6h 23m
103    test-vm        stopped   2048M         -      -

Summary: Running: 2  Stopped: 1  Total: 3
```

---

## Common Workflows

### Quick Docker Host Deployment
```bash
# Create and start a new Docker host in one command
./addhost-docker.sh

# The script will automatically:
# - Clone template 201
# - Start the VM
# - Get IP address
# - Run ubuntu-vm-setup.sh
# - SSH into the new host

# VM will be named docker-01, docker-02, etc.
# VM IDs start at 500
```

### Quick Ubuntu Server Deployment
```bash
# Create and start a new Ubuntu server in one command
./addhost-ubuntusrv.sh

# VM will be named ubuntusrv-01, ubuntusrv-02, etc.
# VM IDs start at 400
```

### Custom VM Creation
```bash
# Interactive VM creation with custom settings
./vm-create.sh

# Follow prompts to:
# - Select template
# - Set VM name
# - Choose full or linked clone
# - Start VM automatically
```

### Template Creation Workflow
```bash
# Step 1: Create and configure a clean VM
./vm-create.sh
# Name it something like "ubuntu-clean" or "docker-base"

# Step 2: SSH into the VM and prepare it for templating
ssh ubadmin@<VM_IP>
sudo apt update && sudo apt upgrade -y
sudo apt install qemu-guest-agent -y
sudo rm /etc/ssh/ssh_host_*
sudo truncate -s 0 /etc/machine-id
history -c
logout

# Step 3: Convert to template
./template-create.sh
# Select the VM ID and confirm
```

### Safe VM Deletion
```bash
# Delete a VM with automatic shutdown
./vm-delete.sh

# Script will:
# - List all VMs
# - Show VM details
# - Auto-stop if running
# - Require VM ID confirmation
# - Delete with all disks
```

### Cluster Node Removal
```bash
# Step 1: Remove secondary node (run on primary)
./cluster-management/cluster-removenode.sh
# Select secondary node to remove

# Step 2: Fix local storage on removed node
# (SSH into the removed node)
./cluster-management/fix-local-storage.sh
```

### Monitor System During Deployment
```bash
# Start monitoring in watch mode
./cluster-management/task-manager.sh --watch

# In another terminal, deploy VMs
./addhost-docker.sh
```

### Recover VM from Orphaned Disk
```bash
# If you have an orphaned disk (e.g., from template deletion)
./recover-vm-from-disk.sh

# Script will:
# - List available LVM volumes
# - Create new VM with existing disk
# - Configure basic settings
```

---

## Proxmox CLI Quick Reference

### VM Operations
```bash
# List all VMs
qm list

# View VM config
qm config <VMID>

# Start/stop VM
qm start <VMID>
qm shutdown <VMID>
qm stop <VMID>        # Force stop

# Clone VM
qm clone <TEMPLATE_ID> <NEW_VMID> --name <NAME> --full 1

# Modify resources
qm set <VMID> --memory 4096
qm set <VMID> --cores 4
qm set <VMID> --net0 virtio,bridge=vmbr0,tag=10  # With VLAN tag
```

### Cluster Operations
```bash
# View cluster status
pvecm status

# List cluster nodes
pvecm nodes

# Remove node from cluster
pvecm delnode <nodename>
```

### Storage
```bash
# List storage
pvesm status

# Check disk usage
df -h
lvs
```

---

## VLAN Configuration

Proxmox bridges can be VLAN-aware, allowing VMs to use different VLANs.

### Enable VLAN-Aware Bridge (GUI)
1. Navigate to **System** → **Network**
2. Select bridge (e.g., `vmbr0`)
3. Click **Edit**
4. Check **VLAN aware**
5. Click **OK** → **Apply Configuration**

### Assign VLAN to VM (GUI)
1. Select VM → **Hardware** tab
2. Edit **Network Device**
3. Enter **VLAN Tag** (e.g., 10, 20, 100)
4. Click **OK**

### Assign VLAN to VM (CLI)
```bash
# Set VLAN tag on network interface
qm set <VMID> --net0 virtio,bridge=vmbr0,tag=<VLAN_ID>

# Example: Assign VLAN 100
qm set 101 --net0 virtio,bridge=vmbr0,tag=100
```

---

## Best Practices

### VM Naming Conventions
- Use descriptive names: `docker-01`, `webserver-prod`, `db-primary`
- Include environment: `prod-app-01`, `dev-app-01`
- Use consistent numbering schemes

### VM ID Organization
- **100-199**: Reserved (system/future use)
- **200-299**: Templates
  - 200: Ubuntu Server template
  - 201: Docker Host template
- **300-399**: Custom/Manual VMs
- **400-499**: Ubuntu Servers (ubuntusrv-XX)
  - Created by addhost-ubuntusrv.sh
  - Auto-increments from 400
- **500-599**: Docker Hosts (docker-XX)
  - Created by addhost-docker.sh
  - Auto-increments from 500

### Template Management
- Keep templates updated monthly
- Test templates before production use
- Always include QEMU guest agent in templates (for IP detection)
- Prepare VMs properly before converting to templates:
  - Update all packages
  - Remove SSH host keys
  - Clear machine ID
  - Clear command history
  - Install cloud-init for automation
- Use template-create.sh to convert VMs to templates
- Use template-delete.sh to safely remove templates
- When deleting templates, choose whether to keep or purge disks

### Clone Mode Selection
- **Production**: Always use full clones (addhost-*.sh scripts)
- **Development/Testing**: Linked clones acceptable (vm-create.sh)
- **Never delete templates** if linked clones exist (data will be lost)

### Automated VM Creation
- Use addhost-docker.sh for Docker hosts (template 201, VM IDs 500+)
- Use addhost-ubuntusrv.sh for Ubuntu servers (template 200, VM IDs 400+)
- Use vm-create.sh for custom/manual VMs (any template)
- All scripts automatically run ubuntu-vm-setup.sh for post-creation configuration

### Cluster Management
- Document cluster topology
- Remove failed nodes promptly using cluster-removenode.sh
- Run fix-local-storage.sh on removed nodes to restore local storage
- Keep cluster nodes synchronized (time, versions)
- Use task-manager.sh to monitor cluster health

---

## Troubleshooting

### Script won't execute
```bash
chmod +x scriptname.sh
```

### "Command not found: qm"
- Ensure running on Proxmox host
- SSH into Proxmox server first

### Template 200 or 201 not found
```bash
# List all templates
qm list | grep -v VMID | while read line; do
  vmid=$(echo "$line" | awk '{print $1}')
  qm config "$vmid" 2>/dev/null | grep -q "template: 1" && echo "$line [TEMPLATE]"
done

# Create templates using template-create.sh
./template-create.sh
```

### VM creation fails with "uuidgen: command not found"
The scripts now have built-in UUID generation fallback. If you see this error on an older script:
```bash
# Use recover-vm-from-disk.sh which has the fallback implemented
./recover-vm-from-disk.sh
```

### VM doesn't get IP address
```bash
# Ensure QEMU Guest Agent is installed in the template
# SSH into the template before converting:
sudo apt install qemu-guest-agent -y
sudo systemctl enable qemu-guest-agent
sudo systemctl start qemu-guest-agent

# Then convert to template
./template-create.sh
```

### ubuntu-vm-setup.sh not found
```bash
# Ensure the script is in the jobs/ subdirectory
ls -la jobs/ubuntu-vm-setup.sh

# The VM creation scripts look for it at:
# ./jobs/ubuntu-vm-setup.sh (relative to script location)
```

### Local storage unavailable after cluster removal
```bash
# Run the fix-local-storage script
./cluster-management/fix-local-storage.sh

# This updates storage.cfg and restarts services
```

### Template deletion leaves orphaned disks
This is expected behavior when choosing "keep disks" option. To clean up:
```bash
# View orphaned disks
lvs | grep -E "vm-<TEMPLATE_ID>-"

# Remove specific disk
lvremove /dev/pve/vm-<TEMPLATE_ID>-disk-0

# Or recover the disk
./recover-vm-from-disk.sh
```

### VM stuck in "stopped" after creation
```bash
# Check VM status
qm status <VMID>

# Try manual start
qm start <VMID>

# Check logs
journalctl -u qemu-server@<VMID> -f
```

---

## Storage Locations

**local-lvm**: LVM-thin storage (default for VM disks)
- Path: `/dev/pve/data`
- Best for: VM disks (better performance)
- Content: Disk images, containers

**local**: Directory-based storage
- Path: `/var/lib/vz`
- Best for: ISO files, backups, templates
- Content: ISO images, CT templates, backups

---

## References

- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)
- [QEMU/KVM Management (qm)](https://pve.proxmox.com/pve-docs/qm.1.html)
- [Proxmox Cluster Manager](https://pve.proxmox.com/wiki/Cluster_Manager)
- [Cloud-Init Support](https://pve.proxmox.com/wiki/Cloud-Init_Support)
- [Network Configuration](https://pve.proxmox.com/wiki/Network_Configuration)