# TacticalRMM Modular Installation

This directory contains a modular installation system for TacticalRMM on Ubuntu 24.04 LTS. The installation has been broken down into individual scripts for each service, making it easier to troubleshoot, maintain, and customize.

## Overview

TacticalRMM is a comprehensive RMM solution that provides:
- Remote desktop and shell access via MeshCentral integration
- Agent-based monitoring for Windows, Linux, and macOS
- Automated task scheduling and scripting
- Patch management
- Alerting and reporting
- Multi-tenant support

## Directory Structure

```
tacticalrmm/
├── config.env                          # Main configuration file
├── .secrets.env                        # Auto-generated secrets (do not commit!)
├── deploy.sh                           # Master deployment script
├── install-tactical-rmm.sh             # Original monolithic script (legacy)
├── lib/
│   └── common.sh                       # Shared utilities and functions
├── install/
│   ├── 01-system-prerequisites.sh      # System updates and base packages
│   ├── 02-postgresql.sh                # PostgreSQL database setup
│   ├── 03-redis.sh                     # Redis cache setup
│   ├── 04-nginx.sh                     # Nginx web server installation
│   ├── 05-nodejs.sh                    # Node.js runtime installation
│   ├── 06-python.sh                    # Python environment setup
│   ├── 07-meshcentral.sh               # MeshCentral remote access
│   ├── 08-tacticalrmm-backend.sh       # TacticalRMM Django backend
│   ├── 09-systemd-services.sh          # Systemd service configuration
│   ├── 10-frontend.sh                  # Vue.js frontend build
│   ├── 11-nginx-config.sh              # Nginx reverse proxy config
│   └── 12-firewall.sh                  # UFW firewall setup
└── logs/                               # Individual service logs (auto-created)
```

## Quick Start

### 1. Configure Installation

Edit [config.env](config.env) to customize your installation:

```bash
# Domain Configuration
DOMAIN="tacticalrmm.hoyt.local"
API_DOMAIN="api.tacticalrmm.hoyt.local"
MESH_DOMAIN="mesh.tacticalrmm.hoyt.local"
RMM_DOMAIN="rmm.tacticalrmm.hoyt.local"

# Installation Paths
INSTALL_DIR="/rmm"
MESHCENTRAL_DIR="/meshcentral"

# See config.env for all available options
```

**Note:** Passwords and secrets are automatically generated and stored in `.secrets.env`. You don't need to set them manually unless you have specific requirements.

### 2. Run Full Deployment

To install everything:

```bash
sudo ./deploy.sh
```

The master script will:
- Run all installation scripts in sequence
- Log each service's output to `logs/`
- Display a summary of results
- Save credentials to `installation-credentials.txt`

### 3. Post-Installation

After deployment, you need to install SSL certificates:

```bash
# Copy wildcard certificates
cp /path/to/wildcard.crt /etc/nginx/ssl/wildcard.crt
cp /path/to/wildcard.key /etc/nginx/ssl/wildcard.key
chmod 644 /etc/nginx/ssl/wildcard.crt
chmod 600 /etc/nginx/ssl/wildcard.key

# Start nginx
systemctl start nginx

# Access TacticalRMM
# URL: https://rmm.tacticalrmm.hoyt.local
```

## Manual Installation

You can run individual scripts for troubleshooting or partial installations:

```bash
# Example: Only install PostgreSQL
sudo ./install/02-postgresql.sh

# Example: Re-run frontend build
sudo ./install/10-frontend.sh

# Example: Update Nginx configuration
sudo ./install/11-nginx-config.sh
```

Each script:
- Sources the common library for logging and utilities
- Loads configuration from [config.env](config.env)
- Can be run independently (with proper dependencies)
- Logs to both console and main log file

## Configuration Details

### config.env

Main configuration file with all installation parameters:
- Domain names
- Installation paths
- Service ports
- Feature toggles (e.g., QEMU agent)

### .secrets.env

