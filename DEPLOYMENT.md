# Deployment Guide - Kamal 2 + Docker

This guide covers deploying the STEM App to a VPS using Kamal 2 and Docker.

## Architecture Overview

- **Web Server**: Thruster (HTTP/2 proxy for Puma)
- **Application Server**: Puma with Solid Queue plugin
- **Database**: PostgreSQL 16 (4 databases: main, cache, queue, cable)
- **Background Jobs**: Solid Queue (PostgreSQL-backed, runs inside Puma)
- **WebSockets**: Solid Cable (PostgreSQL-backed)
- **Cache**: Solid Cache (PostgreSQL-backed)
- **Reverse Proxy**: Traefik with automatic SSL via Let's Encrypt
- **File Storage**: Local disk storage (volume mounted)

## Prerequisites

### 1. VPS Requirements

- Ubuntu 20.04+ or Debian 11+ (recommended)
- At least 2GB RAM (4GB+ recommended for audio processing)
- 20GB+ disk space
- SSH access with sudo privileges
- Public IP address

### 2. Domain Setup

- A domain name pointing to your VPS IP address
- DNS A record: `yourdomain.com` → `your.vps.ip.address`

### 3. Local Requirements

- Docker installed locally (for building images)
- Ruby 3.4.5 installed
- Kamal 2 gem installed: `gem install kamal`

### 4. Docker Registry

Choose one of the following:

**Option A: GitHub Container Registry (ghcr.io)** - Recommended
- Create a GitHub Personal Access Token with `write:packages` permission
- Token URL: https://github.com/settings/tokens

**Option B: Docker Hub**
- Create a Docker Hub account and access token
- Token URL: https://hub.docker.com/settings/security

## Initial Setup

### Step 1: Prepare Your VPS

SSH into your VPS and create a deploy user:

```bash
# Create deploy user
sudo adduser deploy
sudo usermod -aG sudo deploy
sudo usermod -aG docker deploy

# Set up SSH key authentication for the deploy user
sudo mkdir -p /home/deploy/.ssh
sudo cp ~/.ssh/authorized_keys /home/deploy/.ssh/
sudo chown -R deploy:deploy /home/deploy/.ssh
sudo chmod 700 /home/deploy/.ssh
sudo chmod 600 /home/deploy/.ssh/authorized_keys
```

Install Docker on the VPS if not already installed:

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker deploy
```

### Step 2: Configure Kamal Secrets

1. Copy the secrets template:
```bash
cp .kamal/secrets.template .kamal/secrets
```

2. Edit `.kamal/secrets` and fill in your actual values:
```bash
# Required values:
VPS_IP=your.vps.ip.address
DOMAIN=yourdomain.com
DOCKER_REGISTRY=ghcr.io/yourusername/stem-app
DOCKER_REGISTRY_SERVER=ghcr.io
DOCKER_REGISTRY_USERNAME=your-github-username
DOCKER_REGISTRY_PASSWORD=your-github-personal-access-token
RAILS_MASTER_KEY=<value from config/master.key>
STEM_APP_DATABASE_PASSWORD=<choose-a-strong-password>
POSTGRES_PASSWORD=<same-as-database-password>
LETSENCRYPT_EMAIL=your-email@example.com
```

### Step 3: Update Deploy Configuration (Optional)

Review and customize `config/deploy.yml` if needed:

- **Server settings**: Adjust RAM, CPU limits if needed
- **Registry**: Change if not using GitHub Container Registry
- **SSH user**: Default is `deploy`, change if needed
- **PostgreSQL settings**: Tune based on your VPS resources

## Deployment Commands

### First-Time Deployment

```bash
# 1. Set up infrastructure on the VPS (Traefik, PostgreSQL)
kamal setup

# This will:
# - Install and configure Traefik reverse proxy
# - Create PostgreSQL container with 4 databases
# - Set up Docker networks and volumes
# - Obtain SSL certificate from Let's Encrypt
```

### Deploy Application

```bash
# Deploy the application
kamal deploy

# This will:
# - Build Docker image locally
# - Push to registry
# - Pull on VPS
# - Run database migrations
# - Start the application with zero-downtime
```

### Subsequent Deployments

After the initial setup, you only need:

```bash
kamal deploy
```

## Common Operations

### View Application Logs

```bash
# Real-time logs
kamal app logs -f

# Last 100 lines
kamal app logs --lines 100

# Specific container
kamal app logs --container web
```

### View Database Logs

```bash
kamal accessory logs db -f
```

### Access Rails Console

```bash
kamal app exec -i --reuse "bin/rails console"
```

### Run Database Migrations

```bash
kamal app exec "bin/rails db:migrate"
```

### Rollback Deployment

```bash
kamal rollback
```

### Restart Application

```bash
kamal app restart
```

### Access PostgreSQL Database

```bash
# Get PostgreSQL container details
kamal accessory details db

