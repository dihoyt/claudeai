# Synology NAS Scripts

Collection of scripts for Synology NAS systems to synchronize with the claudeai git repository.

## Prerequisites

- Git must be installed on your Synology NAS (available in Package Center)
- rsync (usually pre-installed on Synology DSM)

## Scripts

### setup-scripts-repo.sh

Initial setup script for configuring the scripts repository on your Synology NAS.

**Purpose:**
- First-time installation and configuration
- Sets up the target directory structure
- Performs initial repository clone and sync

**Usage:**

1. Make the script executable:
   ```bash
   chmod +x setup-scripts-repo.sh
   ```

2. Run the setup script once:
   ```bash
   ./setup-scripts-repo.sh
   ```

**Configuration:**

Edit the script to set your desired target directory:
```bash
TARGET_DIR="/volume1/scripts"  # Modify this to your desired location
```

**What it does:**
1. Creates the target directory if it doesn't exist
2. Clones the repository to a temporary directory
3. Extracts the scripts folder
4. Syncs it to your target directory using rsync
5. Sets up proper permissions
6. Cleans up temporary files

---

### quick-sync.sh

Quick synchronization script for scheduled tasks and regular updates.

**Purpose:**
- Lightweight sync for automated/scheduled execution
- Updates existing installation with latest changes
- Designed for cron jobs and Synology Task Scheduler

**Usage:**

Run manually for quick updates:
```bash
bash /volume1/scripts/synology/quick-sync.sh
```

**Scheduled Task Setup:**

Configure as a scheduled task in Synology DSM:
1. Open Control Panel > Task Scheduler
2. Create > Scheduled Task > User-defined script
3. Task name: `quick-sync`
4. Set the schedule (e.g., daily at 2:00 AM)
5. In the "Task Settings" tab, enter:
   ```bash
   bash /volume1/scripts/synology/quick-sync.sh
   ```

**Note:** This scheduled task is already configured on the Synology NAS to keep scripts automatically synchronized.

**What it does:**
1. Efficiently syncs only changed files from the repository
2. Removes files that no longer exist in the repository
3. Minimal overhead for automated execution
4. Color-coded output for easy monitoring

## Recommended Workflow

1. **Initial Setup:** Run `setup-scripts-repo.sh` once to set up the repository
2. **Ongoing Sync:** Use `quick-sync.sh` in a scheduled task for automatic updates
3. **Manual Updates:** Run `quick-sync.sh` anytime you need to pull latest changes