Auto-generated file containing:
- PostgreSQL password
- Redis password
- Admin password
- MeshCentral token
- Django secret key

**Security:** This file is created with `chmod 600` and should never be committed to version control.

## Logging

### Main Log
- File: `/var/log/tacticalrmm-install.log`
- Contains: All installation output with timestamps

### Service Logs
- Directory: `./logs/`
- Files: `<script-name>.log`, `<script-name>.status`, `<script-name>.duration`
- Purpose: Individual script outputs for troubleshooting

### Service Status Logs
```bash
# View systemd service logs
journalctl -xeu tacticalrmm
journalctl -xeu celery
journalctl -xeu celerybeat
journalctl -xeu meshcentral
journalctl -xeu nginx
```

## Troubleshooting Modular Installation

### Check Service Status
```bash
systemctl status tacticalrmm celery celerybeat meshcentral nginx
```

### Review Installation Logs
```bash
# Main installation log
cat /var/log/tacticalrmm-install.log

# Individual service logs
ls -la ./logs/
cat ./logs/08-tacticalrmm-backend.sh.log
```

### Re-run Failed Services
If a specific service fails, you can re-run just that script:

```bash
# Example: PostgreSQL failed
sudo ./install/02-postgresql.sh

# Check the log
cat ./logs/02-postgresql.sh.log
```

### Common Issues

**PostgreSQL Connection Issues**
```bash
# Check PostgreSQL is running
systemctl status postgresql

# Test connection
sudo -u postgres psql -l

# Review PostgreSQL log
cat ./logs/02-postgresql.sh.log
```

**Frontend Build Failures**
```bash
# Check Node.js version
node --version  # Should be 20.x

# Re-run frontend build
sudo ./install/10-frontend.sh

# Review build log
cat ./logs/10-frontend.sh.log
```

**Nginx Won't Start**
```bash
# Verify certificates exist
ls -la /etc/nginx/ssl/

# Test nginx config
nginx -t

# Review nginx config log
cat ./logs/11-nginx-config.sh.log
```

## Benefits of Modular Design

1. **Easy Troubleshooting**: Each service has its own log file
2. **Selective Re-runs**: Re-run only failed services
3. **Customization**: Modify individual scripts without affecting others
4. **Maintenance**: Update specific services independently
5. **Testing**: Test services in isolation
6. **Clear Progress**: See exactly which service succeeded/failed

## Comparison with Original Script

### Original Script (install-tactical-rmm.sh)
- Single monolithic file (~880 lines)
- Hard to troubleshoot failures
- No per-service logging
- Inline configuration
- All-or-nothing installation

### New Modular System
- 12 focused scripts (30-150 lines each)
- Per-service logging and status tracking
- Centralized configuration
- Re-run individual services
- Better error isolation

---

## Legacy Installation Script

### Original Monolithic Script
**File:** `install-tactical-rmm.sh`

Complete automated installation script for TacticalRMM on Ubuntu 24.04 LTS.

#### What It Installs
- **PostgreSQL 16** - Primary database
- **Redis** - Cache and message broker with authentication
- **MeshCentral** - Remote access server for agent connectivity
- **TacticalRMM Backend** - Django/Python 3.12 API server
- **TacticalRMM Frontend** - Vue.js web interface
- **Nginx** - Reverse proxy and web server
- **UFW Firewall** - Configured with required ports
- **QEMU Guest Agent** - For Proxmox VM integration

#### Prerequisites
- Ubuntu 24.04 LTS (fresh installation recommended)
- Root access
- Recommended resources:
  - 8GB RAM (minimum 7GB)
  - 6 CPU cores (minimum 4)
  - 30GB storage (minimum 20GB)
- DNS records configured for:
  - `tacticalrmm.hoyt.local`
  - `api.tacticalrmm.hoyt.local`
  - `rmm.tacticalrmm.hoyt.local`
  - `mesh.tacticalrmm.hoyt.local`
