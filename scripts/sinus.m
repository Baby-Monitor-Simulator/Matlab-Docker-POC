function result = sinus(a, f, ts, tsp, te, server, should_stop)
    % Log received parameters
    disp(['MATLAB: sinus received parameters: a=' num2str(a) ', f=' num2str(f) ', ts=' num2str(ts) ', tsp=' num2str(tsp) ', te=' num2str(te)]);
    
    % Calculate number of points
    num_points = floor((te - ts) / tsp) + 1;
    disp(['MATLAB: Calculating ' num2str(num_points) ' points']);
    
    % Generate time points
    T = linspace(ts, te, num_points);
    
    % Calculate in chunks of 100 points
    chunk_size = 100;
    result = [];
    
    % Continuous loop until server disconnects or should_stop is true
    while true
        % Check if we should stop
        if should_stop || ~server.Connected
            disp('MATLAB: Received stop signal or server disconnected, stopping calculation');
            break;
        end
        
        % Reset result for this cycle
        result = [];
        
        for i = 1:chunk_size:num_points
            % Check if we should stop
            if should_stop || ~server.Connected
                disp('MATLAB: Received stop signal or server disconnected, stopping calculation');
                break;
            end
            
            % Calculate end index for this chunk
            end_idx = min(i + chunk_size - 1, num_points);
            
            % Calculate sine wave for this chunk
            chunk_T = T(i:end_idx);
            chunk_y = a * sin(2 * pi * f * chunk_T);
            
            % Add to result
            result = [result, chunk_y];
            
            % Send this chunk to the server
            if server.Connected
                try
                    % Check if there are any pending commands
                    if server.NumBytesAvailable > 0
                        % Read and process the command
                        data = read(server, server.NumBytesAvailable, "char");
                        try
                            command = jsondecode(data);
                            if isfield(command, 'type')
                                if strcmp(command.type, 'update')
                                    disp('MATLAB: Update command received, pausing data sending');
                                    % Process update directly
                                    disp(['MATLAB: Processing update with params: ' jsonencode(command.params)]);
                                    % Set should_stop to true first
                                    should_stop = true;
                                    % Return the new parameters
                                    result = command.params;
                                    % Send acknowledgment
                                    write(server, jsonencode(struct('status', 'updated')), "char");
                                    disp('MATLAB: Sent update acknowledgment');
                                    return;
                                elseif strcmp(command.type, 'stop')
                                    disp('MATLAB: Stop command received');
                                    should_stop = true;
                                    return;
                                end
                            end
                        catch
                            disp('MATLAB: Error parsing command, continuing');
                            continue;
                        end
                    end
                    
                    write(server, jsonencode(chunk_y), "char");
                    disp(['MATLAB: Sent chunk of ' num2str(length(chunk_y)) ' points']);
                catch e
                    disp(['MATLAB: Error sending chunk: ' e.message]);
                    break;
                end
            else
                disp('MATLAB: Server disconnected, stopping calculation');
                break;
            end
            
            % Add a small pause between chunks to allow for message processing
            pause(0.05);
        end
        
        if should_stop || ~server.Connected
            break;
        end
        
        disp(['MATLAB: First few values: ' num2str(result(1:min(5, length(result))))]);
        disp('MATLAB: Cycle complete, starting next cycle');
        
        % Add a longer delay between cycles
        pause(0.2);
    end
    
    disp('MATLAB: Continuous calculation stopped');
end