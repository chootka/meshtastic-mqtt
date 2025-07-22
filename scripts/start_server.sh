#!/bin/bash

echo "🌐 Starting Meshtastic MQTT Server..."
echo "📡 Connecting to dweb2025.nohost.me:1883"
echo "🔗 Web interface will be available at http://localhost:5001"
echo ""

# Activate virtual environment
source venv/bin/activate

# Check if requirements are installed
if [ ! -f "venv/pyvenv.cfg" ] || ! python -c "import paho.mqtt.client, flask, flask_socketio" 2>/dev/null; then
    echo "📦 Installing requirements..."
    pip install -r requirements.txt
fi

echo "🚀 Starting server..."
python meshtastic_server.py 