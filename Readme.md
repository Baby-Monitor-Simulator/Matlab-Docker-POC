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
   docker run -it --name matlab-container --rm mathworks/matlab:r2024b matlab -licmode onlinelicensing
   
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
       "params": [130, 95, 10, 120, 80]
   }
   ```

### Updating Parameters

Send an update command via WebSocket:
```json
{
    "type": "update",
    "params": [100, 95, 10, 150, 80]
}
```

### Stopping a Script

Send a stop command via WebSocket:
```json
{
    "type": "stop"
}
```

## Creating New Scripts (recommended is to do it from parameterized script)

1. Create a new MATLAB function in the `scripts/` directory
2. The function must accept:
   - Required parameters for your calculation
   - A `server` parameter for TCP communication
   - A `should_stop` parameter for graceful termination
3. Example structure:
   ```matlab
   function result = my_script(param1, param2, server, should_stop)
      [scriptDir, ~, ~] = fileparts(mfilename('fullpath'));
    
      utilsDir = fullfile(scriptDir, 'utils');
      if ~contains(path, scriptDir)
        addpath(scriptDir);
      end
      if ~contains(path, utilsDir)
        addpath(utilsDir);
      end
       % Your code here
       % Use `send_message(server, struct, 'name')` to send data, make sure you only use this once every cycle and just add multiple vars to the struct
       % Check should_stop for termination `[should_stop, new_params] = check_messages(server);`
   end
   ```

## Implementing a Parameterized Script

Here's a step-by-step guide to implement a parameterized script like `parameterized_example.m`:

1. **Create the Function Structure**:
   ```matlab
   function result = my_parameterized_script(param1, param2, param3, server, should_stop)
       % Initialize result structure
       result = struct();
       
       try
           % Your implementation here
           
       catch ME
           % Error handling
           result.success = false;
           result.error = ME.message;
           server.write(jsonencode(result));
       end
   end
   ```

2. **Add Data Generation**:
   ```matlab
   % Inside the try block
   % Generate x values
   x = linspace(-10, 10, 100);
   
   % Calculate y values using parameters
   y = param1 * x.^2 + param2 * x + param3;
   ```

3. **Create Plot Data Structure**:
   ```matlab
   % Create the data structure for plotting
   plot_data = struct();
   plot_data.x = x;
   plot_data.y = y;
   ```

4. **Send Data to Server**:
   ```matlab
   % Send the data to the web interface
   server.write(jsonencode(plot_data));
   ```

5. **Store Results**:
   ```matlab
   % Store the results in the result structure
   result.success = true;
   result.data = plot_data;
   ```

6. **Complete Example**:
   ```matlab
   function result = my_parameterized_script(param1, param2, param3, server, should_stop)
       % Initialize result structure
       result = struct();
       
       try
           % Generate x values
           x = linspace(-10, 10, 100);
           
           % Calculate y values using parameters
           y = param1 * x.^2 + param2 * x + param3;
           
           % Create plot data structure
           plot_data = struct();
           plot_data.x = x;
           plot_data.y = y;
           
           % Send data to server
           server.write(jsonencode(plot_data));
           
           % Store results
           result.success = true;
           result.data = plot_data;
           
       catch ME
           % Error handling
           result.success = false;
           result.error = ME.message;
           server.write(jsonencode(result));
       end
   end
   ```

7. **Adding Your Script to the Frontend**:
   - Open `output/index.html` in your code editor
   - Locate the script configuration object (look for the script definitions)
   - Add your script configuration:
   ```javascript
   'my_parameterized_script.m': {
       name: 'My Script Name',
       params: [
           { name: 'param1', label: 'Parameter 1 Label', value: 1, step: 0.1 },
           { name: 'param2', label: 'Parameter 2 Label', value: -2, step: 0.1 },
           { name: 'param3', label: 'Parameter 3 Label', value: 1, step: 0.1 }
       ]
   }
   ```

8. **Testing Your Implementation**:
   1. Save the script in the `scripts/` directory
   2. Make sure your script is added in the frontend (step 7)
   3. Start the system with `docker-compose up`
   4. Access the web interface at `http://localhost:8765/index.html`
   5. Select your script from the dropdown
   6. Test with different parameter values
   7. Verify the plot updates in real-time

   8. The configuration includes:
      - `name`: Display name for your script in the dropdown
      - `params`: Array of parameter configurations, each with:
         - `name`: Parameter identifier (used in the backend)
         - `value`: Default value for the parameter

9. **Common Modifications**:
   - Change the x-axis range by modifying `linspace` parameters
   - Add more parameters for complex calculations
   - Implement different mathematical functions
   - Add multiple data series to the plot
   - Include additional metadata in the plot_data structure


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
- The system supports real-time parameter updates
