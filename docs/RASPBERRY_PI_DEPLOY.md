# 🍓 Raspberry Pi Deployment Guide

## For your dweb2025.nohost.me server with yunohost

### ⚠️ Prerequisites

1. **DNS Setup First**: Create an A record for `mqtt.dweb2025.nohost.me` pointing to your server's IP address
2. **Server Access**: SSH access to your Raspberry Pi server

### 🚀 Quick Deployment

Since you encountered the Python virtual environment issue, use this updated process:

#### 1. Upload Files
```bash
# On your local machine
./upload_to_server.sh
```

#### 2. Deploy on Server
```bash
# SSH to your server
ssh chootka@dweb2025.nohost.me

# Extract and deploy with the fixed script
cd /tmp
tar -xzf meshtastic-mqtt.tar.gz
sudo ./deploy_production.sh
```

The script now handles:
- ✅ **python3-full** package installation (fixes venv issues)
- ✅ **Subdomain configuration** (mqtt.dweb2025.nohost.me)
- ✅ **Yunohost compatibility** (doesn't interfere with main domain)
- ✅ **Raspberry Pi OS** externally-managed environment

#### 3. Verify Deployment
```bash
# Test the service locally
curl http://localhost:5001/health

# Check service status
sudo systemctl status meshtastic-mqtt

# View logs
sudo journalctl -u meshtastic-mqtt -f
```

#### 4. Access Your App
Once DNS propagates: **http://mqtt.dweb2025.nohost.me**

### 🛠️ If You Still Have Issues

Use the manual deployment script for step-by-step troubleshooting:

```bash
# Instead of deploy_production.sh, use:
sudo ./deploy_manual.sh
```

This will:
- Install dependencies step by step
- Test each component
- Give you manual commands to finish setup

### 🔧 Configuration

The app will:
- **Run on**: `localhost:5001` (internal)
- **Accessible via**: `http://mqtt.dweb2025.nohost.me` (external)
- **Service name**: `meshtastic-mqtt`
- **Install location**: `/opt/meshtastic-mqtt`

### 📊 Post-Deployment

**Check everything is working:**
```bash
# Service status
sudo systemctl status meshtastic-mqtt

# Nginx config test
sudo nginx -t

# View real-time logs
sudo journalctl -u meshtastic-mqtt -f

# Test health endpoint
curl http://localhost:5001/health
```

**Restart if needed:**
```bash
sudo systemctl restart meshtastic-mqtt
sudo systemctl reload nginx
```

### 🌐 DNS Setup Details

In your DNS provider (wherever dweb2025.nohost.me is managed):

```
Type: A Record
Name: mqtt
Value: [Your Server IP]
TTL: 300 (or default)
```

This creates: `mqtt.dweb2025.nohost.me` → `Your Server IP`

### 🔒 Security Notes

- App runs as dedicated `meshtastic-mqtt` user
- Only accessible via nginx proxy
- Subdomain isolation from main yunohost instance
- Optional SSL can be added with Let's Encrypt later 