function mrk = eegLightSensor2Events(data, timestamps, thresh, min_duration)
% takes a vector of EEG data from one channel, and thresholds it to find
% the on/offset of light sensor activity. Extracts onset and produces event
% markers for each. 
%
% data is a double vector of voltages
%
% thresh is the threshold voltage value in µV, above which activation of
% the light sensor is assumed
%
% mrk is a vector of sample indices corresponding to the start of each
% light sensor activation. Note that this function doesn't deal in
% timestamps - these can optionally be used later on if a time vector is
% available, but since not all EEG provides this we restrict ourselves to
% samples here. 
%
% data are quite noisy when the light sensor is on (one example shows a
% range of ~10µV). Currently not attempting to smooth/denoise this, since
% that is likely to shift the onset, and accurate onset is what we care
% about. 

% setup

    % check input
    if ~isnumeric(data) || ~isvector(data)
        error('data must be a numeric vector of voltage values.')
    end
    
    % default threshold is 1000µV
    if ~exist('thresh', 'var') || isempty(thresh)
        thresh = 1000;
    end
    
    % default duration of each light sensor activation is 150ms
    if ~exist('min_duration', 'var') || isempty(min_duration)
        min_duration = 0.150;
    end
    
% normalise voltage

    data = data - min(data(:));
    
% threshold

    % logical index of all samples during which the light sensor was active
    idx = data >= thresh;
    
    % convert to contiguous structure to find on/offsets
    ct = findcontig2(idx);
    
    % remove any activations below minimum duration
    ctt = contig2time(ct, timestamps);
    idx_too_short = ctt(:, 3) < min_duration;
    ct(idx_too_short, :) = [];
    ctt(idx_too_short, :) = [];
    
    %%
    clf
    nsp = numSubplots(50);
    for i = 1:50
        
        subplot(nsp(1), nsp(2), i)
        s1 = ct(i, 1);
        s2 = ct(i, 2);
        
        es1 = s1 - 1000;
        es2 = s2 + 1000;
        if es1 < 1, es1 = 1; end
        if es2 > length(data), es2 = length(data); end
        
        t = timestamps(s1:s2);
        te = timestamps(es1:es2);
        
        plot(te, data(es1:es2))
        hold on
        plot(t, data(s1:s2), 'Color', 'r', 'LineWidth', 2);
        
        mdl = fitlm(t, data(s1:s2)', 'linear');
        title(sprintf('r2 = %.2f, MSE = %.2f, mean res = %.8f', mdl.Rsquared.Ordinary, mdl.MSE, mean(table2array(mdl.Residuals(:, 3)))));
    
    end

    %%
    % we expect light sensor activations to be essentially horizontal lines
    % (since the voltage switches to +5v when the light sensor is on, and
    % 0v when it's off). For each candidate occurrence, calculate the slope
    % of onset to onset + min_duration (default 150ms) and exclude based on
    % slope
    num_events = size(ct, 1);
    for i = 1:num_events
        
        
        
        
        
        
    end
    
    % extract onset
    mrk = ct(:, 1);

end