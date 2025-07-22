#!/bin/bash

echo "🚀 Production Deployment Script for Meshtastic MQTT Server"
echo "=========================================================="

# Configuration
APP_NAME="meshtastic-mqtt"
APP_DIR="/opt/$APP_NAME"
SERVICE_FILE="/etc/systemd/system/$APP_NAME.service"
NGINX_CONFIG="/etc/nginx/sites-available/$APP_NAME"
DOMAIN="mqtt.dweb2025.nohost.me"  # MQTT subdomain

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root (sudo ./deploy_production.sh)"
    exit 1
fi

echo "📦 Installing system dependencies..."
apt update
apt install -y python3 python3-pip python3-venv python3-full nginx

echo "📁 Setting up application directory..."
mkdir -p $APP_DIR
cp -r . $APP_DIR/
cd $APP_DIR

echo "🐍 Setting up Python virtual environment..."
python3 -m venv venv --system-site-packages
cd $APP_DIR

echo "🔗 Fixing broken Python symlinks (manual fix)..."
if [ -d "venv/bin" ]; then
    cd venv/bin
    echo "Removing broken symlinks..."
    rm -f python python3 pip pip3
    echo "Creating working symlinks to /usr/bin/python3..."
    ln -s /usr/bin/python3 python
    ln -s /usr/bin/python3 python3
    ln -s /usr/bin/pip3 pip3
    ln -s /usr/bin/pip3 pip
    cd ../..
    echo "✅ Symlinks fixed manually"
fi

echo "Activating virtual environment..."
source venv/bin/activate

echo "Upgrading pip in virtual environment..."
python -m pip install --upgrade pip

echo "Installing requirements (with fallback for externally-managed environment)..."
if ! pip install -r requirements_production.txt; then
    echo "⚠️  Standard pip install failed, trying with --break-system-packages..."
    pip install -r requirements_production.txt --break-system-packages
fi

# Verify installation
echo "Verifying critical packages are installed..."
python -c "import paho.mqtt.client, flask, flask_socketio; print('✅ All critical packages verified')" || {
    echo "❌ Package verification failed, trying alternative installation..."
    # Try installing system packages as fallback
    apt install -y python3-flask python3-pip
    pip install paho-mqtt flask-socketio --break-system-packages
}

echo "👤 Setting up permissions for chootka user..."
chown -R chootka:chootka $APP_DIR

echo "⚙️ Creating systemd service..."
cat > $SERVICE_FILE << EOF
[Unit]
Description=Meshtastic MQTT Web Server
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=chootka
Group=chootka
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/start_server.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create the startup script that actually works
cat > $APP_DIR/start_server.sh << EOF
#!/bin/bash
cd $APP_DIR
source venv/bin/activate
exec python meshtastic_server.py
EOF

chmod +x $APP_DIR/start_server.sh

echo "🌐 Configuring Nginx for YunoHost subdomain with SSOwat bypass..."

# Create the nginx config directory for YunoHost
mkdir -p /etc/nginx/conf.d/mqtt.dweb2025.nohost.me.d/

# Create the proxy config with SSOwat bypass (YunoHost approach)
cat > /etc/nginx/conf.d/mqtt.dweb2025.nohost.me.d/meshtastic.conf << EOF
# Meshtastic MQTT Proxy Configuration with SSOwat Bypass
location / {
    # Bypass SSOwat
    access_by_lua_block {
        return
    }
    
    proxy_pass http://127.0.0.1:5001;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$connection_upgrade;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_cache_bypass \$http_upgrade;
    
    # Important for YunoHost SSO bypass (if needed)
    proxy_set_header Authorization \$http_authorization;
    proxy_pass_header Authorization;
}

# WebSocket support for Socket.IO
location /socket.io/ {
    # Bypass SSOwat for WebSockets too
    access_by_lua_block {
        return
    }
    
    proxy_pass http://127.0.0.1:5001;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
}
EOF

echo "✅ Created YunoHost-compatible nginx config with SSOwat bypass"

echo "🔄 Starting services..."
systemctl daemon-reload
systemctl enable $APP_NAME
systemctl start $APP_NAME
systemctl reload nginx

echo "✅ Deployment complete!"
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
echo "📋 Useful commands:"
echo "   sudo systemctl status $APP_NAME     # Check service status"
echo "   sudo systemctl restart $APP_NAME    # Restart service"
echo "   sudo journalctl -u $APP_NAME -f     # View logs"
echo "   sudo nginx -t                       # Test nginx config"
echo "   sudo nginx -s reload                # Reload nginx config" 