function [pk, locS] = eegFindPeak(erp, searchTimeS, chanLabel, fs, dir)

    if ~exist('dir', 'var')
        dir = 'positive';
    end
    
    if any(isnan(searchTimeS))
        pk = nan;
        locS = nan;
        return
    end
    
    s1 = find(erp.time >= searchTimeS(1), 1, 'first');
    s2 = find(erp.time >= searchTimeS(2), 1, 'first');
    
    chIdx = find(strcmpi(erp.label, chanLabel), 1, 'first');
    
    data = erp.avg(chIdx, s1:s2);
    
    switch dir
        case 'positive'
            pk = max(data);
        case 'negative'
            pk = min(data);
    end
    
    loc = find(data == pk, 1, 'first') + s1 - 1;
%     locS = (loc / fs) + erp.time(1);
    locS = erp.time(loc);
    
end