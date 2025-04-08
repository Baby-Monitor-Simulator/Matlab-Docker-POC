% MQTT Startup Script
disp('Starting MQTT initialization...');

% Check if MQTT toolbox is properly initialized
try
    % Try to create a test client to verify MQTT functionality
    disp('Creating test MQTT client...');
    testClient = mqttclient('tcp://mqtt_bus', ClientID="sim-runner", Port=1883);
    disp('MQTT client created successfully');
    
    % Test publishing a message
    disp('Testing message publishing...');
    write(testClient, "test/topic", "Hello from MATLAB!");
    disp('Message published successfully');
    
    % Test subscribing to a topic
    disp('Testing message subscription...');
    subscribe(testClient, "test/topic");
    disp('Subscribed to topic successfully');
    
    % Keep the client running for a while to receive messages
    disp('Waiting for messages (press Ctrl+C to stop)...');
    for i = 1:10
        pause(1);
        % Check for new messages
        if hasdata(testClient)
            msg = read(testClient);
            disp(['Received message: ' msg.Data]);
        end
    end
    
    % Clean up
    disp('Cleaning up...');
    unsubscribe(testClient, "test/topic");
    clear testClient;
    disp('MQTT test completed successfully');
    
catch e
    disp(['MQTT initialization error: ' e.message]);
    disp('Stack trace:');
    disp(getReport(e));
end

% Keep MATLAB running
disp('MQTT startup script completed. MATLAB will continue running...');
while true
    pause(1);
end 