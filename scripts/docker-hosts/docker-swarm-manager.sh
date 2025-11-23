#!/bin/bash
# Install Docker and Portainer Server on a Docker Swarm Manager

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
log "Starting Docker Swarm Manager Installation"
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

log "Allowing port 9000/tcp (Portainer UI)"
ufw allow 9000/tcp 2>&1 | tee -a "$logfile"

log "Allowing port 9443/tcp (Portainer UI HTTPS)"
ufw allow 9443/tcp 2>&1 | tee -a "$logfile"

log "Allowing port 8000/tcp (Portainer Edge Agent)"
ufw allow 8000/tcp 2>&1 | tee -a "$logfile"

log "Installing monitoring tools (iotop, iftop, nethogs)..."
apt install -y iotop iftop nethogs 2>&1 | tee -a "$logfile"

log "Creating Portainer data volume..."
docker volume create portainer_data 2>&1 | tee -a "$logfile"

log "Deploying Portainer Server container..."
docker run -d \
  -p 8000:8000 \
  -p 9443:9443 \
  -p 9000:9000 \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest 2>&1 | tee -a "$logfile"

log "========================================="
log "Docker Swarm Manager Installation Complete!"
log ""
log "NEXT STEPS:"
log "1. Initialize Docker Swarm: docker swarm init --advertise-addr <MANAGER_IP>"
log "2. Access Portainer at: http://<MANAGER_IP>:9000 or https://<MANAGER_IP>:9443"
log "3. On worker nodes, run docker-agent-install.sh"
log "4. Join workers using: docker swarm join --token <TOKEN> <MANAGER_IP>:2377"
log ""
log "Log file: $logfile"
log "========================================="
