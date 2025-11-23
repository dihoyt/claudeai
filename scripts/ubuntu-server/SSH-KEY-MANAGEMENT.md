# SSH Key Management Guide

A comprehensive guide to managing SSH keys across multiple VMs and environments.

## The Problem

When managing multiple VMs, SSH key sprawl becomes a nightmare:
- Keys scattered across different VMs
- Hard to revoke access when keys are compromised
- Difficult to track which keys have access where
- No central management
- Keys stored on GitHub, local machines, and various VMs

## Recommended Solutions

### Solution 1: GitHub SSH Key Import (Recommended for Most Users)

**Best for:** Teams, developers already using GitHub, centralized key management

#### How It Works
Cloud-init can automatically fetch your public SSH keys from GitHub and add them to new VMs.

#### Setup

1. **Ensure your SSH keys are on GitHub:**
   - Go to: https://github.com/settings/keys
   - Add your public keys there
   - These are publicly accessible at: `https://github.com/YOUR_USERNAME.keys`

2. **Modify the template preparation script:**

   Edit `/etc/cloud/cloud.cfg.d/99-pve.cfg` before running the template script, or after:

   ```yaml
   system_info:
     default_user:
       name: ubuntu
       ssh_import_id: [gh:YOUR_GITHUB_USERNAME]
       # ... rest of config
   ```

3. **Or set it in Proxmox per-VM:**

   Create a cloud-init user-data snippet in Proxmox:

   ```yaml
   #cloud-config
   ssh_import_id:
     - gh:YOUR_GITHUB_USERNAME
   ```

#### Advantages
- ✅ Centralized key management on GitHub
- ✅ Easy to add/remove keys (update GitHub, not each VM)
- ✅ Publicly accessible (your public keys are public anyway)
- ✅ Works automatically with cloud-init
- ✅ No secrets to manage
- ✅ Audit trail on GitHub

#### Testing
```bash
# See what keys would be imported
curl https://github.com/YOUR_USERNAME.keys

# On a VM, manually import (to test)
ssh-import-id gh:YOUR_USERNAME
```

---

### Solution 2: Centralized Key Management Server

**Best for:** Large deployments, enterprises, strict security requirements

Use a dedicated secrets management solution:

#### Option A: HashiCorp Vault
- Store SSH keys in Vault
- Dynamic SSH credentials
- Automatic key rotation
- Audit logging
- One-time SSH passwords

#### Option B: ssh-ca (SSH Certificate Authority)
- Issue SSH certificates instead of keys
- Short-lived credentials
- Centralized revocation
- No need to distribute keys

#### Option C: LDAP/Active Directory
- Store SSH keys in LDAP/AD
- Use sssd to sync keys to VMs
- Centralized user management

---

### Solution 3: Configuration Management

**Best for:** Infrastructure as Code approach, automated deployments

Use tools like Ansible, Puppet, Chef, or SaltStack:

#### Ansible Example

```yaml
# playbook.yml
---
- hosts: all
  tasks:
    - name: Ensure authorized keys
      authorized_key:
        user: ubuntu
        state: present
        key: "{{ lookup('file', '~/.ssh/id_rsa.pub') }}"
```

Run across all VMs:
```bash
ansible-playbook -i inventory.ini playbook.yml
```

#### Advantages
- ✅ Version controlled key distribution
- ✅ Automated and repeatable
- ✅ Can manage other configurations too
- ✅ Audit trail via Git

---

### Solution 4: Simple Centralized Key Repository

**Best for:** Small teams, simple setups, quick solution

Create a Git repository for SSH keys:

```bash
# Create keys repo
mkdir ssh-keys
cd ssh-keys
git init

# Add keys
cat ~/.ssh/id_rsa.pub > authorized_keys
git add authorized_keys
git commit -m "Add team SSH keys"
git push

# On new VMs, fetch keys
curl https://raw.githubusercontent.com/yourorg/ssh-keys/main/authorized_keys \
  >> ~/.ssh/authorized_keys
```

Or use a simple web server:
```bash
# On a central server
cat team_keys.pub | ssh user@vm "cat >> ~/.ssh/authorized_keys"
```

---

## Best Practices for SSH Key Management

### 1. Key Hygiene

**One Key Per Machine/Purpose:**
```bash
# Work laptop
ssh-keygen -t ed25519 -f ~/.ssh/id_work -C "work-laptop"

# Home desktop
ssh-keygen -t ed25519 -f ~/.ssh/id_home -C "home-desktop"

# CI/CD
ssh-keygen -t ed25519 -f ~/.ssh/id_cicd -C "cicd-automation"
```

**Use SSH Config:**
```bash
# ~/.ssh/config
Host *.hoyt.local
    User ubuntu
    IdentityFile ~/.ssh/id_work
    IdentitiesOnly yes

Host github.com
    IdentityFile ~/.ssh/id_github
    IdentitiesOnly yes

Host production-*
    IdentityFile ~/.ssh/id_production
    IdentitiesOnly yes
```

### 2. Key Types

