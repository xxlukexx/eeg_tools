function [art, reject] =...
    eegAR_MinMax(data, valMin, valMax, chExcl, timeRange)

    % [art, reject] = eegAR_MinMax(data, valMin, valMax, chExcl, timeRange)
    %
    % Find chnanels with absolute voltage values that exceed a min and max
    % criterion. 
    %
    % INPUT ARGS
    % data          -   fieldtrip data
    % valMin        -   minimum voltage value, below which is an artefact
    % valMax        -   maximum voltage value, above which is an artefact
    % chExcl        -   (optional) logical index of channels. Useful to
    %                   exclude e.g. all but frontal channels
    % timeRange     -   time range upon which to detect artefacts (relative
    %                   to trial onset)
    %
    % OUTPUT ARGS
    % reject        -   artefact definition in fieltrip format. Not very
    %                   useful and may not work
    
    if ~exist('chExcl', 'var') || isempty(chExcl)
        chExcl = false(size(data.label));
    end
    
    if ~exist('timeRange', 'var') || isempty(timeRange)
        timeRange = [-inf, inf];
    end
    
    numChans = length(data.label);
    numTrials = length(data.trial);
    
    art.matrix = false(numChans, numTrials);
    reject = [];
    
    for tr = 1:numTrials
        
        for ch = 1:numChans
            % check excluded electrodes
            if ~any(strcmpi(data.label(chExcl), data.label{ch}))
                % get time range
                s1 = find(data.time{tr} >= timeRange(1), 1, 'first');
                s2 = find(data.time{tr} >= timeRange(2), 1, 'first');
                if isempty(s1), s1 = 1; end
                if isempty(s2), s2 = length(data.time{tr}); end
                % detect artefacts
                art.matrix(ch, tr)  =...
                    any(data.trial{tr}(ch, s1:s2) < valMin) |...
                    any(data.trial{tr}(ch, s1:s2) > valMax);
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
