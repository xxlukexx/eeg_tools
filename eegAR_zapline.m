function data = eegAR_zapline(data, line_freq)

    % default to removing 50Hz noise
    if ~exist('line_freq', 'var')
        line_freq = 50;
    end

    num_trials = length(data.trial);
    num_channels = length(data.label);
    
    trial = data.trial;
    fs = data.fsample;
    
    for t = 1:num_trials
        for c = 1:num_channels
            trial{t}(c, :) = nt_zapline(trial{t}(c, :)', line_freq / fs)';
        end
    end
    
    data.trial = trial;

end