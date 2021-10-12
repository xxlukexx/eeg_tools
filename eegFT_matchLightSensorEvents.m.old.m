function out = eegFT_matchLightSensorEvents(data_ft, thresh, tol)

    out = struct;
    out.found = false;
    
    % default threshold is 1000µV
    if ~exist('thresh', 'var') || isempty(thresh)
        thresh = 1000;
    end

    % 100ms default tolerance
    if ~exist('tol', 'var') || isempty(tol)
        tol_s = 0.100;
        tol = tol_s * data_ft.fsample;
    end
    
    idx = [];
    [lightChannelFound, mrk_light, mrk_light_s, idx_chan] = eegFT_lightSensor2Events(data_ft, thresh);
    if ~lightChannelFound, return, end
    
    ev = [data_ft.events.sample]';
    
    numLight = length(mrk_light);
    idx = nan(numLight, 1);
    err = nan(numLight, 1);
    for l = 1:numLight
        
        % find nearest event sample to light sensor
        delta = mrk_light(l) - ev;
        idx_match = abs(delta) <= tol;
        
        % if nothing return, we cannot match
        if ~any(idx_match)
            continue
        elseif sum(idx_match) > 1
            % more than one event matches, take the one with the lowest
            % delta
            lowestDelta = min(abs(delta(idx_match)));
            idx_match = idx_match & abs(delta) == lowestDelta;
            % since we have been using the absolute delta to find the
            % nearest event, it's possible to have an even evenly spaced
            % either side. In this case the abs value is the same. On the
            % basis that screen refresh should come after event, take the
            % more positive of the two
            if sum(idx_match) > 1 && any(delta(idx_match) < 0)
                idx_match = idx_match & delta >= 1;
            end
        end
        
        if sum(idx_match) == 1
            idx(l) = find(idx_match, 1);
            err(l) = delta(idx_match);
        else
            error('Matching failed for weird reason - debug')
        end
        
    end
    
    err = err / data_ft.fsample;
    
    out.found = lightChannelFound;
    out.threshold = thresh;
    out.tolerance_secs = tol_s;
    out.tolerance_samps = tol;
    out.lightChannelFound = lightChannelFound;
    out.lightChannelIdx = idx_chan;
    out.lightChannelLabel = data_ft.label{idx_chan}; 
    out.mrk_light_samps = mrk_light;
    out.mrk_light_secs = mrk_light_s;
    out.mrk_ft_idx = idx;
    out.error = err;
    
% find sample indices and labels for each ft event that is matched to a
% light marker

    % get indices of found markers (we can only do a lookup in the ft event
    % data for these)
    idx_wasFound = ~isnan(idx);
    
    % look up samples
    mrk_ft_samps = nan(numLight, 1);
    mrk_ft_samps(idx_wasFound) = [data_ft.events(idx(idx_wasFound)).sample];
    
    % look up values
    mrk_ft_vals = nan(numLight, 1);
    mrk_ft_vals(idx_wasFound) = [data_ft.events(idx(idx_wasFound)).value];
    
    % store
    out.mrk_ft_samps = mrk_ft_samps;
    out.mrk_ft_value = mrk_ft_vals;
    
% summarise 

    out.summary = eegFT_summariseLightSensorMatch(out);

end