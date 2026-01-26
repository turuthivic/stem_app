# Deployment Guide

This application is configured to deploy to a VPS using Kamal.

## Prerequisites

1. **VPS Server**: A Linux server (Ubuntu 22.04+ recommended) with:
   - Docker installed
   - SSH access configured
   - At least 4GB RAM (8GB+ recommended for Demucs audio processing)
   - 20GB+ disk space

2. **Docker Hub Account**: For storing container images
   - Sign up at https://hub.docker.com
   - Create an access token in Account Settings > Security

3. **Domain Name**: Point your domain's A record to your server IP

## Setup Steps

### 1. Configure Deployment Settings

Edit `config/deploy.yml` and replace the placeholders:

```yaml
image: YOUR_DOCKER_USERNAME/stem-app        # Your Docker Hub username
servers:
  web:
    - YOUR_SERVER_IP                        # Your VPS IP address
  job:
    hosts:
      - YOUR_SERVER_IP                      # Same IP for job server
proxy:
  host: YOUR_DOMAIN.com                     # Your domain name
registry:
  username: YOUR_DOCKER_USERNAME            # Your Docker Hub username
accessories:
  db:
    host: YOUR_SERVER_IP                    # Same IP for database
```

### 2. Configure Secrets

Copy the secrets example and fill in your values:

```bash
cp .kamal/secrets.example .kamal/secrets
```

Edit `.kamal/secrets` with your actual values:

```bash
# Get your Docker Hub token from https://hub.docker.com/settings/security
KAMAL_REGISTRY_PASSWORD=your_docker_hub_token

# Get from config/master.key (this file should already exist)
RAILS_MASTER_KEY=$(cat config/master.key)

# Create a strong password for PostgreSQL
POSTGRES_PASSWORD=your_secure_postgres_password
STEM_APP_DATABASE_PASSWORD=your_secure_postgres_password
```

### 3. Setup VPS Server

SSH into your server and install Docker:

```bash
# On Ubuntu 22.04+
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

Log out and back in for the group change to take effect.

### 4. Deploy

From your local machine:

```bash
# First deployment - sets up everything
bundle exec kamal setup

# Future deployments
bundle exec kamal deploy
```

### 5. Initialize Database

After first deployment, run migrations:

```bash
bundle exec kamal app exec 'bin/rails db:create db:migrate'
```

## Common Commands

```bash
# Deploy application
bundle exec kamal deploy

# View logs
bundle exec kamal app logs

# SSH into container
bundle exec kamal app exec -i bash

# Restart application
bundle exec kamal app restart

# Stop application
bundle exec kamal app stop

# Remove everything (destructive!)
bundle exec kamal remove
```

## Monitoring

- **Application logs**: `kamal app logs -f`
- **Job worker logs**: `kamal app logs -r job -f`
- **Database logs**: `kamal accessory logs db -f`

## Troubleshooting

### Port 80/443 Issues
If ports are already in use, check for existing services:
```bash
sudo lsof -i :80
sudo lsof -i :443
```

### Database Connection Issues
Check if PostgreSQL container is running:
```bash
kamal accessory details db
```

### Out of Memory
Demucs audio processing requires significant RAM. If you see OOM errors:
- Upgrade to a server with more RAM
- Consider adding swap space

### SSL Certificate Issues
Let's Encrypt certificates are automatically provisioned. If SSL fails:
- Ensure domain DNS is correctly pointing to server
- Check firewall allows ports 80 and 443
- View proxy logs: `kamal accessory logs kamal-proxy -f`

## Environment Variables

Add additional environment variables in `config/deploy.yml`:

```yaml
env:
  secret:
    - RAILS_MASTER_KEY
    - STEM_APP_DATABASE_PASSWORD
  clear:
    RAILS_MAX_THREADS: 5
```

## Scaling

### Multiple Web Servers
Add more IPs to the web servers list:

```yaml
servers:
  web:
    - 192.168.1.1
    - 192.168.1.2
```

### Background Job Workers
Already configured as a separate container on the same host.

## Backup

Database backups should be configured separately:

```bash
# Manual backup
kamal accessory exec db pg_dump -U stem_app stem_app_production > backup.sql

# Setup automated backups (on server)
# Use cron with pg_dump or a backup service
```
