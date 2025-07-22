#!/usr/bin/env python3
import paho.mqtt.client as mqtt
import json
import time
from datetime import datetime
from flask import Flask, render_template, request
from flask_socketio import SocketIO, emit
import threading
import os

# Configuration - can be overridden by environment variables
MQTT_BROKER = os.getenv('MQTT_BROKER', 'dweb2025.nohost.me')
MQTT_PORT = int(os.getenv('MQTT_PORT', '1883'))
MQTT_ROOT_TOPIC = os.getenv('MQTT_ROOT_TOPIC', 'msh/chootka')
MQTT_SUBSCRIBE_TOPIC = f"{MQTT_ROOT_TOPIC}/#"
SERVER_HOST = os.getenv('SERVER_HOST', '127.0.0.1')  # Production: bind to localhost only
SERVER_PORT = int(os.getenv('SERVER_PORT', '5001'))

# Meshtastic device IDs from your notes
DEVICES = {
    "fa6f1418": 4201583640,
    "435722f4": 1129784052
}

# Flask app setup
app = Flask(__name__)
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'meshtastic-mqtt-secret-change-in-production')
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')

# Global variables
mqtt_client = None
message_log = []
MAX_LOG_SIZE = 100

def format_timestamp():
    """Get current timestamp in readable format"""
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")

def add_to_log(message_data):
    """Add message to log and emit to web clients"""
    global message_log
    
    # Add timestamp
    message_data['timestamp'] = format_timestamp()
    
    # Add to log (keep only last MAX_LOG_SIZE messages)
    message_log.append(message_data)
    if len(message_log) > MAX_LOG_SIZE:
        message_log.pop(0)
    
    # Emit to all connected web clients
    socketio.emit('new_message', message_data)
    
    # Print to console (will go to systemd journal in production)
    print(f"[{message_data['timestamp']}] {message_data['type']}: {message_data['content']}")

def on_mqtt_connect(client, userdata, flags, rc):
    """Callback for when MQTT client connects"""
    if rc == 0:
        print(f"Connected to MQTT broker at {MQTT_BROKER}:{MQTT_PORT}")
        client.subscribe(MQTT_SUBSCRIBE_TOPIC)
        print(f"Subscribed to topic: {MQTT_SUBSCRIBE_TOPIC}")
        add_to_log({
            'type': 'system',
            'content': f'Connected to MQTT broker and subscribed to {MQTT_SUBSCRIBE_TOPIC}',
            'topic': '',
            'raw': ''
        })
    else:
        print(f"Failed to connect to MQTT broker. Return code: {rc}")
        add_to_log({
            'type': 'error',
            'content': f'Failed to connect to MQTT broker. Return code: {rc}',
            'topic': '',
            'raw': ''
        })

def on_mqtt_message(client, userdata, msg):
    """Callback for when MQTT message is received"""
    try:
        topic = msg.topic
        payload = msg.payload.decode('utf-8')
        
        print(f"Raw MQTT message - Topic: {topic}, Payload: {payload}")
        
        # Try to parse as JSON
        try:
            message_json = json.loads(payload)
            content = f"From: {message_json.get('from', 'Unknown')}"
            
            if message_json.get('type') == 'sendtext':
                content = f"Text from {message_json.get('from', 'Unknown')}: {message_json.get('payload', '')}"
            elif 'decoded' in message_json and 'text' in message_json['decoded']:
                content = f"Text from {message_json.get('from', 'Unknown')}: {message_json['decoded']['text']}"
            else:
                content = f"Message from {message_json.get('from', 'Unknown')}: {json.dumps(message_json, indent=2)}"
            
            add_to_log({
                'type': 'received',
                'content': content,
                'topic': topic,
                'raw': payload
            })
            
        except json.JSONDecodeError:
            # Not JSON, treat as plain text
            add_to_log({
                'type': 'received',
                'content': f"Non-JSON message: {payload}",
                'topic': topic,
                'raw': payload
            })
            
    except Exception as e:
        print(f"Error processing MQTT message: {e}")
        add_to_log({
            'type': 'error',
            'content': f"Error processing message: {str(e)}",
            'topic': topic if 'topic' in locals() else '',
            'raw': payload if 'payload' in locals() else ''
        })

