# Scripts Directory

Automation scripts for infrastructure management, VM operations, Docker orchestration, and system utilities.

## Directory Structure

```
scripts/
├── authorize-git-keys.sh          # Import SSH keys from GitHub
├── docker-hosts/                  # Docker Swarm setup and management
│   ├── docker-agent-install.sh    # Setup worker nodes with Portainer Agent
│   ├── docker-swarm-manager.sh    # Setup manager node with Portainer Server
│   ├── nfs-scripts.sh             # Configure NFS mount for /scripts
│   └── README.md
├── proxmox/                       # Proxmox VM management
│   ├── create-vm.sh               # Create VMs from templates
│   ├── delete-vm.sh               # Delete VMs with confirmation
│   ├── task-manager.sh            # Monitor Proxmox tasks
│   └── README.md
├── synology/                      # Synology NAS automation
│   ├── quick-sync.sh              # Fast git sync with auto-permissions
│   ├── sync-scripts-repo.sh       # Full sync with validation
│   └── README.md
├── tacticalrmm/                   # TacticalRMM installation
│   ├── install-tactical-rmm.sh    # Automated TacticalRMM setup
│   ├── verify-tacticalrmm.sh      # Post-install verification
│   └── readme.md
└── ubuntu-server/                 # Ubuntu VM template preparation
    ├── prepare-template.sh        # Prepare VMs for templating
    ├── SSH-KEY-MANAGEMENT.md      # SSH key setup guide
    └── README.md
```

## Quick Start Guides

### Docker Swarm Cluster Setup

1. **Prepare your template:**
   ```bash
   # On a fresh Ubuntu VM
   sudo ./ubuntu-server/prepare-template.sh
   # Shutdown and convert to template in Proxmox
   ```

2. **Create VMs from template:**
   ```bash
   # On Proxmox host
   ./proxmox/create-vm.sh
   # Create docker-00 (manager), docker-01, docker-02 (workers)
   ```

3. **Setup manager node:**
   ```bash
   # On docker-00
   sudo ./docker-hosts/docker-swarm-manager.sh
   docker swarm init --advertise-addr <MANAGER_IP>
   # Access Portainer at http://<MANAGER_IP>:9000
   ```

4. **Setup worker nodes:**
   ```bash
   # On docker-01, docker-02, etc.
   sudo ./docker-hosts/docker-agent-install.sh
   docker swarm join --token <TOKEN> <MANAGER_IP>:2377
   ```

### Synology Script Sync

Keep your Synology NAS synchronized with the latest scripts from GitHub:

```bash
# Quick sync (minimal output)
./synology/quick-sync.sh

# Full sync with validation
./synology/sync-scripts-repo.sh
```

### SSH Key Management

Import your GitHub SSH keys to any server:

```bash
# As current user
./authorize-git-keys.sh

# As root
sudo ./authorize-git-keys.sh
```

## Script Descriptions

### Root Level Scripts

#### authorize-git-keys.sh
Imports SSH public keys from GitHub account (`gh:dihoyt`) and adds them to `~/.ssh/authorized_keys`.

**Features:**
- Fetches keys from GitHub API
- Backs up existing authorized_keys
- Sets proper permissions (600)
- Works for both root and regular users
- Shows imported key fingerprints

**Usage:**
```bash
./authorize-git-keys.sh
```

## Folder-Specific Details

### docker-hosts/
Complete Docker Swarm cluster setup with Portainer management.

**Key files:**
- `docker-swarm-manager.sh` - Installs Docker, Portainer Server, configures firewall
- `docker-agent-install.sh` - Installs Docker, Portainer Agent, prepares for swarm
- `nfs-scripts.sh` - Mounts NFS share (10.50.1.100:/volume1/scripts → /scripts)

See [docker-hosts/README.md](docker-hosts/README.md) for detailed setup guide.

### proxmox/
Proxmox VM lifecycle management scripts.

**Key files:**
- `create-vm.sh` - Interactive VM creation from templates with cloud-init support
- `delete-vm.sh` - Safe VM deletion with confirmation prompts
- `task-manager.sh` - Monitor running Proxmox tasks

