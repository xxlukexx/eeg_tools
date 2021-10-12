function [anyFound, idx_chan, reason, ft_data] = eegFT_findLightSensorChannel(ft_data, thresh)
% attempts to find the channel containing light sensor data. Simple
% approach is to look for voltage values that regularly exceed a certain
% threshold - by default 1000µV (although 5000µV is more usual). Can be set
% with the thresh input arg. 

    reason = 'unknown error';

    try
        ft_defaults
    catch ERR
        error('Error initialising fieldtrip (call to ft_defaults). Fieldtrip may not be in the Matlab path? Error was:\n\n%s',...
            ERR.message)
    end
    
    % default threshold is 1000µV
    if ~exist('thresh', 'var') || isempty(thresh)
        thresh = 500;
    end
    
    % preprocess data
    cfg = [];
    cfg.hpfilt = 'yes';
    cfg.hpfreq = 1;
    cfg.detrend = 'yes';
    cfg.demean = 'yes';
    ft_data = ft_preprocessing(cfg, ft_data);
    
    % set minimum number of contiguous samples above threshold that we
    % consider to be indicative of a light sensor turning on 
    min_time = 0.015;
    min_samps = min_time * ft_data.fsample;
    
    % put all trials into one long matrix
    numTrials = length(ft_data.trial);
    if numTrials == 1
        data = ft_data.trial{1};
    else
        data = horzcat(ft_data.trial{:});
    end
    
    % loop through channels...
    numChan = size(data, 1);
    found = zeros(numChan, 1);
    for c = 1:numChan
        
        % threshold and find runs
        idx = data(c, :) >= thresh;
        ct = findcontig2(idx);
        
        % if not voltages above threshold, move to next channel
        if isempty(ct)
            continue
        end
        
        % remove runs below minimum duration
        idx_tooShort = ct(:, 3) < min_samps;
        ct(idx_tooShort, :) = [];
        
        % count number of runs left
        found(c) = length(ct);

    end
    
    % check at last one channel had some runs
    anyFound = ~all(found == 0);
    if anyFound
        % find channel with most runs
        idx_chan = found == max(found);
    else
        idx_chan = false(numChan, 1);
    end
    
end