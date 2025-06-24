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
should_stop = False  # Flag to control MATLAB execution

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
    global current_script, current_params, is_running, matlab_socket, should_stop
    print("Controller: New WebSocket connection established")
    ws = web.WebSocketResponse()
    await ws.prepare(request)
    print("Controller: WebSocket connection prepared")
    
    try:
        print("Controller: WebSocket connection prepared, waiting for messages")
        async for msg in ws:
            print(f"Controller: WebSocket message received, type: {msg.type}")
            if msg.type == aiohttp.WSMsgType.TEXT:
                print(f"Controller: Received WebSocket message: {msg.data}")
                try:
                    data = json.loads(msg.data)
                    print(f"Controller: Parsed WebSocket message: {data}")
                    
                    if data.get('type') == 'start':
                        print("Controller: Processing start command")
                        # Reset state for new run
                        if matlab_socket:
                            print("Controller: Closing existing MATLAB socket")
                            try:
                                stop_command = {"type": "stop"}
                                print(f"Controller: Sending stop command to MATLAB: {stop_command}")
                                matlab_socket.send(json.dumps(stop_command).encode())
                                print("Controller: Stop command sent to MATLAB")
                                
                                # Wait for MATLAB to acknowledge the stop
                                print("Controller: Waiting for MATLAB stop acknowledgment")
                                response = matlab_socket.recv(4096).decode()
                                print(f"Controller: Received MATLAB response: {response}")
                                
                                try:
                                    response_data = json.loads(response)
                                    print(f"Controller: Parsed MATLAB response: {response_data}")
                                    if isinstance(response_data, dict) and response_data.get('status') == 'stopped':
                                        print("Controller: MATLAB acknowledged stop command")
                                    else:
                                        print("Controller: Unexpected MATLAB response to stop command")
                                except json.JSONDecodeError:
                                    print(f"Controller: Error decoding MATLAB response: {response}")
                            except Exception as e:
                                print(f"Controller: Error sending stop command: {e}")
                            finally:
                                print("Controller: Closing MATLAB socket")
                                matlab_socket.close()
                                matlab_socket = None
                                # Add a small delay to ensure socket is fully closed
                                await asyncio.sleep(0.5)
                        
                        current_script = data.get('script', 'sinus.m')
                        current_params = data.get('params')
                        is_running = True
                        should_stop = False
                        print(f"Controller: Starting script {current_script} with params {current_params}")
                        
                        # Send started status to frontend
                        print("Controller: Sending started status to frontend")
                        await ws.send_json({'status': 'started'})
                        
                        # Start MATLAB communication in a separate task
                        print("Controller: Creating MATLAB communication task")
                        asyncio.create_task(send_script_to_matlab(current_script, current_params, ws))
                        
                    elif data.get('type') == 'stop':
                        print("Controller: Processing stop command")
                        should_stop = True
                        if matlab_socket:
                            try:
                                stop_command = {"type": "stop"}
                                print(f"Controller: Sending stop command to MATLAB: {stop_command}")
                                matlab_socket.send(json.dumps(stop_command).encode())
                                print("Controller: Stop command sent to MATLAB")
                                
                                # Wait for MATLAB to acknowledge the stop with timeout
                                print("Controller: Waiting for MATLAB stop acknowledgment")
                                start_time = time.time()
                                timeout = 5.0  # 5 second timeout
                                
                                while time.time() - start_time < timeout:
                                    try:
                                        response = matlab_socket.recv(4096).decode()
                                        if response:
                                            print(f"Controller: Received MATLAB response: {response}")
                                            try:
                                                response_data = json.loads(response)
                                                print(f"Controller: Parsed MATLAB response: {response_data}")
                                                if isinstance(response_data, dict) and response_data.get('status') == 'stopped':
                                                    print("Controller: MATLAB acknowledged stop command")
                                                    break
                                                else:
                                                    print("Controller: Unexpected MATLAB response to stop command")
                                            except json.JSONDecodeError:
                                                print(f"Controller: Error decoding MATLAB response: {response}")
                                    except BlockingIOError:
                                        # No data available yet, sleep briefly
                                        await asyncio.sleep(0.1)
                                        continue
                                    except Exception as e:
                                        print(f"Controller: Error reading MATLAB response: {e}")
                                        break
                                
                                if time.time() - start_time >= timeout:
                                    print("Controller: Timeout waiting for MATLAB stop acknowledgment")
                            except Exception as e:
                                print(f"Controller: Error sending stop command: {e}")
                            finally:
                                print("Controller: Closing MATLAB socket")
                                matlab_socket.close()
                                matlab_socket = None
                        else:
                            print("Controller: No active MATLAB socket to stop")
                        
                        # Update state
                        is_running = False
                        should_stop = False

                        # Add a small delay to ensure socket is fully closed
                        await asyncio.sleep(0.5)
                        
                        # Send stopped status to frontend
                        print("Controller: Sending stopped status to frontend")
                        await ws.send_json({'status': 'stopped'})
                    elif data.get('type') == 'update':
                        print("Controller: Processing update command")
                        if matlab_socket and is_running:
                            # Create a separate task for the update
                            asyncio.create_task(send_update_to_matlab(matlab_socket, data.get('params'), ws))
                        else:
                            print("Controller: No active MATLAB session to update")
                            await ws.send_json({'error': 'No active session to update'})
                    else:
                        print(f"Controller: Unknown message type: {data.get('type')}")
                except json.JSONDecodeError as e:
                    print(f"Controller: Error decoding WebSocket message: {e}")
                    print(f"Controller: Raw message: {msg.data}")
                except Exception as e:
                    print(f"Controller: Error processing WebSocket message: {e}")
            elif msg.type == aiohttp.WSMsgType.ERROR:
                print(f"Controller: WebSocket error: {msg.data}")
            elif msg.type == aiohttp.WSMsgType.CLOSED:
                print("Controller: WebSocket connection closed")
            elif msg.type == aiohttp.WSMsgType.CLOSING:
                print("Controller: WebSocket connection closing")
            else:
                print(f"Controller: Unhandled WebSocket message type: {msg.type}")
                    
    except websockets.exceptions.ConnectionClosed:
        print("Controller: WebSocket connection closed")
        is_running = False
        should_stop = True
    except Exception as e:
        print(f"Controller: WebSocket error: {e}")
    finally:
        if matlab_socket:
            print("Controller: Cleaning up MATLAB socket in WebSocket handler")
            matlab_socket.close()
            matlab_socket = None
        return ws

