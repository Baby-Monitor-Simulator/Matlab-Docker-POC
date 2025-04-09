import asyncio
import websockets
import json
import time

async def test_websocket():
    uri = "ws://localhost:8765/ws"
    print(f"Connecting to {uri}...")
    
    try:
        async with websockets.connect(uri) as websocket:
            print("Connected to WebSocket server")
            
            # Test start command
            start_command = {
                "type": "start",
                "script": "sinus.m",
                "params": [5, 0.5, 0, 0.1, 1]  # [amplitude, frequency, start_time, time_step, end_time]
            }
            print(f"Sending start command: {start_command}")
            await websocket.send(json.dumps(start_command))
            
            # Wait for started response
            response = await websocket.recv()
            print(f"Received response: {response}")
            
            # Wait for some data points
            print("Waiting for data points...")
            for i in range(5):  # Get 5 data points
                data = await websocket.recv()
                print(f"Received data point {i+1}: {data}")
                time.sleep(1)  # Wait between points
            
            # Test stop command
            stop_command = {"type": "stop"}
            print(f"Sending stop command: {stop_command}")
            await websocket.send(json.dumps(stop_command))
            
            # Wait for stopped response
            response = await websocket.recv()
            print(f"Received response: {response}")
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    asyncio.get_event_loop().run_until_complete(test_websocket()) 