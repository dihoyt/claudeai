#!/bin/bash
# Install Docker and Portainer Agent on a Docker host

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

scriptdir="/scripts"
# Create script directory and log file
mkdir -p $scriptdir
logfile="$scriptdir/logs.txt"
# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$logfile"
}

log "========================================="
log "Starting Docker Agent Installation"
log "========================================="

log "Creating script directory: $scriptdir"
mkdir -p $scriptdir

log "Downloading Docker installation script..."
curl -fsSL https://get.docker.com -o $scriptdir/get-docker.sh

log "Setting execute permissions on get-docker.sh"
chmod +x $scriptdir/get-docker.sh

log "Running Docker installation script..."
$scriptdir/get-docker.sh 2>&1 | tee -a "$logfile"

log "Enabling Docker service..."
systemctl enable docker 2>&1 | tee -a "$logfile"

log "Starting Docker service..."
systemctl start docker 2>&1 | tee -a "$logfile"

log "Deploying Portainer Agent container..."
docker run -d -p 9001:9001 --name portainer_agent --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/docker/volumes:/var/lib/docker/volumes portainer/agent:latest 2>&1 | tee -a "$logfile"

log "Configuring firewall rules for Docker Swarm..."
# Allow Swarm ports
log "Allowing port 2377/tcp (Cluster management)"
ufw allow 2377/tcp 2>&1 | tee -a "$logfile"

log "Allowing port 7946/tcp (Node communication)"
ufw allow 7946/tcp 2>&1 | tee -a "$logfile"

log "Allowing port 7946/udp (Node communication)"
ufw allow 7946/udp 2>&1 | tee -a "$logfile"

log "Allowing port 4789/udp (Overlay network traffic)"
ufw allow 4789/udp 2>&1 | tee -a "$logfile"

log "Allowing port 22/tcp (SSH)"
ufw allow 22/tcp 2>&1 | tee -a "$logfile"

log "Installing monitoring tools (iotop, iftop, nethogs)..."
apt install -y iotop iftop nethogs 2>&1 | tee -a "$logfile"

log "========================================="
log "Docker Agent Installation Complete!"
log "Log file: $logfile"
log "========================================="