async def init_app():
    app = web.Application()
    app.router.add_get('/ws', websocket_handler)  # WebSocket endpoint
    app.router.add_static('/', pathlib.Path('/app/output'))  # Static files
    print("Controller: WebSocket routes configured")
    return app

async def start_websocket_server():
    app = await init_app()
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, '0.0.0.0', 8765)
    await site.start()
    print("Controller: Web server started on http://0.0.0.0:8765")
    print("Controller: Waiting for WebSocket connections...")
    await asyncio.Future()  # run forever

def run_websocket_server():
    print("Controller: Starting WebSocket server...")
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
    """Send a script to MATLAB and get the response"""
    global matlab_socket, should_stop
    try:
        print("Controller: Connecting to MATLAB service")
        # Connect to MATLAB
        matlab_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        matlab_socket.connect(('matlab_service', 12345))
        matlab_socket.setblocking(False)  # Make socket non-blocking
        print("Controller: Connected to MATLAB service")
        
        # Prepare the command
        command = {
            'type': 'start',
            'script': script_name,
            'params': params
        }
        
        # Send the command
        print(f"Controller: Sending command to MATLAB: {command}")
        matlab_socket.send(json.dumps(command).encode())
        print("Controller: Command sent to MATLAB")
        
        # Process responses
        while not should_stop:
            try:
                # Try to read response with timeout
                response = matlab_socket.recv(4096).decode()
                if not response:
                    print("Controller: No response received from MATLAB")
                    break
                    
                try:
                    print(f"Controller: Received from MATLAB: {response}")
                    # First try to parse as numeric value
                    try:
                        data = float(response)
                        print(f"Controller: Parsed MATLAB response as numeric: {data}")
                        # Forward to WebSocket client
                        await ws.send_json(data)
                        print("Controller: Data forwarded successfully")
                        continue
                    except ValueError:
                        # If not numeric, try to parse as JSON
                        try:
                            data = json.loads(response)
                            print(f"Controller: Parsed MATLAB response as JSON: {data}")
                            
                            # Check if it's a final result or incremental data
                            if isinstance(data, dict) and 'error' in data:
                                print(f"Controller: MATLAB error: {data['error']}")
                                await ws.send_json({'error': data['error']})
                                raise Exception(f"MATLAB error: {data['error']}")
                            elif isinstance(data, dict) and 'status' in data:
                                print(f"Controller: MATLAB status: {data['status']}")
                                await ws.send_json(data)
                                if data['status'] == 'stopped':
                                    print("Controller: Received stopped status from MATLAB")
                                    break
                                elif data['status'] == 'completed':
                                    print("Controller: Received completed status from MATLAB")
                                    break
                            elif isinstance(data, dict) and 'name' in data and 'value' in data:
                                # Handle named variable data
                                print(f"Controller: Received named variable: {data['name']} = {data['value']}")
                                await ws.send_json(data)
                            elif isinstance(data, dict):
                                # Handle dictionary data with direct key-value pairs
                                print(f"Controller: Received dictionary data: {data}")
                                await ws.send_json(data)
                                print("Controller: Dictionary data forwarded successfully")
                            elif isinstance(data, list):
                                print(f"Controller: Received {len(data)} data points from MATLAB")
                                # Write data points to file
                                with open('data_points.txt', 'a') as f:
                                    for point in data:
                                        f.write(f"{point}\n")
                                
                                # Forward to WebSocket client
                                print("Controller: Forwarding data to WebSocket client")
                                await ws.send_json(data)
                                print("Controller: Data forwarded successfully")
                        except json.JSONDecodeError:
                            print(f"Controller: Could not parse MATLAB response: {response}")
                            continue
                except Exception as e:
                    print(f"Controller: Error in MATLAB communication: {e}")
                    break
            except BlockingIOError:
                # No data available, sleep briefly and continue
                await asyncio.sleep(0.1)
                continue
            except Exception as e:
                print(f"Controller: Error in MATLAB communication: {e}")
                break
                
    except Exception as e:
        print(f"Controller: Error in send_script_to_matlab: {str(e)}")
        try:
            await ws.send_json({'error': str(e)})
        except Exception as ws_error:
            print(f"Controller: Error sending error to WebSocket: {ws_error}")
    finally:
        if matlab_socket:
            print("Controller: Cleaning up MATLAB socket in send_script_to_matlab")
            matlab_socket.close()
            matlab_socket = None
        is_running = False
        should_stop = False

