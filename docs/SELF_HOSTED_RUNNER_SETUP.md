# Self-Hosted GitHub Actions Runner Setup Guide

This guide walks you through setting up a self-hosted GitHub Actions runner on Ubuntu to deploy your DataOps pipeline.

## 📋 Prerequisites

Before you begin, ensure you have:

- **Ubuntu Server** (20.04 LTS or later recommended)
- **Sudo/Root access** to the server
- **GitHub repository access** with admin permissions
- **Stable internet connection**
- **Docker & Docker Compose** installed on the server

## 🚀 Quick Setup Overview

1. Install system dependencies
2. Install Docker and Docker Compose
3. Configure GitHub Actions runner
4. Set up the runner as a system service
5. Test the deployment

---

## 📦 Step 1: Install System Dependencies

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y \
    curl \
    wget \
    git \
    jq \
    tar \
    libssl-dev \
    libffi-dev \
    python3 \
    python3-pip
```

## 🐳 Step 2: Install Docker & Docker Compose

### Install Docker

```bash
# Remove old versions (if any)
sudo apt remove docker docker-engine docker.io containerd runc

# Install Docker using official script
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add your user to docker group (avoid using sudo for docker commands)
sudo usermod -aG docker $USER

# Apply group changes (or logout and login again)
newgrp docker

# Verify Docker installation
docker --version
docker run hello-world
```

### Install Docker Compose

```bash
# Download Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Make it executable
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
docker-compose --version
```

## 🤖 Step 3: Configure GitHub Actions Runner

### 3.1 Create a Runner User (Optional but Recommended)

```bash
# Create a dedicated user for the runner
sudo useradd -m -s /bin/bash github-runner
sudo usermod -aG docker github-runner

# Switch to runner user
sudo su - github-runner
```

### 3.2 Download and Configure Runner

```bash
# Create a directory for the runner
mkdir -p ~/actions-runner && cd ~/actions-runner

# Download the latest runner package
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz

# Extract the installer
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz

# Remove the archive
rm actions-runner-linux-x64-2.311.0.tar.gz
```

### 3.3 Get Runner Token from GitHub

1. Go to your GitHub repository: `https://github.com/<YOUR_USERNAME>/dataops-project`
2. Navigate to: **Settings** → **Actions** → **Runners** → **New self-hosted runner**
3. Select **Linux** as the operating system
4. Copy the configuration command (it includes your unique token)

### 3.4 Configure the Runner

```bash
# Run the configuration script with your token
./config.sh --url https://github.com/<YOUR_USERNAME>/dataops-project --token YOUR_TOKEN_HERE

# When prompted:
# - Enter runner group: Default (press Enter)
# - Enter runner name: self-hosted
# - Enter labels: self-hosted,Linux,X64 (press Enter for defaults)
# - Enter work folder: _work (press Enter for default)
```

### 3.5 Test the Runner (Optional)

```bash
# Run the runner interactively to test
./run.sh

# Press Ctrl+C to stop after testing
```

## 🔧 Step 4: Set Up Runner as a System Service

To keep the runner running automatically and restart on boot:

```bash
# Install the service (run as the runner user)
cd ~/actions-runner
sudo ./svc.sh install

# Start the service
sudo ./svc.sh start

# Check service status
sudo ./svc.sh status

# Enable auto-start on boot
sudo systemctl enable actions.runner.<YOUR_USENAME>-dataops-project.dataops-prod-runner.service
```

### Service Management Commands

```bash
# Start the runner
sudo ./svc.sh start

# Stop the runner
sudo ./svc.sh stop

# Check status
sudo ./svc.sh status

# View logs
sudo journalctl -u actions.runner.* -f
```

## 📂 Step 5: Clone and Prepare Your Project

```bash
# Create a workspace directory
mkdir -p ~/workspace
cd ~/workspace

# Clone your repository
git clone https://github.com/ngocnhan2k4/dataops-project.git
cd dataops-project

# Set proper permissions
chmod +x sqlserver/entrypoint.sh sqlserver/restore_db.sh
```

## 🔒 Security Best Practices

### 1. Firewall Configuration

```bash
# Enable UFW firewall
sudo ufw enable

# Allow SSH (replace 22 with your SSH port if different)
sudo ufw allow 22/tcp

# Allow Docker network communication
sudo ufw allow from 172.16.0.0/12 to any

# Check firewall status
sudo ufw status
```

### 2. Secure Docker Socket

```bash
# The runner user already has Docker access via group membership
# Verify with:
groups github-runner

# Should show: github-runner : github-runner docker
```

### 3. GitHub Secrets Configuration

Add these secrets in your GitHub repository:

- Go to **Settings** → **Secrets and variables** → **Actions**
- Add any sensitive configuration (database passwords, API keys, etc.)

## 🔍 Troubleshooting

### Runner Not Appearing in GitHub

```bash
# Check if the service is running
sudo systemctl status actions.runner.*

# Check logs
sudo journalctl -u actions.runner.* -f

# Restart the service
cd ~/actions-runner
sudo ./svc.sh stop
sudo ./svc.sh start
```

### Docker Permission Denied

```bash
# Ensure user is in docker group
sudo usermod -aG docker github-runner

# Reboot or restart the service
sudo reboot
```

### Container Health Issues

```bash
# Check container logs
docker logs dataops-dbt
docker logs dataops-airflow
docker logs dataops-sqlserver

# Restart containers
docker-compose down
docker-compose up -d --build

# Check disk space
df -h

# Clean up old Docker resources
docker system prune -a
```

### Deployment Fails on First Run

```bash
# Ensure the project directory exists and is accessible
cd ~/workspace/dataops-project
git pull origin main

# Manually run the deployment steps
docker-compose up -d --build
sleep 30
docker exec dataops-dbt dbt deps
docker exec dataops-dbt dbt run --target dev
```

## 📊 Monitoring

### View Runner Logs

```bash
# Real-time logs
sudo journalctl -u actions.runner.* -f

# Last 100 lines
sudo journalctl -u actions.runner.* -n 100

# Logs from today
sudo journalctl -u actions.runner.* --since today
```

## 🔄 Maintenance

### Update Runner

```bash
# Stop the service
cd ~/actions-runner
sudo ./svc.sh stop

# Download latest version
curl -o actions-runner-linux-x64-latest.tar.gz -L https://github.com/actions/runner/releases/latest/download/actions-runner-linux-x64-latest.tar.gz

# Extract
tar xzf ./actions-runner-linux-x64-latest.tar.gz

# Restart service
sudo ./svc.sh start
```

## 📝 Configuration Files Location

- **Runner config**: `~/actions-runner/.runner`
- **Runner credentials**: `~/actions-runner/.credentials`
- **Service file**: `/etc/systemd/system/actions.runner.*.service`
- **Project workspace**: Set by GitHub Actions (usually `~/actions-runner/_work`)

## ✅ Verification Checklist

- [ ] Ubuntu system updated
- [ ] Docker installed and running
- [ ] Docker Compose installed
- [ ] GitHub runner configured and connected
- [ ] Runner service enabled and started
- [ ] Runner appears in GitHub repository settings
- [ ] Manual docker-compose test successful
- [ ] Test deployment via GitHub Actions successful
- [ ] Firewall configured (if needed)
- [ ] Monitoring and logs accessible

## 🆘 Support

If you encounter issues:

1. Check the troubleshooting section above
2. Review GitHub Actions logs in the **Actions** tab
3. Check runner logs: `sudo journalctl -u actions.runner.* -f`

---

**Last Updated**: December 2025  
**Maintained By**: DataOps Team
