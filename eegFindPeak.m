function [pk, locS] = eegFindPeak(erp, searchTimeS, chanLabel, dir)

    if ~exist('dir', 'var')
        dir = 'positive';
    end
    
    if any(isnan(searchTimeS))
        pk = nan;
        locS = nan;
        return
    end
    
    % convert window edges in seconds to samples
    s1 = find(erp.time >= searchTimeS(1), 1, 'first');
    s2 = find(erp.time >= searchTimeS(2), 1, 'first');
    
    % find the index of the channel we're searching in
    chIdx = find(strcmpi(erp.label, chanLabel), 1, 'first');
    
    % cut out the data on the search channel, within just the window
    % defined by searchTimeS / s1 and s2
    data = erp.avg(chIdx, s1:s2);
    
    switch dir
        case 'positive'
            pk = max(data);
        case 'negative'
            pk = min(data);
    end
    
    loc = find(data == pk, 1, 'first') + s1 - 1;
    locS = erp.time(loc);
    
end