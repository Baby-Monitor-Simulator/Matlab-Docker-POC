import socket
import time
import json
import numpy as np # type: ignore
import matplotlib.pyplot as plt # type: ignore
import asyncio
import websockets
import threading
import os
import tempfile
import atexit
import aiohttp
from aiohttp import web
import pathlib

# Global variables to store current parameters and running state
current_params = None
current_script = None
is_running = False
matlab_socket = None
current_figure = None  # Keep track of the current figure
data_file = None  # File to store accumulated data
last_progress_update = 0  # Track last progress update time

def cleanup():
    """Cleanup function to ensure temporary file is removed on exit"""
    global data_file
    if data_file and os.path.exists(data_file.name):
        try:
            data_file.close()
            os.unlink(data_file.name)
        except Exception as e:
            print(f"Error cleaning up temporary file: {e}")

# Register cleanup function
atexit.register(cleanup)

async def websocket_handler(request):
    global current_script, current_params, is_running, matlab_socket
    print("Controller: New WebSocket connection established")
    ws = web.WebSocketResponse()
    await ws.prepare(request)
    
    try:
        async for msg in ws:
            if msg.type == aiohttp.WSMsgType.TEXT:
                print(f"Controller: Received from frontend: {msg.data}")
                data = json.loads(msg.data)
                print(f"Controller: Parsed frontend message: {data}")
                
                if data.get('type') == 'start':
                    current_script = data.get('script', 'sinus.m')
                    current_params = data.get('params')
                    is_running = True
                    print(f"Controller: Starting script {current_script} with params {current_params}")
                    
                    # Start MATLAB communication
                    await send_script_to_matlab(current_script, current_params, ws)
                    
                elif data.get('type') == 'stop':
                    is_running = False
                    if matlab_socket:
                        stop_command = {"type": "stop"}
                        print(f"Controller: Sending stop command to MATLAB: {stop_command}")
                        matlab_socket.send(json.dumps(stop_command).encode())
                    await ws.send_json({'status': 'stopped'})
                    print("Controller: Sent stopped status to frontend")
                    
    except websockets.exceptions.ConnectionClosed:
        print("Controller: WebSocket connection closed")
        is_running = False
    except Exception as e:
        print(f"Controller: WebSocket error: {e}")
    finally:
        return ws

async def init_app():
    app = web.Application()
    app.router.add_get('/ws', websocket_handler)  # WebSocket endpoint
    app.router.add_static('/', pathlib.Path('/app/output'))  # Static files
    return app

async def start_websocket_server():
    app = await init_app()
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, '0.0.0.0', 8765)
    await site.start()
    print("Web server started on http://0.0.0.0:8765")
    await asyncio.Future()  # run forever

def run_websocket_server():
    asyncio.run(start_websocket_server())

def parse_matlab_response(response_data):
    try:
        print(f"Controller: Received from MATLAB: {response_data}")
        result = json.loads(response_data)
        print(f"Controller: Parsed MATLAB response: {result}")
        return result
    except json.JSONDecodeError:
        print(f"Controller: Failed to parse MATLAB response: {response_data}")
        return None

def plot_data(data_file_path, params, script_name):
    global current_figure
    
    # Close the previous figure if it exists
    if current_figure is not None:
        plt.close(current_figure)
    
    # Create a new figure
    current_figure = plt.figure(figsize=(12, 8))
    
    try:
        # Read data from file
        with open(data_file_path, 'r') as f:
            data = [float(line.strip()) for line in f if line.strip()]
        
        print(f"Plotting {len(data)} data points from {data_file_path}")
        
        if not data:
            print("No data found in file!")
            return
        
        # Create time array based on the parameters
        start_time = params[2]
        time_step = params[3]
        end_time = params[4]
        t = np.arange(start_time, end_time + time_step, time_step)
        
        # Ensure we have the same number of points for x and y
        if len(t) > len(data):
            t = t[:len(data)]
        elif len(data) > len(t):
            data = data[:len(t)]
        
        # Plot the results with better styling
        plt.plot(t, data, linewidth=2, color='blue')
        plt.title(f'Real-time {script_name[:-2]} (A={params[0]}, f={params[1]}Hz)', fontsize=14, pad=20)
        plt.xlabel('Time (s)', fontsize=12)
        plt.ylabel('Amplitude', fontsize=12)
        plt.grid(True, linestyle='--', alpha=0.7)
        
        # Add some additional information
        plt.figtext(0.5, 0.01, f'Total points: {len(data)} | Time range: {start_time}s to {end_time}s', 
                   ha='center', fontsize=10, style='italic')
        
        # Adjust layout to prevent text overlap
        plt.tight_layout()
        
        # Save the plot with high DPI for better quality
        plt.savefig(f'/app/output/realtime_plot.png', dpi=300, bbox_inches='tight')
        print(f"Plot saved to /app/output/realtime_plot.png")
        
        # Don't close the figure here, let the caller handle it
    except Exception as e:
        print(f"Error while plotting: {str(e)}")
        if current_figure is not None:
            plt.close(current_figure)
            current_figure = None

async def send_script_to_matlab(script_name, params, ws):
    global matlab_socket
    print("Controller: Waiting for MATLAB to start...")
    time.sleep(30)  # Wait for MATLAB to fully start
    
    try:
        matlab_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        matlab_socket.connect(('matlab_service', 12345))
        print("Controller: Connected to MATLAB successfully")
        
        # Format command for MATLAB
        command = {
            "script": script_name,
            "params": params
        }
        command_json = json.dumps(command)
        
        print(f"Controller: Sending to MATLAB: {command_json}")
        matlab_socket.send(command_json.encode())
        print("Controller: Command sent successfully")
        
        # Keep connection open and process responses
        while True:
            try:
                response = matlab_socket.recv(4096)
                if not response:
                    print("Controller: No response received, connection may be closed")
                    break
                    
                response_data = response.decode()
                result = parse_matlab_response(response_data)
                
                if result is not None:
                    print(f"Controller: Forwarding to frontend: {result}")
                    await ws.send_json(result)
                    print("Controller: Data forwarded to frontend")
                
            except socket.error as e:
                print(f"Controller: Socket error: {e}")
                break
            except Exception as e:
                print(f"Controller: Error processing response: {e}")
                break
            
    except Exception as e:
        print(f"Controller: Error occurred: {str(e)}")
    finally:
        if matlab_socket:
            matlab_socket.close()

if __name__ == "__main__":
    # Load initial parameters from config file
    try:
        with open('/app/config.json', 'r') as f:
            config = json.load(f)
            params = config['params']
            script_name = config['script_name']
    except FileNotFoundError:
        print("Config file not found, using defaults")
        params = [5, 0.5, 0, 0.1, 2]  # [amplitude, frequency, start_time, time_step, end_time]
        script_name = 'sinus.m'
    
    # Start WebSocket server in a separate thread
    websocket_thread = threading.Thread(target=run_websocket_server)
    websocket_thread.daemon = True
    websocket_thread.start()
    
    # Keep the main thread alive
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("Shutting down...")