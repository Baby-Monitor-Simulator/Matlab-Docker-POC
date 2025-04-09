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
    
    % Initialize variables for continuous operation
    current_script = '';
    current_params = [];
    is_running = false;
    
    while true
        % Check if client is connected and data is available
        if server.Connected && server.NumBytesAvailable > 0
            data = read(server, server.NumBytesAvailable, "char");
            try
                % Try to decode the JSON data
                command = jsondecode(data);
                
                % Handle stop command
                if isfield(command, 'type') && strcmp(command.type, 'stop')
                    is_running = false;
                    write(server, jsonencode(struct('status', 'stopped')), "char");
                    continue;
                end
                
                % Extract script and parameters
                script_path = command.script;
                params = command.params;
                
                % Update current script and parameters
                current_script = script_path;
                current_params = params;
                is_running = true;
                
                try
                    % Convert params from cell to array if needed
                    if iscell(params)
                        params = cell2mat(params);
                    end
                    
                    % Execute the script with current parameters
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
                disp(['Raw data received: ' data]);
                write(server, jsonencode(struct('error', ['JSON decode error: ' e.message])), "char");
            end
        end
        
        % If we have a current script and parameters, keep generating data
        if is_running && ~isempty(current_script) && ~isempty(current_params)
            try
                % Convert params from cell to array if needed
                if iscell(current_params)
                    params = cell2mat(current_params);
                else
                    params = current_params;
                end
                
                % Execute the script with current parameters
                result = feval(current_script(1:end-2), params(1), params(2), params(3), params(4), params(5));
                
                % Check if client is still connected before sending
                if ~server.Connected
                    disp('Client disconnected, waiting for reconnection...');
                    pause(1);  % Wait 1 second before checking again
                    continue;
                end
                
                % Try to send data with retry mechanism
                max_retries = 150;
                retry_count = 0;
                while retry_count < max_retries
                    try
                        % Convert result to JSON and send it back
                        jsonResult = jsonencode(result);
                        write(server, jsonResult, "char");
                        break;  % If successful, exit retry loop
                    catch e
                        retry_count = retry_count + 1;
                        if retry_count < max_retries
                            disp(['Send attempt ' num2str(retry_count) ' failed: ' e.message]);
                            pause(0.5);  % Wait before retrying
                        else
                            disp(['Failed to send data after ' num2str(max_retries) ' attempts: ' e.message]);
                            is_running = false;  % Stop continuous execution
                            break;
                        end
                    end
                end
            catch e
                disp(['Error in continuous execution: ' e.message]);
                pause(2);  % Add delay before retrying on error
            end
        end
        
        pause(0.1); % Shorter pause for better responsiveness
    end 
catch e
    disp(['Server error: ' e.message]);
end