# Proxmox Management Scripts

This directory contains scripts for managing Proxmox VE (Virtual Environment) infrastructure.

## Quick Reference

| Script | Purpose | Interactive |
|--------|---------|-------------|
| `new-docker-host.sh` | Create Docker host from template 104 | No |
| `create-vm.sh` | Create VM from any template | Yes |
| `delete-vm.sh` | Delete VMs safely | Yes |
| `task-manager.sh` | Monitor host and VMs | No |
| `ssh-gh-dih-root.sh` | Configure SSH key-only access | No |
| `authorize-git-keys.sh` | Import GitHub SSH keys | No |
| `root-key-access.sh` | Disable SSH password auth | No |
| `remove-node-from-cluster.sh` | Remove node from cluster | Yes |
| `remove-cluster.sh` | Destroy cluster configuration | Yes |

---

## VM Management Scripts

### `new-docker-host.sh`
**One-command Docker host creation from template 104**

Automatically creates and starts a new Docker host VM with auto-incremented naming (`docker-01`, `docker-02`, etc.).

**Features:**
- No prompts - fully automated
- Auto-detects current node
- Auto-increments Docker host numbers
- Full clone from template 104
- Automatically starts VM
- Waits for IP address and displays it

**Usage:**
```bash
./new-docker-host.sh
```

**Output:**
```
[2025-01-22 14:30:00] Verifying template 104 exists
[2025-01-22 14:30:00] Using current node: pve-main
[2025-01-22 14:30:00] Scanning for existing docker-* VMs
[2025-01-22 14:30:01] Next available name: docker-03
[2025-01-22 14:30:01] Using next available VM ID: 105
[2025-01-22 14:30:01] Creating VM 105 (docker-03) from template 104
[2025-01-22 14:30:05] VM created successfully!
[2025-01-22 14:30:05] Starting VM 105
[2025-01-22 14:30:06] VM started successfully!
[2025-01-22 14:30:06] Waiting for VM to boot and acquire IP address
[2025-01-22 14:30:15] VM IP address acquired: 192.168.1.105

VM Details:
  VM ID:        105
  Name:         docker-03
  IP Address:   192.168.1.105
```

**Requirements:**
- Template 104 must exist
- Template 104 must have QEMU guest agent installed for IP detection

---

### `create-vm.sh`
**Interactive VM creation from any template**

Full-featured script for creating VMs with customizable options.

**Features:**
- Lists all available templates
- Prompts for template selection
- Customizable VM name
- Choice of full or linked clone
- Optional VLAN configuration
- Automatic VM startup

**Usage:**
```bash
./create-vm.sh
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
100   ubuntu-template template  2048     20G
104   docker-template template  4096     80G

Enter Template ID: 100
Enter new VM ID (or press Enter for next available): 201
Enter VM Name: webserver-01
Clone Mode - (F)ull Clone or (L)inked Clone [F/L]: F
Start the VM now? [Y/n]: y
```

---

### `delete-vm.sh`
**Safe VM deletion with multiple confirmations**

Interactive script with safety features to prevent accidental deletions.

**Features:**
- Excludes templates from deletion list
- Shows VM details before deletion
- Requires typing exact VM name
- Handles running VMs (graceful/force shutdown)
- Multiple confirmation prompts
- Purges all disks automatically

**Usage:**
```bash
./delete-vm.sh
```

**Safety Features:**
- Name confirmation required
- Running VMs must be stopped first
- Final "yes" confirmation
- Templates cannot be deleted

---

### `task-manager.sh`
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
./task-manager.sh

# Watch mode (refresh every 5 seconds)
./task-manager.sh --watch

# Custom refresh interval
./task-manager.sh --watch 10
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

## SSH Configuration Scripts

### `ssh-gh-dih-root.sh`
**One-command SSH security configuration**

Fetches SSH keys from GitHub user `dihoyt` and configures SSH for key-only root access.

**What it does:**
1. Imports SSH keys from `github.com/dihoyt.keys`
2. Adds keys to `/root/.ssh/authorized_keys`
3. Configures SSH to disable password authentication
4. Enables root login with keys only
5. Restarts SSH service

**Usage:**
```bash
./ssh-gh-dih-root.sh
```

**Requirements:**
- Must run as root
- Internet access to github.com
- SSH service installed

**Security:**
- Disables password authentication completely
- Only SSH keys from GitHub user `dihoyt` allowed
- Backs up existing configurations

---

### `authorize-git-keys.sh`
**Import SSH keys from GitHub**

Standalone script to import SSH keys from GitHub user `dihoyt`.

**Usage:**
```bash
# As root (configures /root/.ssh)
sudo ./authorize-git-keys.sh

# As regular user (configures $HOME/.ssh)
./authorize-git-keys.sh
```

**Features:**
- Fetches keys from `github.com/dihoyt.keys`
- Works for root or regular users
- Backs up existing authorized_keys
- Shows key fingerprints after import

