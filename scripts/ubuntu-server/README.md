# Ubuntu Server Scripts

This directory contains general-purpose scripts for Ubuntu Server administration and management, particularly focused on Proxmox virtualization environments.

## Documentation

- **[SSH Key Management Guide](SSH-KEY-MANAGEMENT.md)** - Comprehensive guide for managing SSH keys across multiple VMs

## Scripts

### 1. VM Template Preparation Script
**File:** `prepare-template.sh`

Comprehensive script to clean and prepare an Ubuntu VM for use as a Proxmox template with cloud-init support.

#### Purpose
Converts a freshly installed Ubuntu Server into a clean, reusable Proxmox template by:
- Removing machine-specific identifiers
- Installing and configuring cloud-init
- Cleaning logs, cache, and temporary files
- Preparing the system for cloud-init provisioning

#### What It Does

**Installation:**
- Installs cloud-init for automated VM provisioning
- Installs QEMU guest agent for Proxmox integration
- Updates all system packages
- Installs common administrative tools (curl, wget, vim, git, htop, etc.)

**Cloud-Init Configuration:**
- Creates Proxmox-optimized cloud-init configuration
- Sets up default user (ubuntu) with sudo access
- Configures cloud-init modules for network, SSH, users, etc.
- Enables cloud-init data sources (NoCloud, ConfigDrive)

**System Cleaning:**
- **Network:** Removes persistent network device names and DHCP leases
- **SSH:** Deletes host keys (regenerated on first boot by cloud-init)
- **Machine ID:** Truncates machine-id (regenerated on first boot)
- **Logs:** Cleans all log files and journal entries
- **Temporary Files:** Clears /tmp, /var/tmp, and apt cache
- **User Data:** Removes bash history, cache, and user-specific files
- **Swap:** Disables and removes swap file
- **Free Space:** Optionally zeros free space for better compression

#### Prerequisites
- Fresh Ubuntu Server installation (any recent version)
- Root access
- VM running in Proxmox environment
- Internet connectivity for package installation

#### Usage

1. **Install Ubuntu Server on your VM:**
   - Minimal installation recommended
   - Set a temporary hostname (will be overridden by cloud-init)
   - Configure temporary network settings

2. **Run the preparation script:**
   ```bash
   sudo ./prepare-template.sh
   ```

3. **Follow the prompts:**
   - The script will ask for confirmation before starting
   - Option to zero free space at the end (recommended but slow)

4. **Review the template information:**
   ```bash
   cat /root/TEMPLATE_INFO.txt
   ```

5. **Shut down the VM:**
   ```bash
   shutdown -h now
   ```

6. **Convert to template in Proxmox:**
   ```bash
   qm template <VMID>
   ```
   Or use the Proxmox web GUI: Right-click VM � Convert to template

#### Post-Template Setup

After converting to a template, configure cloud-init defaults in Proxmox GUI:

1. **Navigate to:** VM � Cloud-Init tab

2. **Configure defaults:**
   - **User:** ubuntu (or your preferred default user)
   - **Password:** Set a default password (optional)
   - **SSH Public Key:** Add your public SSH key
   - **DNS Domain:** Your domain (e.g., hoyt.local)
   - **DNS Servers:** Your DNS server IPs
   - **IP Config (net0):** DHCP or static IP configuration

3. **Regenerate Image:** Click "Regenerate Image" after making changes

#### SSH Key Management

**For automatic SSH access without console configuration, see the [SSH Key Management Guide](SSH-KEY-MANAGEMENT.md).**

**Quick setup for GitHub key import:**

1. Edit the cloud-init config in the template before converting:
   ```bash
   sudo nano /etc/cloud/cloud.cfg.d/99-pve.cfg
   ```

2. Uncomment and set your GitHub username:
   ```yaml
   ssh_import_id: [gh:YOUR_GITHUB_USERNAME]
   ```

3. Every VM cloned from this template will automatically fetch your SSH keys from GitHub on first boot!

**Result:** SSH into new VMs immediately after boot - no console or manual key configuration needed.

#### Using the Template

**Creating VMs from the template:**

1. **Clone the template:**
   - Right-click template � Clone
   - Choose "Full Clone" (not Linked Clone)
   - Set new VM ID and name

2. **Configure cloud-init for the VM:**
   - Navigate to VM � Cloud-Init tab
   - Customize settings for this specific VM:
     - Hostname
     - SSH keys
     - Network configuration (IP/CIDR, Gateway, DNS)
     - User credentials
   - Click "Regenerate Image"

3. **Start the VM:**
   - Cloud-init will run on first boot
   - SSH keys will be generated
   - User account will be created
   - Network will be configured

4. **Access the VM:**
   ```bash
   ssh ubuntu@<vm-ip>
   ```

#### Cloud-Init Features

The template is configured to support:

- **User Management:** Automatic user creation with SSH keys
- **Network Configuration:** Static IP or DHCP via Proxmox GUI
- **SSH Access:** Automatic SSH key deployment
- **Hostname Management:** Set hostname via cloud-init
- **Package Installation:** Install packages on first boot
- **Script Execution:** Run custom scripts via user-data
- **File Injection:** Add files during provisioning

#### Advanced Customization

**Custom cloud-init user-data:**

You can add custom user-data via Proxmox:

1. Create a user-data file:
   ```yaml
   #cloud-config
   packages:
     - docker.io
     - git

   runcmd:
     - systemctl enable docker
     - systemctl start docker

   write_files:
     - path: /etc/motd
       content: |
         Welcome to My Custom VM
   ```

2. Add to VM via Proxmox CLI:
   ```bash
   qm set <VMID> --cicustom "user=local:snippets/user-data.yml"
   ```

#### Template Information File

After running the script, a comprehensive info file is created at:
```
/root/TEMPLATE_INFO.txt
```

