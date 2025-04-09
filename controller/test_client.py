import asyncio
import websockets
import json
import time
import sys

async def test_client():
    uri = "ws://localhost:8765"
    try:
        print("Connecting to WebSocket server...")
        async with websockets.connect(uri) as websocket:
            print("Connected successfully!")
            
            # First command: Start with initial parameters
            start_command = {
                "type": "start",
                "script": "sinus.m",
                "params": [5, 0.5, 0, 0.1, 1]  # [amplitude, frequency, start_time, time_step, end_time]
            }
            print("\n1. Starting with sine wave:")
            print(f"   Amplitude: {start_command['params'][0]}")
            print(f"   Frequency: {start_command['params'][1]} Hz")
            await websocket.send(json.dumps(start_command))
            response = await websocket.recv()
            print(f"   Response: {response}")
            
            # Wait 5 seconds
            print("\nWaiting 5 seconds...")
            for i in range(5, 0, -1):
                print(f"   {i}...", end='\r')
                time.sleep(1)
            print("   Continuing...")
            
            # Second command: Update parameters
            update_command1 = {
                "type": "update",
                "params": [10, 1.0, 0, 0.1, 10]  # Double amplitude and frequency
            }
            print("\n2. Updating parameters:")
            print(f"   New Amplitude: {update_command1['params'][0]}")
            print(f"   New Frequency: {update_command1['params'][1]} Hz")
            await websocket.send(json.dumps(update_command1))
            response = await websocket.recv()
            print(f"   Response: {response}")
            
            # Wait 5 seconds
            print("\nWaiting 5 seconds...")
            for i in range(5, 0, -1):
                print(f"   {i}...", end='\r')
                time.sleep(1)
            print("   Continuing...")
            
            # Third command: Update parameters and switch to cosine
            update_command2 = {
                "type": "update",
                "script": "cosinus.m",
                "params": [15, 2.0, 0, 0.1, 10]  # Triple amplitude and quadruple frequency
            }
            print("\n3. Switching to cosine and updating parameters:")
            print(f"   New Script: {update_command2['script']}")
            print(f"   New Amplitude: {update_command2['params'][0]}")
            print(f"   New Frequency: {update_command2['params'][1]} Hz")
            await websocket.send(json.dumps(update_command2))
            response = await websocket.recv()
            print(f"   Response: {response}")
            
            # Wait 5 seconds
            print("\nWaiting 5 seconds...")
            for i in range(5, 0, -1):
                print(f"   {i}...", end='\r')
                time.sleep(1)
            print("   Continuing...")
            
            # Final command: Stop
            stop_command = {
                "type": "stop"
            }
            print("\n4. Stopping the generation...")
            await websocket.send(json.dumps(stop_command))
            response = await websocket.recv()
            print(f"   Response: {response}")
            
            print("\nTest completed successfully!")
            
    except ConnectionRefusedError:
        print("\nError: Could not connect to the WebSocket server.")
        print("Make sure the main system is running with 'docker-compose up -d'")
        sys.exit(1)
    except Exception as e:
        print(f"\nError: {e}")
        sys.exit(1)

if __name__ == "__main__":
    print("Starting test client...")
    asyncio.run(test_client()) 