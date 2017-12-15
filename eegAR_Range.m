function [art, reject] = eegAR_Range(data, valRange, chExcl)

    % check whether any channels are being excluded
    if ~exist('chExcl', 'var') || isempty(chExcl)
        chExcl = false(size(data.label));
    end
    
    numChans = length(data.label);
    numTrials = length(data.trial);
    
    art.matrix = false(numChans, numTrials);
    reject = [];
    
    for tr = 1:numTrials
        
        for ch = 1:numChans
            % check excluded electrodes
            if ~any(strcmpi(data.label(chExcl), data.label{ch}))
                art.matrix(ch, tr) = max(data.trial{tr}(ch, :)) -...
                    min(data.trial{tr}(ch, :)) >= valRange;
            end
        end
        
        % if ft sampleinfo is present, make a vector of start/end samples
        % with artefacts
        if any(art.matrix(:, tr))
            if isfield(data, 'sampleinfo')
                reject = [reject; data.sampleinfo(tr, :)];
            end
        end

    end
    
    art = eegAR_Summarise(data, art);

end
