# TacticalRMM Docker Installation

Docker-based deployment of TacticalRMM using Docker Compose. This provides a cleaner, more maintainable installation compared to bare metal deployment.

## Prerequisites

- Ubuntu 20.04 LTS or newer
- Docker Engine 20.10+
- Docker Compose v2.0+ (or docker-compose 1.29+)
- At least 4GB RAM
- At least 20GB free disk space
- Root or sudo access

## Quick Start

### 1. Install Docker (if not already installed)

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose (if using standalone version)
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
docker --version
docker compose version  # or docker-compose --version
```

### 2. Deploy TacticalRMM

```bash
cd docker-install
sudo bash deploy.sh
```

The deployment script will:
1. Check Docker installation
2. Generate secure passwords
3. Create `.env` configuration file
4. Set up SSL certificates (self-signed or use your own)
5. Build and start all services
6. Display access credentials

### 3. Access TacticalRMM

After deployment completes, access the web interface at:
- **Frontend**: `https://tacticalrmm.hoyt.local` (or your configured domain)
- **API**: `https://api.tacticalrmm.hoyt.local`
- **MeshCentral**: `https://mesh.tacticalrmm.hoyt.local`

## Manual Configuration

### Environment Variables

Copy the example environment file and customize:

```bash
cp .env.example .env
nano .env
```

Key variables to configure:
- `DOMAIN`: Your base domain
- `API_DOMAIN`, `MESH_DOMAIN`, `RMM_DOMAIN`: Service domains
- `POSTGRES_PASSWORD`: PostgreSQL password
- `REDIS_PASSWORD`: Redis password
- `DJANGO_SECRET`: Django secret key
- `ADMIN_PASSWORD`: Initial admin password

### SSL Certificates

#### Option 1: Self-Signed (Development/Testing)

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout ssl/cert.key \
    -out ssl/cert.crt \
    -subj "/C=US/ST=State/L=City/O=Org/CN=*.tacticalrmm.hoyt.local"
```

#### Option 2: Your Own Certificates (Production)

Place your wildcard certificate files:
```bash
cp /path/to/your/certificate.crt ssl/cert.crt
cp /path/to/your/private.key ssl/cert.key
chmod 644 ssl/cert.crt
chmod 600 ssl/cert.key
```

### DNS Configuration

Add DNS A records pointing to your server's IP:
```
tacticalrmm.hoyt.local      -> YOUR_SERVER_IP
api.tacticalrmm.hoyt.local  -> YOUR_SERVER_IP
mesh.tacticalrmm.hoyt.local -> YOUR_SERVER_IP
```

Or add to `/etc/hosts` for testing:
```bash
echo "YOUR_SERVER_IP tacticalrmm.hoyt.local api.tacticalrmm.hoyt.local mesh.tacticalrmm.hoyt.local" | sudo tee -a /etc/hosts
```

## Service Management

### Start Services

```bash
docker compose up -d
```

### Stop Services

```bash
docker compose down
```

### Restart a Service

```bash
docker compose restart tacticalrmm
docker compose restart celery
docker compose restart nginx
```

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f tacticalrmm
docker compose logs -f celery
docker compose logs -f nginx
```

### Check Service Status

```bash
docker compose ps
```

### Update TacticalRMM

```bash
# Pull latest changes
docker compose pull

# Rebuild custom images
docker compose build --no-cache

# Restart services
docker compose down
docker compose up -d
```

## Container Details

### Services

| Service | Container Name | Port | Description |
|---------|---------------|------|-------------|
| postgres | trmm-postgres | 5432 | PostgreSQL database |
| redis | trmm-redis | 6379 | Redis cache |
| meshcentral | trmm-mesh | 4430 | MeshCentral server |
| tacticalrmm | trmm-backend | 8000 | Django API backend |
| celery | trmm-celery | - | Celery worker |
| celerybeat | trmm-celerybeat | - | Celery beat scheduler |
| nginx | trmm-nginx | 80, 443 | Nginx reverse proxy |

### Volumes

| Volume | Purpose |
|--------|---------|
| postgres_data | PostgreSQL database files |
| redis_data | Redis persistence |
| meshcentral_data | MeshCentral configuration |
| meshcentral_files | MeshCentral uploaded files |
| tacticalrmm_data | TacticalRMM application data |
| static_files | Django static files |
| frontend_files | Vue.js frontend files |
| tacticalrmm_logs | Application logs |

## Troubleshooting

### Services won't start

Check logs for specific errors:
```bash
docker compose logs tacticalrmm
docker compose logs celery
```

### Database connection errors

Ensure PostgreSQL is healthy:
```bash
docker compose ps postgres
docker compose logs postgres
```

### Permission issues

Reset ownership of volumes:
```bash
docker compose down
docker volume ls
docker volume inspect tacticalrmm_data
```

### SSL certificate issues

Verify certificate files:
```bash
ls -la ssl/
openssl x509 -in ssl/cert.crt -text -noout
```

### Reset everything

**WARNING**: This will delete all data!
```bash
docker compose down -v
rm -rf ssl/* .env
```

## Backup and Restore

### Backup

```bash
# Create backup directory
mkdir -p backups/$(date +%Y%m%d)

# Backup database
docker compose exec postgres pg_dump -U tactical tacticalrmm > backups/$(date +%Y%m%d)/database.sql

# Backup volumes
docker run --rm -v tacticalrmm_tacticalrmm_data:/data -v $(pwd)/backups/$(date +%Y%m%d):/backup alpine tar czf /backup/tacticalrmm_data.tar.gz -C /data .

# Backup .env file
cp .env backups/$(date +%Y%m%d)/
```

### Restore

```bash
# Restore database
cat backups/YYYYMMDD/database.sql | docker compose exec -T postgres psql -U tactical tacticalrmm

# Restore volumes
docker run --rm -v tacticalrmm_tacticalrmm_data:/data -v $(pwd)/backups/YYYYMMDD:/backup alpine tar xzf /backup/tacticalrmm_data.tar.gz -C /data
```

## Security Considerations

1. **Change default passwords** immediately after installation
2. **Use proper SSL certificates** in production (not self-signed)
3. **Restrict network access** using firewall rules
4. **Regularly update** Docker images and TacticalRMM
5. **Backup regularly** using the backup procedures above
6. **Secure .env file**: `chmod 600 .env`

## Support

- TacticalRMM Documentation: https://docs.tacticalrmm.com/
- GitHub Issues: https://github.com/amidaware/tacticalrmm/issues
- Discord Community: https://discord.gg/upGTkWp

## License

TacticalRMM is licensed under the AGPLv3 license.
