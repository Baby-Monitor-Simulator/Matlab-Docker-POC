import socket
import time
import json
import numpy as np # type: ignore
import matplotlib.pyplot as plt # type: ignore

def send_script_to_matlab(script_name, params):
    print("Waiting for MATLAB to start...")
    time.sleep(30)  # Wait for MATLAB to fully start
    
    print("Attempting to connect to MATLAB...")
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.connect(('matlab_service', 12345))
        
        command = {
            "script": script_name,
            "params": params
        }
        
        print(f"Sending command: {command}")
        s.send(json.dumps(command).encode())
        print("Command sent successfully")
        
        # Wait for and print the response
        response = s.recv(4096)
        result = json.loads(response.decode())
        print(f"Received response with {len(result)} data points")
        
        # Create time array based on parameters
        t = np.arange(params[2], params[4] + params[3], params[3])
        
        # Extract base name from script (remove .m extension)
        base_name = script_name.rsplit('.', 1)[0]
        
        # Plot the results
        plt.figure(figsize=(10, 6))
        plt.plot(t, result)
        plt.title(f'Sine Wave (A={params[0]}, f={params[1]}Hz)')
        plt.xlabel('Time (s)')
        plt.ylabel('Amplitude')
        plt.grid(True)
        plt.savefig(f'/app/output/{base_name}_plot.png')
        plt.close()
        
        print(f"Plot saved as {base_name}_plot.png")
        
        s.close()
    except Exception as e:
        print(f"Error occurred: {str(e)}")

if __name__ == "__main__":
    # Example: send testscript with parameters for a sine wave
    # Load parameters from config file
    try:
        with open('/app/config.json', 'r') as f:
            config = json.load(f)
            params = config['params']
            script_name = config['script_name']
    except FileNotFoundError:
        print("Config file not found, using defaults")
        params = [5, 0.5, 0, 0.1, 10]  # [amplitude, frequency, start_time, time_step, end_time]
        script_name = 'sinus.m'
    
    send_script_to_matlab(script_name, params)