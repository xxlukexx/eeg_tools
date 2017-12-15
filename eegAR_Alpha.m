function art = eegAR_Alpha(data, valMax, chExcl, timeRange)

    % check whether any channels are being excluded
    if ~exist('chExcl', 'var') || isempty(chExcl)
        chExcl = false(size(data.label));
    end
    
    if ~exist('timeRange', 'var') || isempty(timeRange)
        timeRange = [-inf, inf];
    end
        
    % calculate alpha power
    pow = cellfun(@(x)...
        mean(real(pwelch(x', [], [], 7.5:.5:12.5, data.fsample, 'power'))),...
        data.trial, 'uniform', false);
    pow = vertcat(pow{:})';
    
    % zscore and threshold
    pow_z = zscore(pow, [], 2);
    art.matrix = pow_z >= valMax;
    
    art = eegAR_Summarise(data, art);

end
