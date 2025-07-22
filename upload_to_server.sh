#!/bin/bash

# Configuration - Update these for your server
SERVER_USER="chootka"  # Change this to your username
SERVER_HOST="dweb2025.nohost.me"
SERVER_PATH="/tmp/"

echo "📦 Creating deployment package..."
tar -czf meshtastic-mqtt.tar.gz . \
    --exclude='.git' \
    --exclude='venv' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='.DS_Store' \
    --exclude='*.log'

echo "📤 Uploading to server..."
scp meshtastic-mqtt.tar.gz $SERVER_USER@$SERVER_HOST:$SERVER_PATH

echo "✅ Upload complete!"
echo ""
echo "🚀 Next steps:"
echo "1. SSH into your server: ssh $SERVER_USER@$SERVER_HOST"
echo "2. Extract files: cd /tmp && tar -xzf meshtastic-mqtt.tar.gz"
echo "3. Deploy: sudo ./deploy_production.sh"
echo ""
echo "📋 Or run this one-liner on your server:"
echo "   cd /tmp && tar -xzf meshtastic-mqtt.tar.gz && sudo ./deploy_production.sh"

# Clean up local tar file
rm meshtastic-mqtt.tar.gz 