# Connect to database
kamal accessory exec db "psql -U stem_app -d stem_app_production"
```

### Check Application Status

```bash
# Overall status
kamal app details

# Accessory status
kamal accessory details db
```

## Database Management

### Creating Additional Databases

The PostgreSQL accessory automatically creates 4 databases on first run:
- `stem_app_production` - Main application database
- `stem_app_production_cache` - Solid Cache
- `stem_app_production_queue` - Solid Queue
- `stem_app_production_cable` - Solid Cable

### Backup Database

```bash
# Backup main database
kamal accessory exec db "pg_dump -U stem_app stem_app_production" > backup.sql

# Backup all databases
kamal accessory exec db "pg_dumpall -U stem_app" > backup_all.sql
```

### Restore Database

```bash
cat backup.sql | kamal accessory exec -i db "psql -U stem_app stem_app_production"
```

## Monitoring

### Health Check

The application exposes a health check endpoint at `/up` (configured in `config/routes.rb`).

Check it via:
```bash
curl https://yourdomain.com/up
```

### Resource Usage

```bash
# Check Docker container resource usage
kamal app exec "docker stats --no-stream"
```

## Troubleshooting

### Application Won't Start

1. Check logs:
```bash
kamal app logs --lines 100
```

2. Verify environment variables:
```bash
kamal app exec "env | grep RAILS"
```

3. Check database connectivity:
```bash
kamal app exec "bin/rails runner 'puts ActiveRecord::Base.connection.active?'"
```

### SSL Certificate Issues

1. Check Traefik logs:
```bash
kamal traefik logs -f
```

2. Verify DNS:
```bash
dig yourdomain.com
```

3. Ensure ports 80 and 443 are open on your VPS firewall

### Database Connection Issues

1. Check if PostgreSQL is running:
```bash
kamal accessory details db
```

2. Verify database exists:
```bash
kamal accessory exec db "psql -U stem_app -l"
```

3. Test connection from app container:
```bash
kamal app exec "nc -zv stem-app-db 5432"
```

### Out of Disk Space

1. Check disk usage:
```bash
kamal app exec "df -h"
```

2. Clean up old Docker images:
```bash
kamal app exec "docker system prune -a"
```

3. Clean up old application images:
```bash
kamal app remove --version <old-version>
```

## Scaling

### Increase Database Resources

Edit `config/deploy.yml` and adjust PostgreSQL settings:

```yaml
accessories:
  db:
    cmd: >
      postgres
      -c max_connections=400           # Increase max connections
      -c shared_buffers=512MB          # Increase buffer size
      -c effective_cache_size=2GB      # Increase cache size
```

Then restart the database:
```bash
kamal accessory restart db
```

### Add More Web Workers

Set the `WEB_CONCURRENCY` environment variable in `config/deploy.yml`:

```yaml
env:
  clear:
    WEB_CONCURRENCY: 3  # Number of Puma workers
```

Then redeploy:
```bash
kamal deploy
```

## Security Best Practices

1. **Keep secrets secure**: Never commit `.kamal/secrets` to version control
2. **Use strong passwords**: Generate secure database passwords
3. **Regular updates**: Keep Docker images and gems updated
4. **Firewall**: Only open necessary ports (22, 80, 443)
5. **SSH keys**: Use SSH key authentication, disable password auth
6. **Backups**: Regularly backup your database and uploaded files

## File Storage

Currently using local disk storage at `/rails/storage` (mounted as Docker volume).

### Backup Uploaded Files

```bash
# Create archive of uploaded files
kamal app exec "tar czf /tmp/storage-backup.tar.gz storage/"

# Copy to local machine
kamal app exec "cat /tmp/storage-backup.tar.gz" > storage-backup.tar.gz
```

### Migrate to S3 (Future)

To migrate to S3-compatible storage:

1. Update `config/storage.yml`
2. Add S3 credentials to `.kamal/secrets`
3. Run migration script to move files
4. Update `config/environments/production.rb`

## Additional Resources

- [Kamal Documentation](https://kamal-deploy.org/)
- [Rails Guides - Deployment](https://guides.rubyonrails.org/)
- [Solid Queue Documentation](https://github.com/rails/solid_queue)
- [Traefik Documentation](https://doc.traefik.io/traefik/)

## Support

For issues or questions:
- Check logs: `kamal app logs`
- Verify configuration: `kamal app details`
- Check infrastructure: `kamal accessory details db`
