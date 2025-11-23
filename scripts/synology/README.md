# Synology NAS Scripts

Collection of scripts for Synology NAS systems.

## Scripts

### sync-scripts-repo.sh

Keeps a local folder synchronized with the scripts folder from the claudeai git repository.

**Features:**
- Clones the latest version of the scripts folder from the repository
- Uses rsync to efficiently update only changed files
- Automatically cleans up temporary files
- Color-coded output for easy monitoring

**Prerequisites:**
- Git must be installed on your Synology NAS (available in Package Center)
- rsync (usually pre-installed on Synology DSM)

**Configuration:**

Edit the script to set your desired target directory:
```bash
TARGET_DIR="/volume1/scripts"  # Modify this to your desired location
```

**Usage:**

1. Make the script executable:
   ```bash
   chmod +x sync-scripts-repo.sh
   ```

2. Run the script manually:
   ```bash
   ./sync-scripts-repo.sh
   ```

3. Set up as a scheduled task in Synology DSM (configured as "quick-sync"):
   - Open Control Panel > Task Scheduler
   - Create > Scheduled Task > User-defined script
   - Task name: `quick-sync`
   - Set the schedule (e.g., daily at 2:00 AM)
   - In the "Task Settings" tab, enter:
     ```bash
     bash /volume1/scripts/synology/sync-scripts-repo.sh
     ```

   **Note:** This scheduled task is already configured on the Synology NAS to keep scripts automatically synchronized.

**What it does:**
1. Clones the repository to a temporary directory
2. Extracts the scripts folder
3. Syncs it to your target directory using rsync
4. Removes any files in the target that no longer exist in the repository
5. Cleans up temporary files