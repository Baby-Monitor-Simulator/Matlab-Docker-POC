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
3. When prompted, log in with your MATLAB account credentials
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