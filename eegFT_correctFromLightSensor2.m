function [data_ft_corr, smry, event_table] =...
    eegFT_correctFromLightSensor2(data_ft, wanted_events, tolerance_secs, threshold_uv)

    % if specific wanted-events not specified, assume we want all of them
    if ~exist('wanted_events', 'var') 
        wanted_events = [];
    end
    
    % tolerance is how close the light sensor needs to be to an event to be
    % used for correction. Default is 70ms. 
    if ~exist('tolerance_secs', 'var') || isempty(tolerance_secs)
        tolerance_secs = 0.070;
        warning('No light sensor - event tolerance (tolerance_secs) was set, defaulting to %.3fs', tolerance_secs)
    end
    
    % get tolerance in samples
    tolerance_samps = round(tolerance_secs * data_ft.fsample);
    
    % default threshold for light sensor activation is 4000µV 
    if ~exist('threshold_uv', 'var') || isempty(threshold_uv)
        threshold_uv = 4000;
    end
    
% find light sensor channel and extract its data

    [~, idx_ls, ~, data_ls_preproc] = eegFT_findLightSensorChannel(data_ft);
    ls = data_ls_preproc.trial{1}(idx_ls, :);
    
% preprocess events for speed

    % convert struct array to table
    tab = struct2table(data_ft.events);
    
    % optionally mark which events are wanted
    if ~isempty(wanted_events)
        tab.wanted = ismember(tab.value, wanted_events);
    end
        
    % preallocate storage
    num_events = size(tab, 1);
    tab.was_corrected = false(num_events, 1);
    tab.sample_uncorrected = tab.sample;
    tab.correction_samps = zeros(num_events, 1);
    tab.correction_secs = zeros(num_events, 1);
    
% loop through events and look for light sensor marker 

    num_events = length(data_ft.events);
    for e = 1:num_events
        
        % if not a wanted event, skip
        if ~tab.wanted(e), continue, end
        
        % define edges of light sensor search space, based on tolerance 
        marker_samp = tab.sample_uncorrected(e);
        s1 = marker_samp;
        s2 = marker_samp + tolerance_samps;
        
        % get ls data for this period and zero it
        data = ls(s1:s2);
        data = data - min(data(:));
        
%         clf, plot([s1:s2], data), hold on, scatter(marker_samp, 1e3, [], 'diamond')
%         title(sprintf('corr_samps = %d | corr_ms = %.1f', tab.correction_samps(e), tab.correction_secs(e) * 1000))
%         pause        
        
        % threshold to find onset
        ct = findcontig2(data >= threshold_uv);
        if isempty(ct), continue, end
        
        onset_samps = marker_samp + ct(1, 1);
        
        % store
        tab.was_corrected(e) = true;
        tab.correction_samps(e) = ct(1, 1);
        tab.correction_secs(e) = tab.correction_samps(e) / data_ft.fsample;
        

        
    end
    
% prepare summary

    smry = struct;
    smry.num_wanted = sum(tab.wanted);
    smry.num_corrected = sum(tab.was_corrected);
    smry.prop_corrected = smry.num_corrected / smry.num_wanted;
    tab_corr = tab(tab.was_corrected, :);
    smry.fsample = data_ft.fsample;
    smry.tolerance_secs = tolerance_secs;
    smry.tolerance_samps = tolerance_samps;
    smry.min_correction_secs = min(tab_corr.correction_secs);
    smry.max_correction_secs = max(tab_corr.correction_secs);
    smry.mean_correction_secs = mean(tab_corr.correction_secs);
    smry.sd_correction_secs = std(tab_corr.correction_secs);
    
% store corrections

    data_ft_corr = data_ft;
    data_ft_corr.events = table2struct(tab(:, {'sample', 'type', 'value'}));
    event_table = tab;

end