See [proxmox/README.md](proxmox/README.md) for usage examples.

### synology/
Scripts for keeping Synology NAS in sync with GitHub repository.

**Key files:**
- `quick-sync.sh` - Fast sync, sets permissions automatically (777 + executable .sh files)
- `sync-scripts-repo.sh` - Full sync with validation and error checking

See [synology/README.md](synology/README.md) for scheduling and automation.

### tacticalrmm/
Automated installation and verification of TacticalRMM.

**Key files:**
- `install-tactical-rmm.sh` - Full TacticalRMM installation
- `verify-tacticalrmm.sh` - Post-install health checks

See [tacticalrmm/readme.md](tacticalrmm/readme.md) for prerequisites and setup.

### ubuntu-server/
VM template preparation for Proxmox cloud-init templates.

**Key files:**
- `prepare-template.sh` - Comprehensive script to clean and prepare Ubuntu VMs for templating

**What it does:**
- Installs cloud-init and QEMU guest agent
- Cleans machine-specific data (SSH keys, machine ID, logs)
- Updates system packages
- Installs common tools
- Zeros free space for better compression

See [ubuntu-server/README.md](ubuntu-server/README.md) for detailed usage.

## Common Workflows

### New Ubuntu VM Template

```bash
# 1. Create fresh Ubuntu VM in Proxmox
# 2. SSH into the VM
# 3. Run preparation script
sudo ./ubuntu-server/prepare-template.sh

# 4. Shutdown
sudo shutdown -h now

# 5. Convert to template (on Proxmox host)
qm template <VMID>
```

### Deploy New Docker Swarm Node

```bash
# 1. Clone template in Proxmox
./proxmox/create-vm.sh

# 2. Start VM and SSH in
# 3. Configure NFS mount (optional)
sudo ./docker-hosts/nfs-scripts.sh

# 4. Install Docker + Portainer
# For manager:
sudo ./docker-hosts/docker-swarm-manager.sh

# For worker:
sudo ./docker-hosts/docker-agent-install.sh

# 5. Join/create swarm cluster
```

### Update Scripts on Synology

```bash
# On Synology NAS (via SSH or Task Scheduler)
cd /volume1/scripts/synology
./quick-sync.sh

# All scripts in /volume1/scripts are now updated and executable
```

## Requirements

### General
- Bash 4.0+
- Root/sudo access for most scripts
- Network connectivity

### Specific Tools
- **Proxmox scripts**: Proxmox VE host, `qm`, `pvesh` commands
- **Docker scripts**: Ubuntu 20.04+, internet access for package downloads
- **Synology scripts**: Git, rsync
- **SSH scripts**: curl

## Logging

Most scripts include comprehensive logging:

- **Docker scripts**: Log to `/scripts/logs.txt` with timestamps
- **Proxmox scripts**: Color-coded console output with status indicators
- **Template prep**: Console output with progress indicators

## NFS Share Setup

Many scripts assume an NFS share mounted at `/scripts`:

**NFS Server:** `10.50.1.100:/volume1/scripts`
**Mount Point:** `/scripts`

Configure with:
```bash
sudo ./docker-hosts/nfs-scripts.sh
```

Or add to `/etc/fstab`:
```
10.50.1.100:/volume1/scripts /scripts nfs defaults,_netdev 0 0
```

## Security Notes

- Scripts require root/sudo for system modifications
- SSH key scripts modify `~/.ssh/authorized_keys` - backups are created automatically
- Docker scripts open firewall ports - review before running in production
- NFS mounts use world-writable permissions (777) - adjust for your security requirements

## Contributing

When adding new scripts:

1. Include shebang (`#!/bin/bash`)
2. Add root check if needed
3. Include logging with timestamps
4. Add error handling
5. Create/update README in subfolder
6. Update this main README
7. Test on clean system

## Support

For detailed documentation on specific script categories, see the README.md files in each subdirectory.

## License

Internal use scripts for infrastructure automation.
