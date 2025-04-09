function result = sinus(a, f, ts, tsp, te)
    try
        % Calculate number of points to prevent array bounds error
        num_points = floor((te - ts) / tsp) + 1;
        if num_points > 1e6  % Limit maximum number of points
            num_points = 1e6;
            tsp = (te - ts) / (num_points - 1);
        end
        
        T = linspace(ts, te, num_points);
        y = a * sin(2 * pi * f * T);
        
        % Convert to array for JSON serialization
        result = double(y);
    catch e
        error('Error in sinus function: %s', e.message);
    end
end