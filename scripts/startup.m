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
functions_to_check = {'tcpclient', 'tcpserver', 'tcpip', 'write', 'webread', 'webwrite', 'mqttclient'};
for i = 1:numel(functions_to_check)
    func = functions_to_check{i};
    if exist(func, 'file') == 2
        disp(['Found function: ' func]);
    else
        disp(['Not found: ' func]);
    end
end

% Check and add toolbox paths if they are installed
disp('Checking installed toolboxes and adding their paths...');

% Define toolbox paths
icommPath = '/home/matlab/Documents/MATLAB/Add-Ons/icomm';
instrumentPath = '/home/matlab/Documents/MATLAB/Add-Ons/instrument';

% Check for icomm toolbox
if exist(icommPath, 'dir')
    disp(['Found icomm directory at: ' icommPath]);
    disp(['Adding icomm Toolbox path: ' icommPath]);
    addpath(genpath(icommPath));
else
    warning('Icomm directory not found at: %s', icommPath);
end

% Check for instrument toolbox
if exist(instrumentPath, 'dir')
    disp(['Found instrument directory at: ' instrumentPath]);
    disp(['Adding Instrument Toolbox path: ' instrumentPath]);
    addpath(genpath(instrumentPath));
else
    warning('Instrument directory not found at: %s', instrumentPath);
end

% List contents of Add-Ons directory
disp('Contents of Add-Ons directory:');
dir('/home/matlab/Documents/MATLAB/Add-Ons/');

% Final check of communication functions after adding toolbox paths
disp('Final check of communication functions after adding toolbox paths:');
for i = 1:numel(functions_to_check)
    func = functions_to_check{i};
    if exist(func, 'file') == 2
        disp(['Found function: ' func]);
    else
        disp(['Not found: ' func]);
    end
end

% Keep the script running
disp('MATLAB is running. Waiting for further instructions...');
while true
    pause(1);
end