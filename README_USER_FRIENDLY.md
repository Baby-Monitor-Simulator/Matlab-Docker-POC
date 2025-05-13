# Simple Installation Guide for the Fetal-Maternal Physiology Model

This guide will help you set up and run the Fetal-Maternal Physiology Model, even if you're not familiar with technical concepts.

## Step 1: Install Docker

1. Go to [Docker's website](https://www.docker.com/products/docker-desktop/)
2. Click on "Download for Windows"
3. Run the downloaded installer
4. Follow the installation wizard's instructions
5. Restart your computer when prompted

## Step 2: Download the Project

1. Go to [GitHub](https://github.com/Baby-Monitor-Simulator/Matlab-Docker-POC)
2. Click the green "Code" button
3. Click "Download ZIP"
4. Extract the downloaded ZIP file to a location of your choice (e.g., Desktop)

## Step 3: Start the Application

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

## Step 4: Access the Web Interface

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

## Need Help?

If you need assistance:
1. Check if your question is answered in this guide
2. Contact the technical support team
3. Make sure to include any error messages you see in your request for help 