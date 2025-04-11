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
        
        % Check if data is available
        if server.NumBytesAvailable > 0
            % Read data in smaller chunks to prevent message merging
            data = '';
            while server.NumBytesAvailable > 0
                chunk = read(server, 1, "char");
                data = [data chunk];
                
                % Check if we have a complete JSON message
                try
                    % Try to parse the current data as JSON
                    command = jsondecode(data);
                    disp(['MATLAB: Received data: ' data]);
                    disp(['MATLAB: Decoded command: ' jsonencode(command)]);
                    
                    % Handle stop command
                    if isfield(command, 'type') && strcmp(command.type, 'stop')
                        disp('MATLAB: Received stop command');
                        is_running = false;
                        should_stop = true;
                        write(server, jsonencode(struct('status', 'stopped')), "char");
                        break;  % Exit the inner loop after processing a complete message
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
                catch
                    % If JSON parsing fails, continue reading more data
                    continue;
                end
            end
        end
        
        % If we're running and have a script, execute it
        if is_running && ~isempty(current_script) && ~should_stop
            try
                disp(['MATLAB: Executing ' current_script ' with params: ' jsonencode(current_params)]);
                result = feval(current_script(1:end-2), current_params(1), current_params(2), current_params(3), current_params(4), current_params(5), server, should_stop);
                
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
                else
                    disp(['MATLAB: Cycle complete, starting next cycle']);
                end
            catch e
                disp(['MATLAB: Error executing script: ' e.message]);
                write(server, jsonencode(struct('error', e.message)), "char");
                is_running = false;
            end
        end
        
        pause(0.1);
    end 
catch e
    disp(['MATLAB: Server error: ' e.message]);
end