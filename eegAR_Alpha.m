function art = eegAR_Alpha(data, valMax, chExcl, timeRange)

    % art = eegAR_Alpha(data, valMax, chExcl, timeRange)
    %
    % Detects alpha bursts, by marking channel x trial segments with an
    % alpha power exceeding valMax standard deviations of the mean. This is
    % achieved by z-scoring the data for all trials (therefore valMax is
    % relative to the distribution of alpha power at all channels over all
    % trials). 
    %
    % data          -   fieldtrip data
    % valMax        -   number of SDs to detect alpha bursts at
    % chExcl        -   (optional) logical index of channels
    % timeRange     -   not yet implenented
    
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
