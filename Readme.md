# MATLAB-Python TCP Server

This project sets up a MATLAB TCP server that can execute MATLAB scripts and communicate with a Python controller. The system uses Docker containers for easy deployment and configuration.

## Prerequisites

- Docker
- Docker Compose
- MATLAB license (for the MATLAB container)

## Project Structure

```
├── docker-compose.yml
├── config.json
├── scripts/
│   ├── startup.m
│   ├── sinus.m
│   ├── cosinus.m
│   ├── parameterized_example.m
│   └── Add-Ons/
│       └── instrument/
├── controller/
│   ├── Dockerfile
│   ├── main.py
│   └── test_client.py
└── output/
    ├── index.html
    └── plots/
```

## Quick Start

1. **Set up MATLAB License**:
   ```bash
   # Run MATLAB container
   docker run -it --rm mathworks/matlab:r2024b matlab -n matlab-container -licmode onlinelicensing
   
   # Login in the CLI of the running container
   
   # Commit the container
   docker commit matlab-container matlab-login
   ```

2. **Install Instrument Control Toolbox**:
   - Download and extract the Instruments Add-On from MATLAB
   - Place the files in `scripts/Add-Ons/instrument/`

3. **Start the System**:
   ```bash
   docker-compose up
   ```

4. **Access the Web Interface**:
   - Open your browser and navigate to `http://localhost:8765`
   - The web interface will automatically connect to the WebSocket server

## Web Interface

The project includes a web-based interface for real-time visualization and control of MATLAB scripts. The interface provides:

### Features

1. **Real-time Plotting**:
   - Live updates of MATLAB data
   - Interactive Chart.js visualization
   - Automatic scaling and axis labels

2. **Parameter Control**:
   - Script selection dropdown
   - Parameter input fields
   - Start/Stop/Update controls (stop is a bit buggy for now and requires a matlab service restart)

3. **Connection Status**:
   - Visual indication of WebSocket connection state
   - Automatic reconnection on disconnection

### Usage

1. **Accessing the Interface**:
   - After starting the system, open `http://localhost:8765` in your browser
   - The interface will automatically connect to the WebSocket server

2. **Controlling Scripts**:
   - Select a script from the dropdown menu
   - Adjust parameters using the input fields
   - Use the Start button to begin execution
   - Use Update to modify parameters during execution
   - Use Stop to terminate the script (stop is a bit buggy for now and requires a matlab service restart)

3. **Viewing Results**:
   - Data is plotted in real-time as it's received
   - The plot automatically scales to show all data
   - Points are connected with a smooth line

### Supported Scripts

1. **sinus.m**:
   - Parameters:
     - Amplitude
     - Frequency (Hz)
     - Start Time (s)
     - Time Step (s)
     - End Time (s)

2. **parameterized_example.m**:
   - Parameters:
     - a (quadratic coefficient)
     - b (linear coefficient)
     - c (constant term)

## Configuration

### config.json

The `config.json` file controls the parameters for the MATLAB script execution:

```json
{
    "script_name": "sinus.m",
    "params": [5, 0.5, 0, 0.1, 10]
}
```
It is only used by main.py for default values.

### Available Scripts and Their Parameters

1. **sinus.m**:
   - Parameters: [amplitude, frequency, start_time, time_step, end_time]
   - Example: `[5, 0.5, 0, 0.1, 10]` generates a sine wave with:
     - Amplitude: 5
     - Frequency: 0.5 Hz
     - Time range: 0 to 10 seconds
     - Time step: 0.1 seconds

2. **parameterized_example.m**:
   - Parameters: [a, b, c]
   - Example: `[1, -2, 1]` generates a quadratic function:
     - y = x² - 2x + 1
     - Range: x from -10 to 10

## Using the System

### Starting a Script

1. **Using config.json**:
   - Edit `config.json` with your desired script and parameters
   - Start the system with `docker-compose up`

2. **Using WebSocket API**:
   - Connect to `ws://localhost:8765/ws`
   - Send a start command:
   ```json
   {
       "type": "start",
       "script": "parameterized_example.m",
       "params": [1, -2, 1]
   }
   ```

### Updating Parameters

Send an update command via WebSocket:
```json
{
    "type": "update",
    "params": [2, -4, 2]
}
```

### Stopping a Script

Send a stop command via WebSocket:
```json
{
    "type": "stop"
}
```

## Creating New Scripts

1. Create a new MATLAB function in the `scripts/` directory
2. The function must accept:
   - Required parameters for your calculation
   - A `server` parameter for TCP communication
   - A `should_stop` parameter for graceful termination
3. Example structure:
   ```matlab
   function result = my_script(param1, param2, server, should_stop)
       % Your code here
       % Use server.write() to send data
       % Check should_stop for termination
   end
   ```

## Troubleshooting

1. **MATLAB Server Issues**:
   - Check if port 12345 is available
   - Verify MATLAB license
   - Check Instrument Control Toolbox installation

2. **Plot Generation Issues**:
   - Check `output/` directory permissions
   - Verify Python controller logs
   - Check MATLAB server logs

3. **Connection Issues**:
   - Ensure all containers are running
   - Check network connectivity
   - Verify WebSocket connection

## Development

### Adding New Features

1. **New MATLAB Scripts**:
   - Place in `scripts/` directory
   - Follow parameter pattern
   - Include error handling

2. **Controller Modifications**:
   - Edit `controller/main.py`
   - Update WebSocket handlers
   - Add new plot types

### Testing

1. **Test Client**:
   ```bash
   python controller/test_client.py
   ```

2. **Manual Testing**:
   - Use WebSocket client
   - Monitor logs
   - Check output files

## Notes

- The MATLAB server uses port 12345 for TCP communication
- The Python controller uses port 8765 for WebSocket communication
- All data is sent in JSON format
- Plots are saved in the `output/` directory
- The system supports real-time parameter updates
