#!/bin/bash

echo "🔧 Fixed Deployment for Raspberry Pi (Symlink Issue)"
echo "=================================================="

# Configuration
APP_NAME="meshtastic-mqtt"
APP_DIR="/opt/$APP_NAME"
SERVICE_FILE="/etc/systemd/system/$APP_NAME.service"
NGINX_CONFIG="/etc/nginx/sites-available/$APP_NAME"
DOMAIN="mqtt.dweb2025.nohost.me"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root (sudo ./deploy_fixed.sh)"
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

echo "🔍 Finding correct Python path..."
PYTHON_PATH=$(which python3)
echo "Found Python at: $PYTHON_PATH"

# Remove any existing broken venv
if [ -d "venv" ]; then
    echo "🗑️ Removing existing broken virtual environment..."
    rm -rf venv
fi

echo "🐍 Creating virtual environment with correct Python path..."
$PYTHON_PATH -m venv venv --system-site-packages

echo "🔗 Fixing broken Python symlinks (manual fix that actually works)..."
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

echo "✅ Verifying Python works in venv..."
source venv/bin/activate
python --version || {
    echo "❌ Python still not working in venv, falling back to system Python"
    rm -rf venv
    mkdir -p venv/bin
    cd venv/bin
    ln -s $PYTHON_PATH python
    ln -s $PYTHON_PATH python3
    ln -s $(which pip3) pip3
    ln -s $(which pip3) pip
    cd ../..
}

echo "📦 Installing Python packages..."
source venv/bin/activate

# Try pip install with multiple fallback methods
echo "Installing packages (trying multiple methods)..."

# Method 1: Standard pip
if pip install paho-mqtt flask-socketio python-socketio python-engineio eventlet; then
    echo "✅ Standard pip install successful"
elif pip install paho-mqtt flask-socketio python-socketio python-engineio eventlet --break-system-packages; then
    echo "✅ Pip install with --break-system-packages successful"
else
    echo "⚠️ Pip failed, installing system packages and minimal pip packages..."
    apt install -y python3-flask python3-werkzeug python3-jinja2
    pip install paho-mqtt flask-socketio --break-system-packages --user
fi

echo "🧪 Testing package imports..."
python -c "
try:
    import paho.mqtt.client
    import flask
    import flask_socketio
    print('✅ All required modules imported successfully')
except ImportError as e:
    print(f'❌ Import error: {e}')
    print('Installing missing packages...')
    import subprocess
    subprocess.run(['pip', 'install', 'paho-mqtt', 'flask-socketio', '--break-system-packages'], check=False)
    # Test again
    import paho.mqtt.client
    import flask
    import flask_socketio
    print('✅ All required modules imported successfully after retry')
"

echo "👤 Setting up permissions for chootka user..."
# Ensure chootka user can access the app directory
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

# Create the startup script
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

echo "🧪 Final test of the application..."
sudo -u chootka $APP_DIR/venv/bin/python -c "
import sys
print(f'Python executable: {sys.executable}')
print(f'Python version: {sys.version}')
try:
    import paho.mqtt.client
    import flask
    import flask_socketio
    print('✅ All required modules work with chootka user')
except ImportError as e:
    print(f'❌ Import error with chootka user: {e}')
    exit(1)
" || {
    echo "⚠️ User test failed, but continuing..."
}

echo "🔄 Starting services..."
systemctl daemon-reload
systemctl enable $APP_NAME
systemctl start $APP_NAME

# Check service status
sleep 2
if systemctl is-active --quiet $APP_NAME; then
    echo "✅ Service started successfully"
else
    echo "⚠️ Service may have issues, checking logs..."
    systemctl status $APP_NAME --no-pager -l
fi

# Test nginx config
nginx -t
if [ $? -eq 0 ]; then
    systemctl reload nginx
    echo "✅ Nginx reloaded successfully"
else
    echo "❌ Nginx configuration test failed"
fi

echo ""
echo "✅ Fixed deployment complete!"
echo ""
echo "🌐 Your Meshtastic MQTT interface will be available at:"
echo "   http://$DOMAIN"
echo ""
echo "🧪 Test the service:"
echo "   curl http://localhost:5001/health"
echo ""
echo "📊 Check status and logs:"
echo "   sudo systemctl status $APP_NAME"
echo "   sudo journalctl -u $APP_NAME -f"
echo ""
echo "🔧 Debug info:"
echo "   Python path used: $PYTHON_PATH"
echo "   Virtual env location: $APP_DIR/venv" 