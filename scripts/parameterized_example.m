function result = parameterized_example(heart_rate, oxygen_level, num_cycles, server, should_stop)
    % Get the directory where this script is located
    [scriptDir, ~, ~] = fileparts(mfilename('fullpath'));
    
    % Add the script directory and utils directory to the MATLAB path if not already there
    utilsDir = fullfile(scriptDir, 'utils');
    if ~contains(path, scriptDir)
        addpath(scriptDir);
    end
    if ~contains(path, utilsDir)
        addpath(utilsDir);
    end
    
    % PARAMETERIZED_EXAMPLE Simulate vital signs during birth
    %   This function simulates a series of heartbeats and calculates
    %   various vital signs for each heartbeat cycle.
    %
    %   Input:
    %       heart_rate - beats per minute
    %       oxygen_level - blood oxygen saturation percentage
    %       num_cycles - number of heartbeat cycles to simulate
    %       server - TCP/IP server connection
    %       should_stop - boolean to indicate if calculation should stop
    %
    %   Output:
    %       result - final parameters if updated, empty otherwise
    
    % Log received parameters
    disp(['MATLAB: Starting simulation with heart_rate=' num2str(heart_rate) ...
          ', oxygen_level=' num2str(oxygen_level) ...
          ', num_cycles=' num2str(num_cycles)]);
    
    % Calculate time per cycle (in seconds)
    cycle_time = 60 / heart_rate;
    
    % Main simulation loop for each heartbeat cycle
    for cycle = 1:num_cycles
        % Check if we should stop
        if should_stop || ~server.Connected
            disp('MATLAB: Received stop signal or server disconnected');
            break;
        end
        
        % Log current cycle
        disp(['MATLAB: Processing heartbeat cycle ' num2str(cycle) ' of ' num2str(num_cycles)]);
        
        % Calculate oxygen levels (simplified)
        current_oxygen = oxygen_level + randn(1) * 2;  % Add some random variation
        current_oxygen = max(0, min(100, current_oxygen));  % Keep within valid range
        
        % Send the oxygen level directly as a numeric value
        send_message(server, current_oxygen, 'vital signs data');
        
        % Check for messages and process commands
        [should_stop, new_params] = check_messages(server);
        
        % If we received new parameters, send acknowledgment and return them
        if ~isempty(new_params)
            send_message(server, struct('status', 'updated'), 'update acknowledgment');
            result = new_params;
            return;
        end
        
        % Check if we should stop
        if should_stop || ~server.Connected
            disp('MATLAB: Received stop signal or server disconnected');
            break;
        end
        
        %result = current_oxygen;
        % Wait for next cycle (simulating real-time)
        pause(cycle_time);
    end
    
    disp('MATLAB: Simulation complete');
end 