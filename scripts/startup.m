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
    disp('MATLAB: Waiting for client connection...');
    
    % Initialize variables for continuous operation
    current_script = '';
    current_params = [];
    is_running = false;
    should_stop = false;
    is_updating = false;  % Flag to track update state
    update_pending = false;  % Flag to track pending updates
    
    % Wait for initial connection
    while ~server.Connected
        pause(0.1);
    end
    disp('MATLAB: Client connected');
    
    while true
        % Check if client is connected
        if ~server.Connected
            disp('MATLAB: Client disconnected, waiting for new connection...');
            while ~server.Connected
                pause(0.1);
            end
            disp('MATLAB: New client connected');
            continue;
        end
        
        % Check if data is available before sending new data
        if server.NumBytesAvailable > 0
            disp(['MATLAB: Bytes available: ' num2str(server.NumBytesAvailable)]);
            % Read data in smaller chunks to prevent message merging
            data = '';
            while server.NumBytesAvailable > 0
                try
                    disp('MATLAB: Attempting to read from socket...');
                    % Read a chunk of data instead of single characters
                    chunk = read(server, server.NumBytesAvailable, "char");
                    data = [data chunk];
                    disp(['MATLAB: Read chunk: ' chunk]);
                    
                    % Check if we have a complete JSON message
                    try
                        disp('MATLAB: Attempting to parse JSON...');
                        % Try to parse the current data as JSON
                        command = jsondecode(data);
                        disp(['MATLAB: Received raw data: ' data]);
                        disp(['MATLAB: Decoded command: ' jsonencode(command)]);
                        
                        % Handle stop command
                        if isfield(command, 'type') && strcmp(command.type, 'stop')
                            disp('MATLAB: Received stop command');
                            is_running = false;
                            should_stop = true;
                            write(server, jsonencode(struct('status', 'stopped')), "char");
                            break;  % Exit the inner loop after processing a complete message
                        end
                        
                        % Handle update command
                        if isfield(command, 'type') && strcmp(command.type, 'update')
                            disp('MATLAB: Received update command');
                            disp(['MATLAB: Raw update command: ' jsonencode(command)]);
                            disp(['MATLAB: Update command params: ' jsonencode(command.params)]);
                            if is_running && ~isempty(current_params)
                                update_pending = true;  % Set update pending flag
                                disp(['MATLAB: Current params before update: ' jsonencode(current_params)]);
                                % Update parameters immediately
                                current_params = command.params;
                                disp(['MATLAB: Updated parameters to: ' jsonencode(current_params)]);
                                % Verify the update
                                if ~isequal(current_params, command.params)
                                    disp('MATLAB: WARNING - Parameter update verification failed');
                                    disp(['MATLAB: Expected: ' jsonencode(command.params)]);
                                    disp(['MATLAB: Actual: ' jsonencode(current_params)]);
                                end
                                update_pending = false;  % Clear update pending flag
                                % Set should_stop to true to break the current execution
                                should_stop = true;
                                % Send acknowledgment
                                write(server, jsonencode(struct('status', 'updated')), "char");
                                disp('MATLAB: Sent update acknowledgment');
                                % Don't break here, let the main loop handle the stop
                            else
                                disp('MATLAB: Cannot update - no active session');
                                write(server, jsonencode(struct('error', 'No active session to update')), "char");
                                break;
                            end
                        end
                        
                        % Handle start command or legacy command (without type)
                        if (~isfield(command, 'type') || strcmp(command.type, 'start')) && isfield(command, 'script')
                            current_script = command.script;
                            current_params = command.params;
                            is_running = true;
                            should_stop = false;
                            disp(['MATLAB: Starting continuous execution of ' current_script]);
                            write(server, jsonencode(struct('status', 'started')), "char");
                            break;  % Exit the inner loop after processing a complete message
                        end
                    catch json_error
                        disp(['MATLAB: JSON parsing error: ' json_error.message]);
                        disp(['MATLAB: Failed to parse data: ' data]);
                        disp(['MATLAB: Error stack: ' json_error.stack]);
                        continue;
                    end
                catch read_error
                    disp(['MATLAB: Error reading from socket: ' read_error.message]);
                    disp(['MATLAB: Error stack: ' read_error.stack]);
                    break;
                end
            end
        end
        
        % If we're running and have a script, execute it
        if is_running && ~isempty(current_script) && ~should_stop
            try
                disp(['MATLAB Startup: Executing ' current_script ' with params: ' jsonencode(current_params)]);
                result = feval(current_script(1:end-2), current_params(1), current_params(2), current_params(3), current_params(4), current_params(5), server, should_stop);
                disp(['MATLAB: Result: ' jsonencode(result)]);
                disp(['MATLAB: Result size: ' num2str(size(result))]);
                disp(['MATLAB: Result is numeric: ' num2str(isnumeric(result))]);
                
                % Check if we got new parameters from the script
                if (isequal(size(result), [1 5]) || isequal(size(result), [5 1])) && isnumeric(result)
                    disp(['MATLAB: Received new parameters from script: ' jsonencode(result)]);
                    % Convert to row vector if needed
                    if size(result, 1) > size(result, 2)
                        result = result';
                    end
                    current_params = result;
                    disp(['MATLAB: Updated current_params to: ' jsonencode(current_params)]);
                end
                
                % Check if the script stopped due to server disconnection
                if ~server.Connected
                    disp('MATLAB: Server disconnected, stopping execution');
                    is_running = false;
                    should_stop = true;
                    continue;
                end
                
                if should_stop
                    disp('MATLAB: Script stopped by command');
                    is_running = false;
                    should_stop = false;  % Reset should_stop for next execution
                    continue;  % Continue to next iteration to restart with new parameters
                else
                    disp(['MATLAB: Cycle complete, starting next cycle']);
                    % Add a longer pause between cycles to allow for message processing
                    pause(0.5);
                end
            catch e
                disp(['MATLAB: Error executing script: ' e.message]);
                write(server, jsonencode(struct('error', e.message)), "char");
                is_running = false;
            end
        else
            % If not running, add a small pause to prevent CPU spinning
            pause(0.1);
        end
    end 
catch e
    disp(['MATLAB: Server error: ' e.message]);
end