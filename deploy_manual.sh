#!/bin/bash

echo "🛠️  Manual Deployment Script for Troubleshooting"
echo "================================================"

# Configuration
APP_NAME="meshtastic-mqtt"
APP_DIR="/opt/$APP_NAME"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root (sudo ./deploy_manual.sh)"
    exit 1
fi

echo "📦 Step 1: Installing system dependencies..."
apt update
apt install -y python3 python3-pip python3-venv python3-full nginx
echo "✅ System dependencies installed"

echo "📁 Step 2: Setting up application directory..."
mkdir -p $APP_DIR
cp -r . $APP_DIR/
cd $APP_DIR
echo "✅ Files copied to $APP_DIR"

echo "🐍 Step 3: Setting up Python virtual environment..."
echo "Creating virtual environment..."
python3 -m venv venv --system-site-packages
if [ ! -d "venv" ]; then
    echo "❌ Failed to create virtual environment"
    exit 1
fi

echo "Activating virtual environment..."
source venv/bin/activate
if [ "$VIRTUAL_ENV" = "" ]; then
    echo "❌ Failed to activate virtual environment"
    exit 1
fi

echo "Upgrading pip..."
python -m pip install --upgrade pip

echo "Installing requirements..."
if [ ! -f "requirements_production.txt" ]; then
    echo "❌ requirements_production.txt not found"
    exit 1
fi

echo "Trying to install requirements..."
if ! pip install -r requirements_production.txt; then
    echo "⚠️  Standard pip install failed, trying with --break-system-packages..."
    if ! pip install -r requirements_production.txt --break-system-packages; then
        echo "❌ Both pip methods failed, trying system packages..."
        apt install -y python3-flask python3-werkzeug
        pip install paho-mqtt flask-socketio --break-system-packages
    fi
fi
echo "✅ Python environment setup complete"

echo "👤 Step 4: Creating app user..."
useradd --system --shell /bin/false --home $APP_DIR $APP_NAME 2>/dev/null || echo "User already exists"
chown -R $APP_NAME:$APP_NAME $APP_DIR
echo "✅ App user created and permissions set"

echo "🧪 Step 5: Testing the application..."
echo "Testing Python script..."
if [ ! -f "meshtastic_server_production.py" ]; then
    echo "❌ meshtastic_server_production.py not found"
    exit 1
fi

# Test if the script can import required modules
sudo -u $APP_NAME $APP_DIR/venv/bin/python -c "
import paho.mqtt.client
import flask
import flask_socketio
print('✅ All required modules can be imported')
"

if [ $? -ne 0 ]; then
    echo "❌ Failed to import required modules"
    exit 1
fi

echo "📋 Manual steps remaining:"
echo "1. Create systemd service file manually:"
echo "   sudo nano /etc/systemd/system/$APP_NAME.service"
echo ""
echo "2. Add this content:"
echo "[Unit]"
echo "Description=Meshtastic MQTT Web Server"
echo "After=network.target"
echo ""
echo "[Service]"
echo "Type=simple"
echo "User=$APP_NAME"
echo "WorkingDirectory=$APP_DIR"
echo "Environment=PATH=$APP_DIR/venv/bin"
echo "ExecStart=$APP_DIR/venv/bin/python $APP_DIR/meshtastic_server_production.py"
echo "Restart=always"
echo "RestartSec=3"
echo ""
echo "[Install]"
echo "WantedBy=multi-user.target"
echo ""
echo "3. Enable and start the service:"
echo "   sudo systemctl daemon-reload"
echo "   sudo systemctl enable $APP_NAME"
echo "   sudo systemctl start $APP_NAME"
echo "   sudo systemctl status $APP_NAME"
echo ""
echo "4. Test the application:"
echo "   curl http://localhost:5001/health"
echo ""
echo "✅ Manual deployment preparation complete!"
echo "   Application is ready at: $APP_DIR" 