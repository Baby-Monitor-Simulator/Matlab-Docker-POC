% Add instrument toolbox path
instrumentPath = '/home/matlab/Documents/MATLAB/Add-Ons/instrument';
if exist(instrumentPath, 'dir')
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
    disp('MATLAB: Server created successfully');
    cleanupObj = onCleanup(@() delete(server));
    
    % Keep MATLAB running and listening for connections
    disp('MATLAB: Server started on port 12345');
    
    while true
        % Check if client is connected and data is available
        if server.Connected && server.NumBytesAvailable > 0
            data = read(server, server.NumBytesAvailable, "char");
            disp(['MATLAB: Received data: ' data]);
            
            try
                % Decode the JSON data
                command = jsondecode(data);
                disp(['MATLAB: Decoded command: ' jsonencode(command)]);
                
                % Handle stop command
                if isfield(command, 'type') && strcmp(command.type, 'stop')
                    disp('MATLAB: Received stop command');
                    write(server, jsonencode(struct('status', 'stopped')), "char");
                    continue;
                end
                
                % Extract parameters from the command
                params = command.params;
                disp(['MATLAB: Extracted params: ' jsonencode(params)]);
                
                % Execute the script with parameters
                disp(['MATLAB: Executing ' command.script ' with params: ' jsonencode(params)]);
                result = feval(command.script(1:end-2), params(1), params(2), params(3), params(4), params(5));
                disp(['MATLAB: Calculated result: ' jsonencode(result)]);
                
                % Send result back
                write(server, jsonencode(result), "char");
                disp('MATLAB: Sent result back to controller');
                
            catch e
                disp(['MATLAB: Error: ' e.message]);
                write(server, jsonencode(struct('error', e.message)), "char");
            end
        end
        
        pause(0.1);
    end 
catch e
    disp(['MATLAB: Server error: ' e.message]);
end