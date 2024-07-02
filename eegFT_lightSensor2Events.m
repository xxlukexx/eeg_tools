function [found, mrk_samps, mrk_time, idx_chan, ft_data] =...
    eegFT_lightSensor2Events(ft_data, thresh, idx_chan)
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
% returns ft_data with a .event struct containing events in fieldtrip
% format. All values are set to 999. 
%
% Note that currently abstime is not segmented by trial (so doesn't support
% multiple trials). TODO - fix in future if becomes necessary. Right now
% works fine for raw data. 20190814 LM. 

% setup

    need_detection = false;
    found = false;

    % try to init ft
    try
        ft_defaults
    catch ERR
        error('Error initialising fieldtrip (call to ft_defaults). Fieldtrip may not be in the Matlab path? Error was:\n\n%s',...
            ERR.message)
    end
    
    % default threshold is set in eegFT_findLightSensorChannel if passed as
    % empty
    if ~exist('thresh', 'var') 
        thresh = [];
        need_detection = true;
    end
    
    % if a channel containing light sensor data is not specified, we need
    % to detect it
    if ~exist('idx_chan', 'var') 
        idx_chan = [];
        need_detection = true;
    end    
    
    % extract absolute time field if present (ft functions will remove it
    % we need to grab it before they do)
    if isfield(ft_data, 'abstime')
        abstime = ft_data.abstime;
    else
        abstime = [];
    end

% look for channel

    if need_detection
        
        [anyFound, idx_chan, ~, ft_data] =...
            eegFT_findLightSensorChannel(ft_data, thresh);
        
        if ~anyFound
            found = false;
            mrk_samps = [];
            mrk_time = [];
            return
        end
        
    end
    
% extract markers

    found = true;
    numTrials = length(ft_data.trial);
    mrk_samps = cell(numTrials, 1);
    mrk_time = cell(numTrials, 1);
    for t = 1:numTrials 
        
        % extract light sensor channel and timestamps
        light = ft_data.trial{t}(idx_chan, :);
        timestamps = ft_data.time{t};
        
        % get markers
        mrk_samps{t} = eegLightSensor2Events(light, timestamps, thresh);
        
        % try to get timestamps
        if ~isempty(abstime)
            mrk_time{t} = abstime(mrk_samps{t});
        else
            mrk_time{t} = [];
        end
        
    end
    
    % extract from cell array if only one trial
    if numTrials == 1
        mrk_samps = mrk_samps{1};
        mrk_time = mrk_time{1};
    end
    
    % make fieldtrip event struct
    ft_data.event = struct;
    num_events = length(mrk_samps);
    for e = 1:num_events
        ft_data.event(e).sample = mrk_samps(e);
        ft_data.event(e).type = 'light_sensor';
        ft_data.event(e).value = 999;
    end
        
end