% Add instrument toolbox path
instrumentPath = '/home/matlab/Documents/MATLAB/Add-Ons/instrument';
if exist(instrumentPath, 'dir')
    addpath(genpath(instrumentPath));
else
    error('Instrument directory not found at: %s', instrumentPath);
end

% Additional verification
disp('Checking for TCP/IP functions...');
tcpserverPath = which('tcpserver');
tcpipPath = which('tcpip');

if ~isempty(tcpserverPath) && ~isempty(tcpipPath)
    fprintf('tcpserver and tcpip both exist.\n');
else
    if ~isempty(tcpserverPath)
        fprintf('tcpserver exists.\n');
    end
    if ~isempty(tcpipPath)
        fprintf('tcpip exists.\n');
    end
end


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
                    
                    % Process complete JSON messages
                    while ~isempty(data)
                        % Find the first complete JSON message
                        [json_str, data] = extract_json_message(data);
                        
                        if isempty(json_str)
                            % No complete message found, wait for more data
                            break;
                        end
                        
                        try
                            disp('MATLAB: Attempting to parse JSON...');
                            % Try to parse the current data as JSON
                            command = jsondecode(json_str);
                            disp(['MATLAB: Received raw data: ' json_str]);
                            disp(['MATLAB: Decoded command: ' jsonencode(command)]);
                            
                            % Handle stop command
                            if isfield(command, 'type') && strcmp(command.type, 'stop')
                                disp('MATLAB: Received stop command');
                                is_running = false;
                                should_stop = true;
                                % Send acknowledgment with stop reason
                                write(server, jsonencode(struct('status', 'stopped', 'reason', 'command')), "char");
                                disp('MATLAB: Sent stop acknowledgment (command)');
                                % Don't break here, let the main loop handle the stop
                                continue;
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
                            disp(['MATLAB: Failed to parse data: ' json_str]);
                            disp(['MATLAB: Error stack: ' json_error.stack]);
                            % Remove the problematic message and continue
                            data = '';
                            break;
                        end
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

                % Convert params to a cell array in case it isn't already
                if ~iscell(current_params)
                    current_params = num2cell(current_params);
                end

                % Force current_params to be a 1xN row cell array
                current_params = reshape(current_params, 1, []);
                
                % Safely concatenate the function arguments
                all_args = [current_params, {server}, {should_stop}];
                
                % Execute the script
                result = feval(current_script(1:end-2), all_args{:});
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
                    % Send final message indicating disconnect
                    if server.Connected
                        write(server, jsonencode(struct('status', 'stopped', 'reason', 'disconnect')), "char");
                        disp('MATLAB: Sent stop acknowledgment (disconnect)');
                    end
                    continue;
                end
                
                if should_stop
                    disp('MATLAB: Script stopped by command');
                    is_running = false;
                    should_stop = false;  % Reset should_stop for next execution
                    % Add a small delay to ensure acknowledgment is sent
                    pause(0.1);
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

function [json_str, remaining] = extract_json_message(data)
    % EXTRACT_JSON_MESSAGE Extract a complete JSON message from the input data
    %   [json_str, remaining] = extract_json_message(data) extracts the first
    %   complete JSON message from the input data and returns the remaining data.
    %
    %   Input:
    %       data - string containing JSON messages
    %
    %   Output:
    %       json_str - first complete JSON message, empty if none found
    %       remaining - remaining data after extracting the message
    
    json_str = '';
    remaining = data;
    
    % Find the first complete JSON message
    start_idx = strfind(data, '{');
    if isempty(start_idx)
        return;
    end
    
    % Try to find a complete JSON message
    for i = 1:length(start_idx)
        try
            % Try to parse from this position
            json_str = data(start_idx(i):end);
            jsondecode(json_str);  % This will throw an error if not valid JSON
            % If we get here, we found a valid JSON message
            remaining = data(1:start_idx(i)-1);
            return;
        catch
            % Not a complete message, continue searching
            continue;
        end
    end
    
    % No complete message found
    json_str = '';
    remaining = data;
end