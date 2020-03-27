function [found, mrk_samps, mrk_time, idx_chan] =...
    eegFT_lightSensor2Events(ft_data, thresh)
% attempts to find a channel with light sensor data (voltage values above
% thresh, default 1000µV) and then extracts event markers corresponding to
% the onset of each event. Returns markers as a vector of a) sample indices
% [mrk_samps]; and b) timestamps [mrk_time]. Note that mrk_time is only
% returned if the fieldtrip structure has a .abstime field (which is not
% standard but is used by task engine 2 pipeline functions).
%
% if multiple trials exist in the ft struct, then the output args will be
% cell arrays, with one element being the markers for each trial.
%
% Note that currently abstime is not segmented by trial (so doesn't support
% multiple trials). TODO - fix in future if becomes necessary. Right now
% works fine for raw data. 20190814 LM. 

% setup

    % try to init ft
    try
        ft_defaults
    catch ERR
        error('Error initialising fieldtrip (call to ft_defaults). Fieldtrip may not be in the Matlab path? Error was:\n\n%s',...
            ERR.message)
    end
    
    % default threshold is 1000µV
    if ~exist('thresh', 'var') || isempty(thresh)
        thresh = 1000;
    end

% look for channel

    [anyFound, idx_chan] = eegFT_findLightSensorChannel(ft_data, thresh);
    if ~anyFound
        found = false;
        mrk_samps = [];
        mrk_time = [];
        return
    end
    
% extract markers

    found = true;
    numTrials = length(ft_data.trial);
    mrk_samps = cell(numTrials, 1);
    mrk_time = cell(numTrials, 1);
    for t = 1:numTrials 
        
        % extract light sensor channel
        light = ft_data.trial{t}(idx_chan, :);
        
        % get markers
        mrk_samps{t} = eegLightSensor2Events(light, thresh);
        
        % try to get timestamps
        if isfield(ft_data, 'abstime')
            mrk_time{t} = ft_data.abstime(mrk_samps{t});
        else
            mrk_time{t} = [];
        end
        
    end
    
    % extract from cell array if only one trial
    if numTrials == 1
        mrk_samps = mrk_samps{1};
        mrk_time = mrk_time{1};
    end
        
end