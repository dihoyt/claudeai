# Docker Hosts Setup Scripts

This folder contains scripts for setting up Docker hosts and a Docker Swarm cluster with Portainer management.

## Scripts

### `docker-swarm-manager.sh`
Installs Docker and Portainer Server on the Docker Swarm manager node.

**What it does:**
- Installs Docker Engine
- Configures firewall rules for Docker Swarm
- Deploys Portainer Server (web UI for managing the cluster)
- Opens ports for Portainer UI (9000, 9443, 8000)
- Installs monitoring tools (iotop, iftop, nethogs)
- Logs all actions to `/scripts/logs.txt`

**Usage:**
```bash
sudo ./docker-swarm-manager.sh
```

**After installation:**
1. Initialize Docker Swarm:
   ```bash
   docker swarm init --advertise-addr <MANAGER_IP>
   ```
2. Save the join token that's displayed
3. Access Portainer at `http://<MANAGER_IP>:9000` or `https://<MANAGER_IP>:9443`
4. Create your admin account in Portainer

### `docker-agent-install.sh`
Installs Docker and Portainer Agent on Docker Swarm worker nodes.

**What it does:**
- Installs Docker Engine
- Configures firewall rules for Docker Swarm
- Deploys Portainer Agent (communicates with Portainer Server)
- Opens port 9001 for agent communication
- Installs monitoring tools (iotop, iftop, nethogs)
- Logs all actions to `/scripts/logs.txt`

**Usage:**
```bash
sudo ./docker-agent-install.sh
```

**After installation:**
1. Join the worker to the swarm using the token from the manager:
   ```bash
   docker swarm join --token <WORKER_TOKEN> <MANAGER_IP>:2377
   ```
2. The agent will automatically be discovered by Portainer

## Docker Swarm Architecture

```
┌─────────────────────────────────────┐
│   Docker Swarm Manager              │
│   - Portainer Server (UI)           │
│   - Manages cluster                 │
│   - Accessible on :9000/:9443       │
└─────────────────────────────────────┘
                 │
    ┌────────────┼────────────┐
    │            │            │
┌───▼────┐  ┌───▼────┐  ┌───▼────┐
│Worker 1│  │Worker 2│  │Worker 3│
│Agent   │  │Agent   │  │Agent   │
│:9001   │  │:9001   │  │:9001   │
└────────┘  └────────┘  └────────┘
```

## Firewall Ports

### Manager Node
- `2377/tcp` - Cluster management communications
- `7946/tcp` - Node communication
- `7946/udp` - Node communication
- `4789/udp` - Overlay network traffic
- `9000/tcp` - Portainer HTTP UI
- `9443/tcp` - Portainer HTTPS UI
- `8000/tcp` - Portainer Edge Agent
- `22/tcp` - SSH

### Worker Nodes
- `2377/tcp` - Cluster management communications
- `7946/tcp` - Node communication
- `7946/udp` - Node communication
- `4789/udp` - Overlay network traffic
- `9001/tcp` - Portainer Agent
- `22/tcp` - SSH

## Quick Start Guide

### 1. Prepare VMs
Clone your Ubuntu template to create:
- 1 manager node (e.g., `docker-00`)
- 1+ worker nodes (e.g., `docker-01`, `docker-02`)

### 2. Setup Manager Node
```bash
# Copy script to manager
scp docker-swarm-manager.sh root@docker-00:/tmp/

# SSH to manager
ssh root@docker-00

# Run the script
cd /tmp
chmod +x docker-swarm-manager.sh
sudo ./docker-swarm-manager.sh

# Initialize swarm
docker swarm init --advertise-addr <MANAGER_IP>

# Save the worker join token
docker swarm join-token worker
```

### 3. Setup Worker Nodes
```bash
# Copy script to worker
scp docker-agent-install.sh root@docker-01:/tmp/

# SSH to worker
ssh root@docker-01

# Run the script
cd /tmp
chmod +x docker-agent-install.sh
sudo ./docker-agent-install.sh

# Join the swarm (use token from step 2)
docker swarm join --token <WORKER_TOKEN> <MANAGER_IP>:2377
```

### 4. Access Portainer
1. Open browser to `http://<MANAGER_IP>:9000`
2. Create admin account
3. Select "Get Started" to manage the local environment
4. View all swarm nodes under **Swarm** → **Nodes**

## Logs

All installation logs are saved to `/scripts/logs.txt` on each host with timestamps.

To view logs:
```bash
tail -f /scripts/logs.txt
```

## Monitoring Tools Included

- **iotop** - Monitor disk I/O per process
- **iftop** - Monitor network bandwidth
- **nethogs** - Monitor network usage per process

## Notes

- Scripts require root privileges (use `sudo`)
- Both scripts are idempotent-safe for Docker installation
- UFW firewall is configured automatically
- Portainer data is stored in a Docker volume (`portainer_data`)
- All containers are set to restart automatically

## Troubleshooting

### Check Docker status
```bash
systemctl status docker
docker info
```

### Check Swarm status
```bash
docker node ls  # On manager
docker info | grep Swarm  # On any node
```

### Check Portainer logs
```bash
docker logs portainer  # On manager
docker logs portainer_agent  # On worker
```

### Get join tokens again
```bash
docker swarm join-token worker  # For workers
docker swarm join-token manager  # For additional managers
```

## Template Preparation

Before creating a VM template for Docker hosts, consider:

**Include in template:**
- Basic utilities (vim, curl, git, net-tools)
- QEMU Guest Agent (for Proxmox IP display)
- Cloud-init (for hostname/network auto-config)

**Do NOT include in template:**
- Docker installation (use these scripts instead)
- Docker Swarm initialization
- Static IP configuration
- Specific hostname

This keeps the template flexible for both Docker and non-Docker VMs.
