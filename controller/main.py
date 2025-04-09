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
    global current_script, current_params, is_running, data_file, matlab_socket
    print("New WebSocket connection established")
    ws = web.WebSocketResponse()
    await ws.prepare(request)
    
    try:
        async for msg in ws:
            print(f"Received WebSocket message: {msg.data}")
            if msg.type == aiohttp.WSMsgType.TEXT:
                data = json.loads(msg.data)
                print(f"Parsed message data: {data}")
                
                if data.get('type') == 'start':
                    print("Handling start command")
                    current_script = data.get('script', 'sinus.m')
                    current_params = data.get('params')
                    is_running = True
                    if data_file:
                        print("Cleaning up previous data file")
                        cleanup()
                    data_file = tempfile.NamedTemporaryFile(mode='w+', delete=False)
                    print(f"Created new data file: {data_file.name}")
                    
                    response = {'status': 'started', 'script': current_script}
                    print(f"Sending response: {response}")
                    await ws.send_json(response)

                    # Start MATLAB communication
                    await send_script_to_matlab(current_script, current_params, ws)
                    
                    
                elif data.get('type') == 'update':
                    print("Handling update command")
                    if 'script' in data:
                        current_script = data['script']
                    if 'params' in data:
                        current_params = data['params']
                    response = {'status': 'updated', 'script': current_script}
                    print(f"Sending response: {response}")
                    await ws.send_json(response)
                elif data.get('type') == 'stop':
                    print("Handling stop command")
                    is_running = False
                    if matlab_socket:
                        print("Sending stop command to MATLAB")
                        stop_command = {"type": "stop"}
                        matlab_socket.send(json.dumps(stop_command).encode())
                    response = {'status': 'stopped'}
                    print(f"Sending response: {response}")
                    await ws.send_json(response)
                elif data.get('type') == 'list_scripts':
                    print("Handling list_scripts command")
                    script_dir = '/app/scripts'
                    scripts = [f for f in os.listdir(script_dir) if f.endswith('.m')]
                    response = {'type': 'script_list', 'scripts': scripts}
                    print(f"Sending response: {response}")
                    await ws.send_json(response)
    except websockets.exceptions.ConnectionClosed:
        print("WebSocket connection closed")
        is_running = False
    except Exception as e:
        print(f"WebSocket error: {e}")
    finally:
        print("WebSocket handler completed")
        return ws  # Don't close the connection

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
        # First try to decode as a status or error message
        try:
            msg = json.loads(response_data)
            if isinstance(msg, dict):
                if 'status' in msg:
                    return msg
                elif 'error' in msg:
                    print(f"MATLAB Error: {msg['error']}")
                    return {'status': 'error', 'message': msg['error']}
        except json.JSONDecodeError:
            pass

        # If not a status/error message, try to parse as data
        # Remove any extra brackets and split into individual arrays
        clean_data = response_data.strip('[]')
        
        # Split on ][ but preserve the brackets
        parts = []
        current_part = []
        for char in clean_data:
            if char == ']' and current_part and current_part[-1] == '[':
                # Found a ][ split
                parts.append(''.join(current_part[:-1]))  # Remove the last [
                current_part = ['[']  # Start new part with [
            else:
                current_part.append(char)
        if current_part:
            parts.append(''.join(current_part))
        
        # Parse each array and combine the results
        all_data = []
        for part in parts:
            try:
                # Add brackets if needed
                if not part.startswith('['):
                    part = '[' + part
                if not part.endswith(']'):
                    part = part + ']'
                data = json.loads(part)
                if isinstance(data, list):
                    all_data.extend(data)
            except json.JSONDecodeError:
                # If JSON parsing fails, try to extract numbers directly
                numbers = []
                current_num = ''
                for char in part:
                    if char in '0123456789.-':
                        current_num += char
                    elif current_num:
                        try:
                            numbers.append(float(current_num))
                            current_num = ''
                        except ValueError:
                            current_num = ''
                if current_num:
                    try:
                        numbers.append(float(current_num))
                    except ValueError:
                        pass
                if numbers:
                    all_data.extend(numbers)
        
        return all_data if all_data else None
    except Exception as e:
        print(f"Error parsing MATLAB response: {e}")
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
        
        # Create time array based on the length of the data
        t = np.linspace(params[2], params[4], len(data))
        
        # Plot the results with better styling
        plt.plot(t, data, linewidth=2, color='blue')
        plt.title(f'Real-time {script_name[:-2]} (A={params[0]}, f={params[1]}Hz)', fontsize=14, pad=20)
        plt.xlabel('Time (s)', fontsize=12)
        plt.ylabel('Amplitude', fontsize=12)
        plt.grid(True, linestyle='--', alpha=0.7)
        
        # Add some additional information
        plt.figtext(0.5, 0.01, f'Total points: {len(data)} | Time range: {params[2]}s to {params[4]}s', 
                   ha='center', fontsize=10, style='italic')
        
        # Adjust layout to prevent text overlap
        plt.tight_layout()
        
        # Save the plot with high DPI for better quality
        plt.savefig(f'/app/output/realtime_plot.png', dpi=300, bbox_inches='tight')
        print(f"Plot saved to /app/output/realtime_plot.png")
        plt.close(current_figure)
        current_figure = None
    except Exception as e:
        print(f"Error while plotting: {str(e)}")

