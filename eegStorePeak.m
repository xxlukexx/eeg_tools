function erp = eegStorePeak(erp, label, chan, amp, loc)

    numChans = length(erp.label);
    
    % check whether a peaks structure exists
    if ~isfield(erp, 'peaklabel') || isempty(erp.peaklabel)
        erp.peaklabel = {label};
        labIdx = 1;
    else
        % look for existing label
        labIdx = find(strcmpi(erp.peaklabel, label));
        if isempty(labIdx)
            % not found, create
            erp.peaklabel{end + 1} = label;
            labIdx = length(erp.peaklabel);
        end
    end
    
    if ~isfield(erp, 'peakamp') || isempty(erp.peakamp)
        erp.peakamp = nan(numChans, 1);
    else
        % check size of peakamp against labels
        if size(erp.peakamp, 2) ~= length(erp.peaklabel)
            erp.peakamp(:, labIdx) = nan(numChans, 1);
        end
    end
    
    if ~isfield(erp, 'peakloc') || isempty(erp.peakloc)
        erp.peakloc = nan(numChans, 1);
    else
        % check size of peakamp against labels
        if size(erp.peakloc, 2) ~= length(erp.peaklabel)
            erp.peakloc(:, labIdx) = nan(numChans, 1);
        end
    end
    
    % find channel
    chIdx = find(strcmpi(erp.label, chan));
    if isempty(chIdx), error('Channel %s not found.', chan); end
    
    % store new values
    erp.peakamp(chIdx, labIdx) = amp;
    erp.peakloc(chIdx, labIdx) = loc;
    
end