---

### `root-key-access.sh`
**Configure SSH for key-only authentication**

Assumes `authorize-git-keys.sh` has already been run. Configures SSH daemon to disable password authentication.

**Usage:**
```bash
./root-key-access.sh
```

**Requirements:**
- Must run as root
- Requires existing `/root/.ssh/authorized_keys`
- Run `authorize-git-keys.sh` first if needed

**What it configures:**
- `PermitRootLogin prohibit-password`
- `PasswordAuthentication no`
- `PubkeyAuthentication yes`
- `ChallengeResponseAuthentication no`

---

## Cluster Management Scripts

### `remove-node-from-cluster.sh`
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
./remove-node-from-cluster.sh
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

[2025-01-22 14:30:00] Removing node pve-mini from cluster
[2025-01-22 14:30:05] Node pve-mini removed from cluster successfully
```

**When to use:**
- Decommissioning a node
- Downsizing cluster
- Replacing a failed node

---

### `remove-cluster.sh`
**Destroy cluster configuration and return to standalone**

Removes all cluster configuration from the current node, returning it to standalone mode.

**WARNING:** Only use this when:
- You are the last node in the cluster, OR
- You want to completely destroy cluster configuration on this node

**Features:**
- Shows warning about cluster destruction
- Lists current cluster nodes before proceeding
- Requires explicit confirmation
- Removes all cluster files and databases
- Restarts services in standalone mode
- Verifies standalone operation

**Usage:**
```bash
./remove-cluster.sh
```

**Example:**
```
[2025-01-22 14:30:00] Running on node: pve-main

════════════════════════════════════════════════════════════
                         WARNING
════════════════════════════════════════════════════════════

This will completely remove cluster configuration from this node.
If other nodes are still in the cluster, remove them first using:
  ./remove-node-from-cluster.sh

Current cluster nodes:
Node     ID   Addr           Status
pve-main 1    192.168.1.100  online

════════════════════════════════════════════════════════════

Are you sure you want to remove cluster configuration? [y/N]: y

[2025-01-22 14:30:05] Removing cluster configuration from pve-main
[2025-01-22 14:30:10] Cluster configuration removed
[2025-01-22 14:30:15] System is now running in standalone mode
```

**Recommended workflow:**
1. Remove all other nodes with `remove-node-from-cluster.sh`
2. Verify you're the last node
3. Run `remove-cluster.sh` on the last node

---

## Common Workflows

### Quick Docker Host Deployment
```bash
# Create and start a new Docker host in one command
./new-docker-host.sh

# SSH into new host once IP is displayed
ssh user@192.168.1.105
```

### Secure SSH Setup on New Proxmox Node
```bash
# One command to configure SSH keys and disable passwords
sudo ./ssh-gh-dih-root.sh

# Test SSH access from another terminal before closing current session
ssh root@proxmox-host
```

### Cluster Teardown
```bash
# Step 1: Remove secondary node (run on primary)
./remove-node-from-cluster.sh
# Select secondary node

# Step 2: Destroy cluster (run on last remaining node)
./remove-cluster.sh
```

### Monitor System During Deployment
```bash
# Start monitoring in watch mode
./task-manager.sh --watch

# In another terminal, deploy VMs
./new-docker-host.sh
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
- **100-199**: Templates
- **200-299**: Production VMs
- **300-399**: Development VMs
- **400-499**: Test VMs

### Template Management
- Keep templates updated monthly
- Test templates before production use
- Version template names: `ubuntu-2404-v1`, `ubuntu-2404-v2`
- Always include QEMU guest agent in templates

### Clone Mode Selection
- **Production**: Always use full clones
- **Development/Testing**: Linked clones acceptable
- **Never delete templates** if linked clones exist

### Security
- Always use SSH keys, never passwords
- Disable password authentication after key setup
- Test SSH access before closing existing session
- Keep a backup method to access the system

### Cluster Management
- Document cluster topology
- Remove failed nodes promptly
- Test cluster operations in dev first
- Keep cluster nodes synchronized (time, versions)

---

## Troubleshooting

### Script won't execute
```bash
chmod +x scriptname.sh
```

### "Command not found: qm"
- Ensure running on Proxmox host
- SSH into Proxmox server first

### Template 104 not found
```bash
# List all templates
qm list | grep template

# Create template 104 or modify script
```

### Can't SSH after running ssh scripts
- Keep original session open
- Check `/etc/ssh/sshd_config` for errors
- Restore from backup: `cp /etc/ssh/sshd_config.backup.* /etc/ssh/sshd_config`
- Restart SSH: `systemctl restart sshd`

### Cluster removal fails
```bash
# Check cluster status
pvecm status

# Manually stop services
systemctl stop pve-cluster corosync

# Check for stuck processes
ps aux | grep pmxcfs
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