async def send_script_to_matlab(script_name, params, ws):
    global matlab_socket, current_script, current_params, current_figure, data_file, last_progress_update
    print("Waiting for MATLAB to start...")
    time.sleep(30)  # Wait for MATLAB to fully start
    
    print("Attempting to connect to MATLAB...")
    received_data = False  # Initialize the variable
    plot_generated = False  # Initialize the variable
    data_count = 0  # Initialize the variable
    auto_plot_timer = time.time()  # Initialize the variable
    current_time = params[2]  # Initialize current time with start_time
    
    try:
        matlab_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        matlab_socket.connect(('matlab_service', 12345))
        print("Connected to MATLAB successfully")
        
        # Format command for MATLAB
        command = {
            "script": script_name,
            "params": params
        }
        command_json = json.dumps(command)
        
        print(f"Sending command: {command_json}")
        matlab_socket.send(command_json.encode())
        print("Command sent successfully")
        
        # Send started message to WebSocket client
        await ws.send_json({'status': 'started', 'script': script_name})
        print("Sent started message to WebSocket client")
        
        # Keep connection open and process responses
        while True:
            try:
                response = matlab_socket.recv(4096)
                if not response:
                    print("No response received, connection may be closed")
                    break
                    
                response_data = response.decode()
                print(f"Received response: {response_data[:100]}...")  # Print first 100 chars of response
                result = parse_matlab_response(response_data)
                
                if result is None:
                    print("Failed to parse response")
                    continue
                    
                if isinstance(result, dict):
                    if result.get('status') == 'error':
                        print(f"MATLAB Error: {result.get('message', 'Unknown error')}")
                        break
                    if result.get('status') == 'stopped':
                        print("MATLAB stopped")
                        break
                    continue
                    
                if isinstance(result, list):
                    received_data = True
                    
                    # Create data points with x and y coordinates
                    data_points = []
                    for y in result:
                        data_points.append({
                            'x': current_time,
                            'y': y
                        })
                        current_time += params[3]  # Increment by time_step
                    
                    # Write data points to file
                    if data_file:
                        with open(data_file.name, 'a') as f:
                            for point in data_points:
                                f.write(f"{point['x']},{point['y']}\n")
                                data_count += 1
                        print(f"Added {len(data_points)} data points to file")
                    
                    # Forward data to WebSocket client
                    try:
                        await ws.send_json(data_points)
                        print(f"Forwarded {len(data_points)} data points to WebSocket client")
                    except Exception as e:
                        print(f"Error forwarding data to WebSocket client: {e}")
                    
                    # Generate plot periodically
                    if time.time() - auto_plot_timer > 5 and data_file and os.path.exists(data_file.name) and data_count > 0 and not plot_generated:
                        print("Generating plot")
                        plot_data(data_file.name, params, script_name)
                        plot_generated = True
                        auto_plot_timer = time.time()
                
            except socket.error as e:
                print(f"Socket error: {e}")
                break
            except Exception as e:
                print(f"Error processing response: {e}")
                break
            
    except Exception as e:
        print(f"Error occurred: {str(e)}")
    finally:
        # Only plot if we haven't already generated one
        if received_data and data_file and os.path.exists(data_file.name) and not plot_generated:
            try:
                plot_data(data_file.name, params, script_name)
            except Exception as e:
                print(f"Failed to generate final plot: {str(e)}")
        
        if matlab_socket:
            matlab_socket.close()
        if current_figure is not None:
            plt.close(current_figure)

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