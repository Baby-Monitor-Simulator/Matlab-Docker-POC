# Simple Installation Guide for the Fetal-Maternal Physiology Model

This guide will help you set up and run the Fetal-Maternal Physiology Model, even if you're not familiar with technical concepts.

## Step 1: Install Docker

1. Go to [Docker's website](https://www.docker.com/products/docker-desktop/)
2. Click on "Download for Windows"
3. Run the downloaded installer
4. Follow the installation wizard's instructions
5. Restart your computer when prompted

## Step 2: Set Up MATLAB Docker Image

1. Open Command Prompt (search for "cmd" in the Start menu)
2. Run the following command to start MATLAB:
   ```
   docker run -it --name matlab-container --rm mathworks/matlab:r2024b matlab -licmode onlinelicensing
   ```
3. When prompted, log in with your MATLAB account credentials. Don't close the window yet, as it is needed during step 4.
4. After logging in, open a new Command Prompt window (cmd like step 1) and run:
   ```
   docker commit matlab-container matlab-login
   ```
5. Wait for the command to complete - this creates a new image with your login credentials

## Step 3: Install MATLAB Add-ons

1. Go to Microsoft Teams and download the MATLAB add-on ZIP files
2. Extract all the downloaded ZIP files
3. Copy all the extracted files into the `scripts/Add-Ons/instrument/` folder in your project directory
   - If the `Add-Ons` folder doesn't exist, create it first
   - The final structure should look like this:
     ```
     scripts/
     └── Add-Ons/
         └── icomm/
             └── apps/
             └── *more files*
         └── instrument/
             └── apps/
             └── *more files*
         └── signal/
             └── deep/
             └── *more files*
         └── stats/
             └── anomaly/
             └── *more files*
         └── symbolic/
             └── graphics/
             └── *more files*
     ```

## Step 4: Download the Project

1. Go to [GitHub](https://github.com/Baby-Monitor-Simulator/Matlab-Docker-POC)
2. Click the green "Code" button
3. Click "Download ZIP"
4. Extract the downloaded ZIP file to a location of your choice (e.g., Desktop)

## Step 5: Start the Application

1. Open Docker Desktop (you can find it in your Start menu)
2. Wait until Docker Desktop shows "Docker is running" in the bottom left corner
3. Open Command Prompt (search for "cmd" in the Start menu)
4. Navigate to the extracted folder using the `cd` command. For example:
   ```
   cd Desktop\Matlab-Docker-POC
   ```
5. Type the following command and press Enter:
   ```
   docker-compose up
   ```
6. Wait until you see messages indicating that the services are running

## Step 6: Access the Web Interface

1. Open your web browser (Chrome, Firefox, or Edge)
2. Go to: `http://localhost:8765/index.html`
3. You should see the web interface with controls for the model

## Customizing the Model Data

The model can display different types of data. To change what data is shown:

1. Open the file `scripts/production/FMPmodel.m` in a text editor or MATLAB
2. Look for line 385 (or nearby) where you'll see a section that looks like this:
   ```matlab
   FMP_data = struct('mother', mother, ...
                    'fTvs', fTvs);
   ```
3. You can modify this section to include different data. For example, to show more information, you can add more fields like this:
   ```matlab
   FMP_data = struct('mother', mother, ...
                    'fTvs', fTvs, ...
                    'heartRate', heartRate, ...
                    'oxygen', oxygen, ...
                    'bloodPressure', bloodPressure);
   ```
4. After making changes, save the file and restart the application:
   - In the Command Prompt window where the application is running, press Ctrl+C to stop it
   - Type `docker-compose down` and press Enter
   - Wait until you see messages like `removed`
   - Type `docker-compose up` and press Enter
   - Wait until you see messages like `started 5.0s`

## Troubleshooting

If you encounter any issues:

1. Make sure Docker Desktop is running
2. Try closing and reopening Docker Desktop
3. If the web interface doesn't load, try refreshing your browser
4. If you see error messages in the Command Prompt, try running `docker-compose down` followed by `docker-compose up`
5. If you see MATLAB license errors, make sure you completed Step 2 correctly
6. If you see add-on related errors, make sure you completed Step 3 correctly

## Need Help?

If you need assistance:
1. Check if your question is answered in this guide
2. Contact the fontys student team
3. Make sure to include any error messages you see in your request for help 

# Endpoints

## 1. WebSocket Endpoint (Controller Layer)

### **Endpoint**: `ws://localhost:8765/ws`
**Location**: `controller/main.py` (lines 30-180)
**Purpose**: Main interface for frontend applications to control MATLAB simulations
**Message Types**:

#### **Start Command**
```json
{
    "type": "start",
    "script": "sinus.m",
    "params": [5, 0.5, 0, 0.1, 2]
}
```
- **Purpose**: Initiates a new MATLAB simulation
- **Parameters**: 
  - `script`: MATLAB function name (e.g., "sinus.m", "parameterized_example.m")
  - `params`: Array of parameters specific to the script
- **Response**: `{"status": "started"}`

#### **Update Command**
```json
{
    "type": "update",
    "params": [10, 1.0, 0, 0.1, 10]
}
```
- **Purpose**: Updates parameters of running simulation
- **Parameters**: New parameter array
- **Response**: `{"status": "updated"}` or `{"error": "message"}`

#### **Stop Command**
```json
{
    "type": "stop"
}
```
- **Purpose**: Stops current simulation
- **Response**: `{"status": "stopped"}`

## 2. TCP/IP Endpoint (MATLAB Communication)

### **Endpoint**: `tcp://matlab_service:12345`

**Location**: `scripts/startup.m` (lines 30-153)

**Purpose**: Direct communication between Python controller and MATLAB service

**Message Types**:

#### **Start Command**
```json
{
    "type": "start",
    "script": "sinus.m",
    "params": [5, 0.5, 0, 0.1, 2]
}
```
- **Purpose**: Tells MATLAB which script to execute
- **Response**: `{"status": "started"}`

#### **Update Command**
```json
{
    "type": "update",
    "params": [10, 1.0, 0, 0.1, 10]
}
```
- **Purpose**: Sends new parameters to running MATLAB script
- **Response**: `{"status": "updated"}`

#### **Stop Command**
```json
{
    "type": "stop"
}
```
- **Purpose**: Stops MATLAB execution
- **Response**: `{"status": "stopped", "reason": "command"}`

## 3. MATLAB Script Endpoints

### **Available Scripts**:

#### **sinus.m** (Basic Sine Wave Generator)
```matlab
function result = sinus(a, f, ts, tsp, te, server, should_stop)
```
- **Parameters**: `[amplitude, frequency, start_time, time_step, end_time]`
- **Output**: Real-time sine wave data chunks
- **Data Format**: Numeric arrays sent as JSON

#### **parameterized_example.m** (Vital Signs Simulator)
```matlab
function result = parameterized_example(heart_rate, oxygen_level, num_cycles, systolic_bp, diastolic_bp, server, should_stop)
```
- **Parameters**: `[heart_rate, oxygen_level, num_cycles, systolic_bp, diastolic_bp]`
- **Output**: Vital signs data as structured objects
- **Data Format**: 
```json
{
    "oxygen_level": 95.2,
    "heart_rate": 130.5,
    "systolic_bp": 120.1,
    "diastolic_bp": 80.3
}
```

#### **FMPmodel.m** (Complex Medical Model)
```matlab
function result = FMPmodel(vMother, vUterus, vFoetus, vUmbilical, vBrain, vCAVmodel, vScen, vHES, vPersen, vDuty, vNCycleMax, vLamb, server, should_stop)
```
- **Parameters**: 13 medical simulation parameters
- **Purpose**: Advanced fetal-maternal physiology simulation

## 4. Communication Flow

```
Frontend → WebSocket (8765) → Python Controller → TCP/IP (12345) → MATLAB Service
```

### **Detailed Flow Example**:

1. **Frontend sends start command**:
   ```json
   {"type": "start", "script": "sinus.m", "params": [5, 0.5, 0, 0.1, 2]}
   ```

2. **Python controller processes** (`main.py` lines 60-90):
   - Connects to MATLAB via TCP/IP
   - Sends command to MATLAB
   - Forwards response to frontend

3. **MATLAB receives** (`startup.m` lines 70-85):
   - Parses JSON command
   - Executes specified script
   - Sends acknowledgment

4. **MATLAB script runs** (`sinus.m` lines 40-80):
   - Generates data in chunks
   - Sends real-time data via `send_message()`
   - Checks for stop/update commands

5. **Data flows back**:
   - MATLAB → TCP/IP → Python → WebSocket → Frontend

## 5. Utility Functions in MatLab

### **check_messages.m** (Message Handler)
```matlab
function [should_stop, new_params, script_info] = check_messages(server)
```
- **Purpose**: Processes incoming commands from Python controller
- **Returns**: Stop flag, new parameters, script information

### **send_message.m** (Data Sender)
```matlab
function success = send_message(server, message, message_type)
```
- **Purpose**: Sends data back to Python controller
- **Formats**: JSON encoding of MATLAB data
