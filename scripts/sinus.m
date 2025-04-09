function result = sinus(a, f, ts, tsp, te)
    disp(['MATLAB: sinus called with params: a=' num2str(a) ', f=' num2str(f) ', ts=' num2str(ts) ', tsp=' num2str(tsp) ', te=' num2str(te)]);
    
    % Calculate number of points
    num_points = floor((te - ts) / tsp) + 1;
    disp(['MATLAB: Calculating ' num2str(num_points) ' points']);
    
    % Generate time points
    T = linspace(ts, te, num_points);
    
    % Calculate sine wave
    y = a * sin(2 * pi * f * T);
    disp(['MATLAB: First few values: ' num2str(y(1:min(5, length(y))))]);
    
    % Return result
    result = y;
    disp('MATLAB: Returning result array');
end