**Recommended (2024):**
```bash
# ED25519 (best choice)
ssh-keygen -t ed25519 -C "your-comment"

# RSA 4096 (if ED25519 not supported)
ssh-keygen -t rsa -b 4096 -C "your-comment"
```

**Avoid:**
- RSA keys < 2048 bits
- DSA keys (deprecated)
- ECDSA keys (unless required)

### 3. Key Rotation

**Rotate keys regularly:**
```bash
# Generate new key
ssh-keygen -t ed25519 -f ~/.ssh/id_new

# Add new key to authorized sources (GitHub, etc.)
# Test access with new key
ssh -i ~/.ssh/id_new user@host

# Once verified, remove old key from:
# - GitHub/GitLab
# - authorized_keys files
# - Your local machine
```

### 4. Passphrase Protection

**Always use passphrases:**
```bash
# Generate with passphrase
ssh-keygen -t ed25519 -C "your-comment"
# Enter passphrase when prompted

# Use ssh-agent to avoid typing repeatedly
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

### 5. Key Auditing

**Track where your keys are used:**

Create a key inventory:
```bash
# keys-inventory.md
| Key Name | Fingerprint | Location | Purpose | Created | Expires |
|----------|-------------|----------|---------|---------|---------|
| id_work  | SHA256:abc... | GitHub, all VMs | Work access | 2024-01 | 2025-01 |
| id_home  | SHA256:def... | Personal VMs | Home lab | 2024-01 | 2025-01 |
```

**Check key fingerprints:**
```bash
# Local key fingerprint
ssh-keygen -lf ~/.ssh/id_ed25519.pub

# Remote authorized_keys
ssh user@host "ssh-keygen -lf ~/.ssh/authorized_keys"

# GitHub keys
curl https://github.com/USERNAME.keys | ssh-keygen -lf -
```

---

## Recommended Setup for Proxmox + Cloud-Init

### Approach: GitHub + Proxmox Template

**Step 1: Consolidate Your Keys on GitHub**

1. Gather all your public keys from various machines:
   ```bash
   cat ~/.ssh/id_*.pub
   ```

2. Add them all to GitHub:
   - Visit: https://github.com/settings/keys
   - Click "New SSH key"
   - Add each key with descriptive names

3. Verify:
   ```bash
   curl https://github.com/YOUR_USERNAME.keys
   ```

**Step 2: Configure Template**

Edit the template script's cloud-init config:

```bash
sudo nano /etc/cloud/cloud.cfg.d/99-pve.cfg
```

Add your GitHub username:
```yaml
system_info:
  default_user:
    name: ubuntu
    ssh_import_id: [gh:YOUR_GITHUB_USERNAME]
    # ... rest stays the same
```

**Step 3: Run Template Preparation**

```bash
sudo ./prepare-template.sh
```

**Step 4: Convert to Template**

```bash
shutdown -h now
# In Proxmox:
qm template <VMID>
```

**Step 5: Use It**

Every VM cloned from this template will automatically:
1. Fetch your SSH keys from GitHub on first boot
2. Add them to the ubuntu user's authorized_keys
3. Be immediately accessible via SSH (no console needed!)

---

## Migration Plan: Cleaning Up Existing Keys

### Phase 1: Inventory (Week 1)

1. **List all your current keys:**
   ```bash
   ls -la ~/.ssh/id_*
   ssh-keygen -lf ~/.ssh/id_rsa.pub  # For each key
   ```

2. **Document where each is used:**
   - Which VMs have which keys?
   - Which services (GitHub, GitLab, servers)?
   - Which are still needed?

### Phase 2: Consolidation (Week 2)

1. **Create new master keys:**
   ```bash
   # Primary key (daily use)
   ssh-keygen -t ed25519 -f ~/.ssh/id_primary -C "primary-$(date +%Y)"

   # Backup key (emergency access)
   ssh-keygen -t ed25519 -f ~/.ssh/id_backup -C "backup-$(date +%Y)"
   ```

2. **Add to GitHub:**
   - Add both keys to GitHub
   - Use descriptive names

3. **Update SSH config:**
   ```bash
   cat >> ~/.ssh/config <<EOF
   Host *.hoyt.local
       User ubuntu
       IdentityFile ~/.ssh/id_primary
       IdentitiesOnly yes
   EOF
   ```

### Phase 3: Deployment (Week 3)

1. **Deploy new keys to all VMs:**

   Option A - Manual:
   ```bash
   for vm in vm1 vm2 vm3; do
     ssh-copy-id -i ~/.ssh/id_primary ubuntu@$vm
   done
   ```

   Option B - Ansible:
   ```yaml
   - hosts: all
     tasks:
       - authorized_key:
           user: ubuntu
           key: "{{ lookup('file', '~/.ssh/id_primary.pub') }}"
   ```

2. **Test new keys:**
   ```bash
   ssh -i ~/.ssh/id_primary ubuntu@test-vm
   ```

### Phase 4: Verification & Cleanup (Week 4)

1. **Verify new keys work everywhere:**
   ```bash
   # Test each VM
   ssh ubuntu@vm1 "echo 'Connected successfully'"
   ```

2. **Remove old keys from VMs:**
   ```bash
   # On each VM
   # Backup first!
   cp ~/.ssh/authorized_keys ~/.ssh/authorized_keys.backup

   # Edit to keep only new keys
   nano ~/.ssh/authorized_keys
   ```

3. **Remove old keys from GitHub:**
   - Visit: https://github.com/settings/keys
   - Delete old keys

4. **Archive old local keys:**
   ```bash
   mkdir ~/.ssh/archive
   mv ~/.ssh/id_old* ~/.ssh/archive/
   ```

---

## Quick Reference

### Adding GitHub Keys to Existing VM

```bash
# One-time manual import
ssh-import-id gh:YOUR_GITHUB_USERNAME