async def send_update_to_matlab(matlab_socket, params, ws):
    """Send update command to MATLAB in a separate task"""
    try:
        update_command = {
            'type': 'update',
            'params': params
        }
        print(f"Controller: Sending update command to MATLAB: {update_command}")
        
        # Send the command
        matlab_socket.send(json.dumps(update_command).encode())
        print("Controller: Update command sent to MATLAB")
        
        # Wait for acknowledgment with timeout
        print("Controller: Waiting for MATLAB update acknowledgment")
        start_time = time.time()
        timeout = 5.0  # 5 second timeout
        acknowledgment_received = False
        
        while time.time() - start_time < timeout and not acknowledgment_received:
            try:
                response = matlab_socket.recv(4096).decode()
                if response:
                    print(f"Controller: Received MATLAB response: {response}")
                    try:
                        response_data = json.loads(response)
                        if isinstance(response_data, dict):
                            if response_data.get('status') == 'updated':
                                print("Controller: MATLAB acknowledged update command")
                                acknowledgment_received = True
                                await ws.send_json({'status': 'updated'})
                                break
                            elif response_data.get('error'):
                                print(f"Controller: MATLAB error: {response_data.get('error')}")
                                await ws.send_json({'error': response_data.get('error')})
                                break
                        else:
                            # If we receive data points, continue waiting for acknowledgment
                            print("Controller: Received data points while waiting for acknowledgment, continuing to wait")
                            continue
                    except json.JSONDecodeError:
                        print(f"Controller: Error decoding MATLAB response: {response}")
                        continue
            except BlockingIOError:
                # No data available yet, sleep briefly
                await asyncio.sleep(0.1)
                continue
            except Exception as e:
                print(f"Controller: Error reading MATLAB response: {e}")
                await ws.send_json({'error': str(e)})
                break
        
        if not acknowledgment_received:
            print("Controller: Timeout waiting for MATLAB update acknowledgment")
            await ws.send_json({'error': 'Timeout waiting for MATLAB response'})
    except Exception as e:
        print(f"Controller: Error in update task: {e}")
        await ws.send_json({'error': str(e)})

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