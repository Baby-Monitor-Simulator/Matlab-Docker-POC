% Add instrument toolbox path
instrumentPath = '/home/matlab/Documents/MATLAB/Add-Ons/instrument';
if exist(instrumentPath, 'dir')
    disp(['Adding Instrument Toolbox path: ' instrumentPath]);
    addpath(genpath(instrumentPath));
else
    error('Instrument directory not found at: %s', instrumentPath);
end

% Additional verification
disp('Checking for TCP/IP functions...');
which tcpserver
which tcpip

try
    % Create TCP/IP server
    server = tcpserver('0.0.0.0', 12345);
    disp('Server created successfully');
    cleanupObj = onCleanup(@() delete(server)); % Ensure server cleanup on script termination
    
    % Keep MATLAB running and listening for connections
    disp('MATLAB server started on port 12345');
    while true
        % Check if client is connected and data is available
        if server.Connected && server.NumBytesAvailable > 0
            data = read(server, server.NumBytesAvailable, "char");
            try
                command = jsondecode(data);
                script_path = command.script;
                params = command.params;
                try
                    % Convert params from cell to array if needed
                    if iscell(params)
                        params = cell2mat(params);
                    end
                    result = feval(script_path(1:end-2), params(1), params(2), params(3), params(4), params(5));
                    
                    % Convert result to JSON and send it back
                    jsonResult = jsonencode(result);
                    write(server, jsonResult, "char");
                    disp(['Sent result back to client: ' jsonResult]);
                catch e
                    disp(['Error executing script: ' e.message]);
                    write(server, jsonencode(struct('error', e.message)), "char");
                end
            catch e
                disp(['Error decoding JSON: ' e.message]);
                write(server, jsonencode(struct('error', e.message)), "char");
            end
        end
        pause(0.1); % Shorter pause for better responsiveness
    end 
catch e
    disp(['Server error: ' e.message]);
end