- Wildcard SSL certificate for `*.hoyt.local` (from step-ca or other CA)

#### Usage
```bash
sudo ./install-tactical-rmm.sh
```

The script will:
1. Verify system requirements
2. Install all dependencies
3. Configure all services
4. Generate secure random passwords
5. Create systemd service files
6. Save credentials to `/root/tacticalrmm-credentials.txt`

#### Post-Installation Steps
After the script completes, you need to:

1. **Install SSL certificates:**
   ```bash
   cp /path/to/wildcard.crt /etc/nginx/ssl/wildcard.crt
   cp /path/to/wildcard.key /etc/nginx/ssl/wildcard.key
   chmod 644 /etc/nginx/ssl/wildcard.crt
   chmod 600 /etc/nginx/ssl/wildcard.key
   ```

2. **Start Nginx:**
   ```bash
   systemctl start nginx
   ```

3. **Access the web interface:**
   - Navigate to: `https://rmm.tacticalrmm.hoyt.local`
   - Login with credentials from `/root/tacticalrmm-credentials.txt`
   - Change the admin password immediately

4. **Verify installation:**
   ```bash
   ./verify-tacticalrmm.sh
   ```

#### Configuration
The script uses these default domains (modify in the script if needed):
- Main domain: `tacticalrmm.hoyt.local`
- API endpoint: `api.tacticalrmm.hoyt.local`
- Frontend: `rmm.tacticalrmm.hoyt.local`
- MeshCentral: `mesh.tacticalrmm.hoyt.local`

#### Generated Files
- `/root/tacticalrmm-credentials.txt` - All passwords and tokens (chmod 600)
- `/var/log/tacticalrmm-install.log` - Installation log
- `/rmm/api/tacticalrmm/tacticalrmm/local_settings.py` - Django configuration

---

### 2. Verification Script
**File:** `verify-tacticalrmm.sh`

Comprehensive verification script that checks all TacticalRMM components after installation.

#### What It Verifies

**System Requirements:**
- Ubuntu 24.04 LTS
- RAM, CPU cores, disk space

**User Accounts:**
- `tactical` user exists
- `meshcentral` user exists

**Directory Structure:**
- All required directories present
- Correct ownership

**Database & Cache:**
- PostgreSQL installed and running
- Database and user created
- Redis installed and running
- Redis authentication configured

**Python Environment:**
- Python 3.12 installed
- Virtual environment created
- Required packages (pip, gunicorn, celery)

**Node.js:**
- Node.js 20.x installed
- npm installed

**MeshCentral:**
- Installed and configured
- Service running and enabled
- Listening on port 4430

**TacticalRMM Backend:**
- Code directory exists
- Django settings configured
- Migrations applied
- Static files collected

**Frontend:**
- Built and deployed to `/var/www/rmm`
- Correct file ownership

**Nginx:**
- Installed and configured
- Configuration files present
- Sites enabled
- SSL certificates (warns if missing)
- Configuration validity

**Systemd Services:**
- All services exist and enabled:
  - postgresql
  - redis-server
  - meshcentral
  - tacticalrmm
  - celery
  - celerybeat
- Running status for each

**Network:**
- UFW firewall active
- Required ports allowed (22, 80, 443)
- Services listening on correct ports

**DNS:**
- All domains resolve properly

**Logs & Files:**
- Installation log exists
- Celery logs exist
- Credentials file exists with correct permissions

**Proxmox Integration:**
- QEMU Guest Agent installed (optional)

#### Usage
```bash
sudo ./verify-tacticalrmm.sh
```

#### Output
The script provides:
- Color-coded checks ( pass,  fail, � warning)
- Summary with total counts
- Detailed service status
- Actionable next steps
- Service error detection

#### Exit Codes
- Displays summary regardless of failures
- Shows specific failed checks for troubleshooting

---

## Architecture

### Service Stack
```
Internet
   �
Nginx (443/80) � SSL Termination
   �
