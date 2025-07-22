#!/bin/bash

echo "🚀 Simple Deployment for Raspberry Pi (System Packages)"
echo "======================================================"

# Configuration
APP_NAME="meshtastic-mqtt"
APP_DIR="/opt/$APP_NAME"
SERVICE_FILE="/etc/systemd/system/$APP_NAME.service"
NGINX_CONFIG="/etc/nginx/sites-available/$APP_NAME"
DOMAIN="mqtt.dweb2025.nohost.me"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root (sudo ./deploy_simple.sh)"
    exit 1
fi

echo "📦 Installing system dependencies..."
apt update
apt install -y python3 python3-pip python3-venv python3-full nginx
apt install -y python3-flask python3-werkzeug python3-jinja2

echo "📁 Setting up application directory..."
mkdir -p $APP_DIR
cp -r . $APP_DIR/
cd $APP_DIR

echo "🐍 Installing Python packages (minimal virtual environment)..."
python3 -m venv venv --system-site-packages
source venv/bin/activate

# Install only the packages not available as system packages
pip install paho-mqtt flask-socketio python-socketio python-engineio eventlet --break-system-packages

echo "👤 Creating app user..."
useradd --system --shell /bin/false --home $APP_DIR $APP_NAME 2>/dev/null || echo "User already exists"
chown -R $APP_NAME:$APP_NAME $APP_DIR

echo "⚙️ Creating systemd service..."
cat > $SERVICE_FILE << EOF
[Unit]
Description=Meshtastic MQTT Web Server
After=network.target

[Service]
Type=simple
User=$APP_NAME
WorkingDirectory=$APP_DIR
Environment=PATH=$APP_DIR/venv/bin
ExecStart=$APP_DIR/venv/bin/python $APP_DIR/meshtastic_server_production.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

echo "🌐 Configuring Nginx for subdomain..."
cat > $NGINX_CONFIG << EOF
# Meshtastic MQTT Interface - Subdomain Configuration
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:5001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # WebSocket support for Socket.IO
    location /socket.io/ {
        proxy_pass http://127.0.0.1:5001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Optional: Add security headers
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
}
EOF

# Enable nginx site
ln -sf $NGINX_CONFIG /etc/nginx/sites-enabled/

echo "🧪 Testing the application..."
sudo -u $APP_NAME $APP_DIR/venv/bin/python -c "
try:
    import paho.mqtt.client
    import flask
    import flask_socketio
    print('✅ All required modules can be imported')
except ImportError as e:
    print(f'❌ Import error: {e}')
    exit(1)
"

if [ $? -ne 0 ]; then
    echo "❌ Module import test failed"
    exit 1
fi

echo "🔄 Starting services..."
systemctl daemon-reload
systemctl enable $APP_NAME
systemctl start $APP_NAME

# Test nginx config
nginx -t
if [ $? -eq 0 ]; then
    systemctl reload nginx
else
    echo "❌ Nginx configuration test failed"
    exit 1
fi

echo "✅ Simple deployment complete!"
echo ""
echo "🌐 Your Meshtastic MQTT interface will be available at:"
echo "   http://$DOMAIN"
echo ""
echo "📋 IMPORTANT: DNS Setup Required!"
echo "   You need to create a DNS A record for mqtt.dweb2025.nohost.me"
echo "   pointing to your server's IP address."
echo ""
echo "🧪 Test the service locally first:"
echo "   curl http://localhost:5001/health"
echo ""
echo "📊 Check status:"
echo "   sudo systemctl status $APP_NAME"
echo "   sudo journalctl -u $APP_NAME -f" 