def on_mqtt_disconnect(client, userdata, rc):
    """Callback for when MQTT client disconnects"""
    print("Disconnected from MQTT broker")
    add_to_log({
        'type': 'system',
        'content': 'Disconnected from MQTT broker',
        'topic': '',
        'raw': ''
    })

def setup_mqtt():
    """Setup MQTT client"""
    global mqtt_client
    
    # Use compatible API that works with both old and new versions
    mqtt_client = mqtt.Client()
    mqtt_client.on_connect = on_mqtt_connect
    mqtt_client.on_message = on_mqtt_message
    mqtt_client.on_disconnect = on_mqtt_disconnect
    
    try:
        mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
        mqtt_client.loop_start()
        return True
    except Exception as e:
        print(f"Failed to connect to MQTT broker: {e}")
        return False

def send_meshtastic_message(device_id, message_text):
    """Send message to meshtastic network"""
    if not mqtt_client:
        return False, "MQTT client not connected"
    
    try:
        # Determine device details
        device_short_id = None
        device_number = None
        
        for short_id, number in DEVICES.items():
            if device_id == short_id or device_id == str(number):
                device_short_id = short_id
                device_number = number
                break
        
        if not device_short_id:
            return False, f"Unknown device ID: {device_id}"
        
        # Construct topic and message according to your working example
        topic = f"{MQTT_ROOT_TOPIC}/2/json/mqtt/!{device_short_id}"
        
        message = {
            "from": device_number,
            "type": "sendtext",
            "payload": message_text
        }
        
        message_json = json.dumps(message)
        
        # Publish message
        result = mqtt_client.publish(topic, message_json)
        
        if result.rc == mqtt.MQTT_ERR_SUCCESS:
            add_to_log({
                'type': 'sent',
                'content': f"Sent as {device_short_id} ({device_number}): {message_text}",
                'topic': topic,
                'raw': message_json
            })
            return True, "Message sent successfully"
        else:
            return False, f"Failed to publish message. Return code: {result.rc}"
            
    except Exception as e:
        return False, f"Error sending message: {str(e)}"

# Flask routes
@app.route('/')
def index():
    """Serve the main web interface"""
    return render_template('index.html')

@app.route('/health')
def health():
    """Health check endpoint"""
    return {'status': 'ok', 'mqtt_connected': mqtt_client is not None and mqtt_client.is_connected()}

@socketio.on('connect')
def handle_connect():
    """Handle new web client connection"""
    print("Web client connected")
    # Send current message log to new client
    for message in message_log:
        emit('new_message', message)

@socketio.on('send_message')
def handle_send_message(data):
    """Handle message send request from web client"""
    device_id = data.get('device_id', '')
    message_text = data.get('message', '')
    
    if not device_id or not message_text:
        emit('error', {'message': 'Device ID and message are required'})
        return
    
    success, error_msg = send_meshtastic_message(device_id, message_text)
    
    if not success:
        emit('error', {'message': error_msg})

@socketio.on('clear_messages')
def handle_clear_messages():
    """Handle clear messages request from web client"""
    global message_log
    message_log.clear()
    print("Message log cleared by web client")
    
    # Emit clear event to all connected clients
    socketio.emit('messages_cleared')

if __name__ == '__main__':
    print("Starting Meshtastic MQTT Server (Production Mode)...")
    print(f"Connecting to MQTT broker: {MQTT_BROKER}:{MQTT_PORT}")
    print(f"Root topic: {MQTT_ROOT_TOPIC}")
    print(f"Available devices: {DEVICES}")
    print(f"Server will bind to: {SERVER_HOST}:{SERVER_PORT}")
    
    # Setup MQTT connection
    if setup_mqtt():
        print("MQTT setup successful, starting web server...")
        print(f"Web interface will be available at: http://{SERVER_HOST}:{SERVER_PORT}")
        
        # Start Flask-SocketIO server (production mode: no debug, specific host)
        socketio.run(app, host=SERVER_HOST, port=SERVER_PORT, debug=False, allow_unsafe_werkzeug=True)
    else:
        print("Failed to setup MQTT connection. Exiting.")
        exit(1) 