# Or via cloud-init user-data
#cloud-config
ssh_import_id:
  - gh:YOUR_GITHUB_USERNAME
```

### Adding Keys via Proxmox GUI

1. VM → Cloud-Init tab
2. Paste your public key in "SSH public key" field
3. Click "Regenerate Image"
4. Start VM

### Emergency Access (Lost Keys)

1. Use Proxmox console (VNC/SPICE)
2. Login with password (if enabled)
3. Add new key:
   ```bash
   echo "ssh-ed25519 AAAAC3... comment" >> ~/.ssh/authorized_keys
   ```

### Revoking Access

**From GitHub:**
1. Delete key from GitHub settings
2. VMs will still have old keys in authorized_keys

**From VMs:**
```bash
# Remove specific key
ssh user@vm "sed -i '/SPECIFIC_KEY_PART/d' ~/.ssh/authorized_keys"

# Or re-import from GitHub (if removed there)
ssh user@vm "rm ~/.ssh/authorized_keys && ssh-import-id gh:USERNAME"
```

---

## Security Considerations

### DO:
- ✅ Use ED25519 keys (or RSA 4096)
- ✅ Protect private keys with passphrases
- ✅ Use ssh-agent for passphrase caching
- ✅ Rotate keys annually
- ✅ Use different keys for different security zones
- ✅ Keep private keys on encrypted storage
- ✅ Maintain key inventory
- ✅ Use GitHub/centralized management

### DON'T:
- ❌ Share private keys between machines
- ❌ Store private keys on servers
- ❌ Use keys without passphrases for critical systems
- ❌ Commit private keys to Git
- ❌ Use same key for everything
- ❌ Ignore key rotation
- ❌ Keep old keys indefinitely

---

## Tools & Scripts

### Key Distribution Script

```bash
#!/bin/bash
# distribute-keys.sh - Deploy SSH keys to multiple hosts

HOSTS_FILE="hosts.txt"  # One hostname per line
KEY_FILE="$HOME/.ssh/id_primary.pub"

while IFS= read -r host; do
    echo "Deploying key to $host..."
    ssh-copy-id -i "$KEY_FILE" "ubuntu@$host"
done < "$HOSTS_FILE"
```

### Key Audit Script

```bash
#!/bin/bash
# audit-keys.sh - Check which keys are on which hosts

HOSTS_FILE="hosts.txt"

while IFS= read -r host; do
    echo "=== $host ==="
    ssh "ubuntu@$host" "cat ~/.ssh/authorized_keys | ssh-keygen -lf -" 2>/dev/null || echo "Failed to connect"
    echo ""
done < "$HOSTS_FILE"
```

### Key Cleanup Script

```bash
#!/bin/bash
# cleanup-keys.sh - Remove old keys from VMs

HOSTS_FILE="hosts.txt"
OLD_KEY_FINGERPRINT="SHA256:abc123..."

while IFS= read -r host; do
    echo "Cleaning $host..."
    ssh "ubuntu@$host" "sed -i.backup '/$OLD_KEY_FINGERPRINT/d' ~/.ssh/authorized_keys"
done < "$HOSTS_FILE"
```

---

## Troubleshooting

### SSH not working after cloud-init

```bash
# Check cloud-init status
sudo cloud-init status

# Check cloud-init logs
sudo cat /var/log/cloud-init.log | grep -i ssh

# Check authorized_keys
cat ~/.ssh/authorized_keys

# Manually import from GitHub
ssh-import-id gh:YOUR_USERNAME
```

### Wrong permissions

```bash
# Fix SSH directory permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

### Keys on GitHub not importing

```bash
# Test GitHub access
curl https://github.com/YOUR_USERNAME.keys

# Check cloud-init config
sudo cat /etc/cloud/cloud.cfg.d/99-pve.cfg | grep ssh_import_id

# Manually trigger import
sudo cloud-init clean
sudo cloud-init init
```

---

## Additional Resources

- [GitHub SSH Key Documentation](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)
- [Cloud-Init SSH Module](https://cloudinit.readthedocs.io/en/latest/reference/modules.html#ssh)
- [ssh-import-id Man Page](https://manpages.ubuntu.com/manpages/jammy/man1/ssh-import-id.1.html)
- [SSH Best Practices (Mozilla)](https://infosec.mozilla.org/guidelines/openssh)
- [NIST SSH Guidelines](https://nvlpubs.nist.gov/nistpubs/ir/2015/NIST.IR.7966.pdf)