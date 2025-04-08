%if exist(comms_path, 'dir')
%    disp("Adding comms path: " + comms_path);
%    %addpath(genpath(comms_path));
%end

client = mqttclient('tcp://mqtt_bus', ClientID="sim-runner", Port=1883);
disp("created writing client");

range = 0:1:1000;
for i = range
    message = "Testing message " + i;
    disp("sending message: " + message);
    write(client, "simulation", message, QualityOfService=2, Retain=true);
    disp("Wrote message to bus")
    pause(1);
end