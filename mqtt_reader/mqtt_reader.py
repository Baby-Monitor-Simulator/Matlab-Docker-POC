import paho.mqtt.client as mqtt
import time
from datetime import datetime

# Callback when the client receives a CONNACK response from the server
def on_connect(client, userdata, flags, rc):
    print(f"Connected with result code {rc}")
    if rc == 0:
        print("Successfully connected to MQTT broker")
        # Subscribe to a topic
        client.subscribe("simulation")
        print("Subscribed to topic 'simulation'")
    else:
        print(f"Failed to connect with result code {rc}")

# Callback when a message is received from the server
def on_message(client, userdata, msg):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] Topic: {msg.topic}, Message: {msg.payload.decode()}")

# Callback when a message is published
def on_publish(client, userdata, mid):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] Message {mid} published")

# Callback when a message is subscribed
def on_subscribe(client, userdata, mid, granted_qos):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] Subscribed to topic with QoS: {granted_qos}")

def connect_with_retry(client, host, port, max_retries=5, retry_delay=30):
    for attempt in range(max_retries):
        try:
            print(f"Attempting to connect to MQTT broker at {host}:{port} (attempt {attempt + 1}/{max_retries})...")
            client.connect(host, port, 60)
            print("Connection attempt successful!")
            return True
        except Exception as e:
            print(f"Connection attempt {attempt + 1} failed: {str(e)}")
            if attempt < max_retries - 1:
                print(f"Retrying in {retry_delay} seconds...")
                time.sleep(retry_delay)
            else:
                print("Max retries reached. Exiting...")
                return False

def main():
    print("Starting MQTT Reader...")
    # Create MQTT client instance
    client = mqtt.Client()
    
    # Set callbacks
    client.on_connect = on_connect
    client.on_message = on_message
    client.on_publish = on_publish
    client.on_subscribe = on_subscribe
    
    # Enable debug messages
    client.enable_logger()
    
    # Connect to HiveMQ broker using the Docker service name with retry mechanism
    if not connect_with_retry(client, "mqtt_bus", 1883):
        print("Failed to connect to MQTT broker after all retries")
        return
    
    # Start the loop
    client.loop_start()
    print("MQTT Reader started. Press Ctrl+C to exit.")
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nStopping MQTT Reader...")
        client.loop_stop()
        client.disconnect()

if __name__ == "__main__":
    main() 