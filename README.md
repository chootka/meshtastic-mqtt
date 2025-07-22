# Meshtastic MQTT Server

A Python web server that provides a real-time interface for sending and receiving MQTT messages to/from your meshtastic network.

## Features

- 🌐 Real-time web interface for monitoring meshtastic messages
- 📡 Send messages to your meshtastic network via MQTT
- 📊 Live message log with timestamps and message types
- 🎨 Modern, responsive web UI
- 🔄 Auto-reconnection to MQTT broker

## Prerequisites

- Python 3.7 or higher
- Access to your MQTT broker (configured as `dweb2025.nohost.me:1883`)
- Meshtastic devices configured with MQTT uplink/downlink

## Installation

1. Create and activate a virtual environment:
```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install the required dependencies:
```bash
pip install -r requirements.txt
```

## Configuration

The server is pre-configured for your meshtastic setup:

- **MQTT Broker**: `dweb2025.nohost.me:1883`
- **Root Topic**: `msh/chootka`
- **Devices**:
  - `fa6f1418` (4201583640)
  - `435722f4` (1129784052)

To modify these settings, edit the configuration section in `meshtastic_server.py`:

```python
# Configuration
MQTT_BROKER = "dweb2025.nohost.me"
MQTT_PORT = 1883
MQTT_ROOT_TOPIC = "msh/chootka"

# Meshtastic device IDs
DEVICES = {
    "fa6f1418": 4201583640,
    "435722f4": 1129784052
}
```

## Usage

1. Start the server (with auto-setup):
```bash
./start_server.sh
```

Or manually:
```bash
source venv/bin/activate  # Activate virtual environment
python meshtastic_server.py
```

2. Open your web browser and navigate to:
```
http://localhost:5001
```

3. The interface will show:
   - **Connection status** to the MQTT broker
   - **Real-time message log** of all incoming messages
   - **Send form** to transmit messages to your meshtastic network

## Sending Messages

1. Select a device from the dropdown (either `fa6f1418` or `435722f4`)
2. Type your message in the text area
3. Click "Send Message"

Messages will be sent to the MQTT channel and appear in the tropica channel on your meshtastic devices.

## Message Format

The server automatically formats messages according to the meshtastic MQTT protocol:

```json
{
    "from": <device_number>,
    "type": "sendtext",
    "payload": "<your_message>"
}
```

Published to topic: `msh/chootka/2/json/mqtt/!<device_id>`

## Troubleshooting

### Connection Issues
- Verify your MQTT broker is accessible at `dweb2025.nohost.me:1883`
- Check that your meshtastic devices have MQTT enabled and configured
- Ensure your network allows outbound connections on port 1883

### Messages Not Appearing
- Remember: You won't see your own messages in the chat room of the device you're sending from
- Messages need to be sent to the MQTT channel (channel 1) to appear in the tropica channel (channel 0)
- Check that uplink is enabled on channel 0 and downlink is enabled on channel 1

### Web Interface Issues
- Try refreshing the page if the connection status shows "Disconnected"
- Check the browser console for any JavaScript errors
- Ensure port 5001 is not blocked by your firewall

## Testing with Command Line

You can also test the MQTT connection directly using mosquitto tools:

Subscribe to all messages:
```bash
mosquitto_sub -h dweb2025.nohost.me -t 'msh/chootka/#' -v
```

Send a test message:
```bash
mosquitto_pub -h dweb2025.nohost.me -t 'msh/chootka/2/json/mqtt/!fa6f1418' -m '{
    "from": 4201583640,
    "type": "sendtext",
    "payload": "Test message from command line"
}'
```

## File Structure

```
mqtt/
├── meshtastic_server.py    # Main server application
├── requirements.txt        # Python dependencies
├── templates/
│   └── index.html         # Web interface template
└── README.md              # This file
```

## Technical Details

- **Backend**: Python Flask with SocketIO for real-time communication
- **MQTT Client**: paho-mqtt for MQTT protocol handling
- **Frontend**: HTML/CSS/JavaScript with Socket.IO client
- **Real-time Updates**: WebSocket connection for instant message delivery

## 🚀 Deployment

For deploying this app to a remote server, see **[DEPLOYMENT.md](DEPLOYMENT.md)** for comprehensive deployment options including:

- **Recommended**: Deploy to your existing server (dweb2025.nohost.me)
- **YunoHost**: See [RASPBERRY_PI_DEPLOY.md](RASPBERRY_PI_DEPLOY.md) for YunoHost-specific instructions
- Cloud platforms (Render, Railway, Heroku)
- Docker deployment
- Manual server setup

**Quick Deploy** to your existing server:
```bash
# 1. Set up DNS: mqtt.dweb2025.nohost.me → your server IP
# 2. Edit upload_to_server.sh with your username
# 3. Upload and deploy
./upload_to_server.sh
```

### 🍓 **YunoHost/Raspberry Pi Users**

This project has been successfully deployed on **YunoHost** with SSOwat bypass. Key files for YunoHost deployment:
- `nginx-yunohost-config.conf` - Nginx configuration with SSOwat bypass
- `start_server_production.sh` - Production startup script
- `meshtastic-mqtt.service` - Systemd service template

**Key Deployment Notes:**
- ⚠️ **Broken Python symlinks**: Raspberry Pi OS creates broken symlinks in venv. Fixed by manually linking to `/usr/bin/python3`
- ✅ **User permissions**: Run as regular user (`chootka`) instead of creating system user
- ✅ **YunoHost SSOwat**: Bypass required using `access_by_lua_block { return }`

**Recommended deployment scripts:**
- `deploy_production.sh` - Main deployment script (includes symlink fix)
- `deploy_fixed.sh` - Alternative with more error handling

## License

This project is provided as-is for your meshtastic network setup. # meshtastic-mqtt
