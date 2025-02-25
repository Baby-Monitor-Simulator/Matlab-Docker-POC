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
│ ├── startup.m
│ └── cosinus.m
| └── sinus.m
├── controller/
│ ├── Dockerfile
│ └── main.py
└── output/
  └── sine_wave.png
``` 

## Configuration

### config.json

The `config.json` file controls the parameters for the MATLAB script execution:

```JSON
{
"script_name": "sinus.m",
"params": [5, 0.5, 0, 0.1, 10]
}
```

Parameters for the sine wave:
- params[0]: Amplitude
- params[1]: Frequency (Hz)
- params[2]: Start time
- params[3]: Time step
- params[4]: End time

## Usage

1. Get your MATLAB username and password ready.

2. Run a MATLAB container.
```BASH
docker run –it --rm –n matlab-container mathworks/matlab:r2024b matlab –licmode onlinelicensing
```
3. Login in the CLI of the running container.

4. Commit the running container to a local image.
```BASH
docker commit matlab-container matlab-login
```
5. Download and extract the Instruments Add-On from MATLAB (zip can be found in teams if needed). The path to the files in the add-on should be in MAIN-DIR/scripts/Add-Ons/instrument.

6. Start the containers:
```BASH
docker-compose up
```

7. The system will:
   - Start the MATLAB server
   - Execute the Python controller
   - Generate a sine wave plot in the `output` directory

## Docker Services

### MATLAB Service
- Container name: `matlab-scripts`
- Ports:
  - `8888:8888` (MATLAB)
  - `12345:12345` (TCP Server)
- Volumes:
  - `./scripts`: MATLAB scripts directory
  - `./scripts/Add-Ons/instrument`: MATLAB Instrument Control Toolbox

### Python Controller
- Container name: `python-controller`
- Volumes:
  - `./output`: Plot output directory
  - `./config.json`: Configuration file

## Adding New MATLAB Scripts

1. Place your MATLAB script in the `scripts` directory
2. Update `config.json` with:
   - Script name
   - Required parameters

## Troubleshooting

1. If MATLAB server doesn't start:
   - Check if port `12345` is available
   - Verify MATLAB license
   - Check Instrument Control Toolbox installation

2. If no plot is generated:
   - Check the `output` directory permissions
   - Verify Python controller logs
   - Check MATLAB server logs

## Notes

- The MATLAB server waits for TCP connections on port 12345
- The Python controller waits 30 seconds for MATLAB to start
- Results are plotted as PNG files in the output directory
- All communication uses JSON format

## Example

Running the default configuration will:
1. Execute sinus.m with default parameters
2. Generate a sine wave
3. Save the plot as 'sinus_plot.png' in the output directory
