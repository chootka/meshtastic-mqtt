# 🚀 Deployment Guide for Meshtastic MQTT Server

## 🎯 Option 1: Deploy to Your Existing Server (Recommended)

Since you already have `dweb2025.nohost.me` running your MQTT broker, this is the ideal place to deploy your web app.

**⚠️ Note**: The main deployment scripts (`deploy_production.sh` and `deploy_fixed.sh`) are now optimized for **YunoHost** environments and include SSOwat bypass configuration. For non-YunoHost servers, see Option 2 below.

### Step 1: Upload Files to Server

```bash
# On your local machine, create a deployment package
tar -czf meshtastic-mqtt.tar.gz . --exclude='.git' --exclude='venv' --exclude='__pycache__'

# Upload to your server
scp meshtastic-mqtt.tar.gz user@dweb2025.nohost.me:/tmp/
```

### Step 2: Extract and Deploy

```bash
# SSH into your server
ssh user@dweb2025.nohost.me

# Extract files
cd /tmp
tar -xzf meshtastic-mqtt.tar.gz

# Run deployment script
sudo ./deploy_production.sh
```

### Step 3: Set up DNS and Access Your App

1. **Create DNS A record**: Point `mqtt.dweb2025.nohost.me` to your server's IP
2. **Test locally first**: `curl http://localhost:5001/health`
3. **Access your app**: **http://mqtt.dweb2025.nohost.me**

---

## 🔧 Option 2: Manual Server Setup

If you prefer manual setup or don't have root access:

### On Your Server:

```bash
# 1. Clone/upload your files to the server
mkdir -p ~/meshtastic-mqtt
cd ~/meshtastic-mqtt
# ... upload files here ...

# 2. Setup Python environment
python3 -m venv venv
source venv/bin/activate
pip install -r requirements_production.txt

# 3. Run with Gunicorn (production WSGI server)
gunicorn --worker-class eventlet -w 1 --bind 0.0.0.0:5001 meshtastic_server_production:app

# 4. Or run in background with nohup
nohup python3 meshtastic_server_production.py > meshtastic.log 2>&1 &
```

### Configure Reverse Proxy (Nginx/Apache)

If you want to serve on port 80/443, you'll need a reverse proxy:

**Nginx Configuration:**
```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:5001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

---

## 🌐 Option 3: Cloud Platform Deployment

### A. Render.com (Easy, Free Tier Available)

1. **Create a `render.yaml`:**

```yaml
services:
  - type: web
    name: meshtastic-mqtt
    runtime: python3
    buildCommand: pip install -r requirements_production.txt
    startCommand: python meshtastic_server_production.py
    envVars:
      - key: SERVER_HOST
        value: 0.0.0.0
      - key: SERVER_PORT
        value: 10000
```

2. **Push to GitHub and connect to Render**

### B. Railway (Easy Alternative)

1. **Create a `railway.toml`:**

```toml
[build]
builder = "nixpacks"

[deploy]
startCommand = "python meshtastic_server_production.py"

[[ports]]
port = 5001
```

2. **Deploy with Railway CLI:**

```bash
npm install -g @railway/cli
railway login
railway init
railway up
```

### C. Heroku

1. **Create a `Procfile`:**

```
web: python meshtastic_server_production.py
```

2. **Create a `runtime.txt`:**

```
python-3.11.0
```

3. **Deploy:**

```bash
heroku create your-app-name
git push heroku main
```

---

## 🐳 Option 4: Docker Deployment

### Create a `Dockerfile`:

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements_production.txt .
RUN pip install --no-cache-dir -r requirements_production.txt

COPY . .

EXPOSE 5001

CMD ["python", "meshtastic_server_production.py"]
```

### Build and Run:

```bash
# Build image
docker build -t meshtastic-mqtt .

# Run container
docker run -d -p 5001:5001 --name meshtastic-mqtt-server meshtastic-mqtt

# Or with docker-compose.yml:
version: '3.8'
services:
  meshtastic-mqtt:
    build: .
    ports:
      - "5001:5001"
    environment:
      - MQTT_BROKER=dweb2025.nohost.me
      - SERVER_HOST=0.0.0.0
    restart: unless-stopped
```

---

## 🔒 Option 5: Add HTTPS (SSL/TLS)

### With Let's Encrypt (Free SSL):

```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx

# Get certificate
sudo certbot --nginx -d your-domain.com

# Auto-renewal
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

---

## 🔧 Environment Variables

For production deployment, you can customize using environment variables:

```bash
export MQTT_BROKER="your-mqtt-broker.com"
export MQTT_PORT="1883"
export MQTT_ROOT_TOPIC="msh/your-topic"
export SERVER_HOST="0.0.0.0"
export SERVER_PORT="5001"
export SECRET_KEY="your-very-secure-secret-key"
```

---

## 📊 Monitoring & Maintenance

### View Logs:

```bash
# If using systemd service
sudo journalctl -u meshtastic-mqtt -f

# If running manually
tail -f meshtastic.log
```

### Restart Service:

```bash
# Systemd
sudo systemctl restart meshtastic-mqtt

# Manual
pkill -f meshtastic_server_production.py
python3 meshtastic_server_production.py &
```

### Health Check:

```bash
curl http://your-domain.com/health
```

---

## ⚡ Quick Start (Recommended)

**For your existing server at dweb2025.nohost.me:**

1. **Set up DNS**: Create A record for `mqtt.dweb2025.nohost.me` → your server IP
2. Upload files to server
3. Run: `sudo ./deploy_production.sh`
4. Test: `curl http://localhost:5001/health`
5. Visit: `http://mqtt.dweb2025.nohost.me`
6. Done! 🎉

This will give you a production-ready deployment with:
- ✅ Systemd service (auto-restart)
- ✅ Nginx reverse proxy
- ✅ Proper user isolation
- ✅ Production-optimized settings 