This file contains:
- OS version and kernel information
- Installed components list
- Step-by-step instructions for templating
- Cloud-init configuration details
- Network and SSH information
- Maintenance instructions
- Verification commands

#### Verification

After booting a VM from the template, verify cloud-init ran successfully:

```bash
# Check cloud-init status
sudo cloud-init status

# View cloud-init output
sudo cloud-init query -a

# Check cloud-init logs
sudo cat /var/log/cloud-init.log
sudo cat /var/log/cloud-init-output.log

# Verify QEMU guest agent
sudo systemctl status qemu-guest-agent
```

#### Template Maintenance

**Updating the template:**

1. Clone the template to a new VM
2. Boot the VM
3. Apply updates:
   ```bash
   sudo apt update
   sudo apt upgrade -y
   sudo apt dist-upgrade -y
   ```
4. Make any configuration changes
5. Run the preparation script again:
   ```bash
   sudo ./prepare-template.sh
   ```
6. Shut down and convert to template
7. Test the new template
8. Delete or archive the old template

#### Common Use Cases

**1. Base Ubuntu Server Template:**
- Minimal installation with cloud-init
- Use for general-purpose servers

**2. Docker Host Template:**
- Base template + Docker pre-installed
- Modify script to install Docker before cleaning

**3. Development Environment Template:**
- Base template + dev tools (git, build-essential, etc.)
- Add tools installation before running script

**4. Application Server Template:**
- Base template + application runtime (Node.js, Python, etc.)
- Customize for specific application stacks

#### Troubleshooting

**Cloud-init not running:**
- Check cloud-init status: `cloud-init status`
- Review logs: `/var/log/cloud-init.log`
- Verify cloud-init is installed: `cloud-init --version`
- Regenerate cloud-init image in Proxmox GUI

**Network not configured:**
- Check cloud-init network config: `/etc/netplan/50-cloud-init.yaml`
- Verify Proxmox cloud-init network settings
- Check DHCP if using dynamic IP
- Review: `journalctl -u cloud-init`

**SSH keys not applied:**
- Verify SSH key is set in Proxmox cloud-init tab
- Check: `cat /home/ubuntu/.ssh/authorized_keys`
- Regenerate cloud-init image
- Check permissions on `.ssh` directory

**QEMU guest agent not working:**
- Check service: `systemctl status qemu-guest-agent`
- Enable QEMU agent in Proxmox VM options
- Restart VM after enabling

**Template too large:**
- Run the free space zeroing option
- Remove unnecessary packages before templating
- Use minimal Ubuntu Server installation
- Clean apt cache: `sudo apt clean`

#### Best Practices

1. **Start with minimal Ubuntu Server installation**
   - Fewer packages = smaller template = faster cloning

2. **Keep templates updated**
   - Regularly update and recreate templates
   - Version your templates (ubuntu-base-v1, v2, etc.)

3. **Use descriptive template names**
   - Include OS version: ubuntu-24.04-base
   - Include date: ubuntu-24.04-base-2024-01

4. **Test before deploying**
   - Clone and test template after creation
   - Verify all cloud-init features work

5. **Document customizations**
   - Keep notes on what's pre-installed
   - Document any configuration changes

6. **Use linked clones for testing**
   - Full clones for production
   - Linked clones for quick testing

7. **Backup templates**
   - Export templates to backup storage
   - Keep previous versions during updates

#### Security Considerations

**What's Removed:**
- SSH host keys (regenerated per VM)
- Machine ID (unique per VM)
- User bash history
- Log files containing system information
- Network interface persistence

**What's Configured:**
- Default user with sudo access
- SSH key-based authentication (password disabled by default)
- QEMU guest agent for Proxmox management
- Cloud-init for secure provisioning

**Recommendations:**
- Always set SSH keys via cloud-init
- Use strong passwords if enabling password auth
- Keep templates private (contain base configuration)
- Audit cloud-init user-data for secrets
- Use Proxmox access controls for template management

#### File Locations

**Created/Modified by script:**
- `/etc/cloud/cloud.cfg.d/99-pve.cfg` - Cloud-init Proxmox config
- `/etc/netplan/00-installer-config.yaml` - Basic network config
- `/root/TEMPLATE_INFO.txt` - Template documentation
- `/root/netplan-backup/` - Backup of original netplan configs

**Important cloud-init files:**
- `/var/lib/cloud/` - Cloud-init state (cleaned by script)
- `/etc/cloud/cloud.cfg` - Main cloud-init config
- `/etc/cloud/cloud.cfg.d/` - Cloud-init config drop-ins

**Logs (after VM boot from template):**
- `/var/log/cloud-init.log` - Cloud-init execution log
- `/var/log/cloud-init-output.log` - Script output log

---

## Contributing

To add new scripts to this directory:

1. **Create the script:**
   - Use descriptive filename
   - Add shebang line (`#!/bin/bash`)
   - Include header with purpose and usage
   - Make executable (`chmod +x`)

2. **Update README:**
   - Add script to list
   - Document purpose and usage
   - Include examples and troubleshooting

3. **Test thoroughly:**
   - Test on fresh Ubuntu installation
   - Verify all features work
   - Document any dependencies

---

## References

- [Cloud-Init Documentation](https://cloudinit.readthedocs.io/)
- [Proxmox Cloud-Init Support](https://pve.proxmox.com/wiki/Cloud-Init_Support)
- [Ubuntu Server Guide](https://ubuntu.com/server/docs)
- [QEMU Guest Agent](https://pve.proxmox.com/wiki/Qemu-guest-agent)

---

## Future Scripts

Planned additions to this directory:
- System hardening script
- Automated backup configuration
- Monitoring agent installation
- Security updates automation
- Log rotation configuration
- Performance tuning scripts