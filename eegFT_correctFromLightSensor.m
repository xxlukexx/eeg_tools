function [data_ft, smry] = eegFT_correctFromLightSensor(...
    data_ft, thresh, tol, wantedEvents)

    smry = struct;
    smry.found = false;
    
% prepare defaults and find light sensor markers

    % default threshold is 1000µV
    if ~exist('thresh', 'var') || isempty(thresh)
        thresh = 1000;
    end

    % 100ms default tolerance
    if ~exist('tol', 'var') || isempty(tol)
        tol_s = 0.100;
        tol = tol_s * data_ft.fsample;
    end
    
    % default to correcting all events
    if ~exist('wantedEvents', 'var') 
        wantedEvents = [];
    end
    
    % find light sensor events in EEG data
    [lightChannelFound, mrk_light, mrk_light_s, idx_chan] =...
        eegFT_lightSensor2Events(data_ft, thresh);
    if ~lightChannelFound, return, end

% prepare ft events structure and convert to table

    tab = struct2table(data_ft.events);
    
    % store un-corrected event sample index
    tab.sample_uncorrected = tab.sample;
    
% loop through all ft events and correct with nearest light sensor marker

    numEvents = size(tab, 1);
    for e = 1:numEvents
        
        if ~isempty(wantedEvents) && ~ismember(tab.value(e), wantedEvents)
            continue
        end
        
        % find light sensor events within tolerance of ft event
        samp_ft = tab.sample(e);
        delta = samp_ft - mrk_light;
        adelta = abs(delta);
        idx = adelta < tol;
        
        if ~any(idx), continue, end
        
        % if more than on light marker was in range of the ft event, take
        % the closest
        numMatches = sum(idx);
        if numMatches > 1
            idx = adelta < tol & adelta == min(adelta);
            numMatches = sum(idx);
        end
        
        % if we still have multiple matches, it may be because they are
        % equally spaced either side of the ft event (e.g. -3, 3). In this
        % case, take the lowest positive delta, since this is the first
        % event AFTER the ft event. Whilst it makes sense that light
        % markers come after event markers (since we are measuring a
        % monitor-induced delay), we don't assume this in every case. But
        % in this case we really don't know which one to take, so we make
        % this assumption. 
        if numMatches > 1 
            nearestDelta = delta(delta > 0 & delta == min(delta(delta > 0)));
            idx = delta == nearestDelta;
            numMatches = sum(idx);
        end
        
        % correct
        tab.sample(e) = mrk_light(idx);
        
    end

    % rebuild events struct from table
    data_ft.events = table2struct(tab);
    smry.found = true;
    
end