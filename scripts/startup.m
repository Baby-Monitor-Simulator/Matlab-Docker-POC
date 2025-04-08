% Verify Paho library installation
disp('Verifying Paho library installation...');
[status, cmdout] = system('ldconfig -p | grep paho');
disp(['Library check status: ' num2str(status)]);
disp(['Library check output: ' cmdout]);

% Set up environment variables
disp('Setting up environment variables...');
setenv('LD_LIBRARY_PATH', ['/opt/matlab/R2024b/toolbox/icomm/mqtt/mqtt/bin/glnxa64:/opt/matlab/R2024b/bin/glnxa64:' getenv('LD_LIBRARY_PATH')]);

% Verify LD_LIBRARY_PATH
disp('Current LD_LIBRARY_PATH:');
disp(getenv('LD_LIBRARY_PATH'));

% Verify library files exist
disp('Checking for required library files...');
mqttLibPath = '/opt/matlab/R2024b/toolbox/icomm/mqtt/mqtt/bin/glnxa64';
if exist(fullfile(mqttLibPath, 'libmwmqttdevice.so'), 'file')
    disp('Found libmwmqttdevice.so');
else
    disp('Missing libmwmqttdevice.so');
end

if exist(fullfile(mqttLibPath, 'libmwmqttconverter.so'), 'file')
    disp('Found libmwmqttconverter.so');
else
    disp('Missing libmwmqttconverter.so');
end

% List available toolboxes
disp('Listing available toolboxes...');
toolboxes = matlab.addons.toolbox.installedToolboxes;
disp('Available toolboxes:');
for i = 1:numel(toolboxes)
    disp([num2str(i) '. ' toolboxes(i).Name]);
end

% Debug: Show structure of toolboxes
disp('Toolbox structure:');
disp(toolboxes);

% Check available communication functions
disp('Checking available communication functions...');
functions_to_check = {'tcpclient', 'tcpserver', 'tcpip', 'webread', 'webwrite', 'mqttclient'};
for i = 1:numel(functions_to_check)
    func = functions_to_check{i};
    if exist(func, 'file') == 2 || exist(func, 'file') == 6
        disp(['Found function: ' func]);
    else
        disp(['Not found: ' func]);
    end
end

% Check and add toolbox paths if they are installed
disp('Checking installed toolboxes and adding their paths...');

% Define toolbox paths
commonPath = '/opt/matlab/R2024b/toolbox';
icommPath = fullfile(commonPath, 'icomm');
instrumentPath = fullfile(commonPath, 'instrument');

% Check for icomm toolbox
if exist(icommPath, 'dir')
    addpath(genpath(icommPath));
else
    warning('Icomm directory not found at: %s', icommPath);
end

% Check for instrument toolbox
if exist(instrumentPath, 'dir')
    addpath(genpath(instrumentPath));
else
    warning('Instrument directory not found at: %s', instrumentPath);
end

% Add scripts directory and all subdirectories to path
scriptsPath = '/home/matlab/Documents/MATLAB/scripts';
addpath(genpath(scriptsPath));
disp(['Added to path: ' scriptsPath]);

% List contents of Add-Ons directory
disp('Contents of Add-Ons directory:');
dir(commonPath);

% Final check of communication functions after adding toolbox paths
disp('Final check of communication functions after adding toolbox paths:');
for i = 1:numel(functions_to_check)
    func = functions_to_check{i};
    if exist(func, 'file') == 2 || exist(func, 'file') == 6
        disp(['Found function: ' func]);
    else
        disp(['Not found: ' func]);
    end
end

% Keep MATLAB running
disp('Environment setup completed. Running MQTT startup script...');

% Run the MQTT startup script
run('/home/matlab/Documents/MATLAB/scripts/mqtt_startup.m');