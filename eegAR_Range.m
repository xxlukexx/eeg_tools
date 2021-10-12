function [art, reject] = eegAR_Range(data, valRange, chExcl)

    % [art, reject] = eegAR_Range(data, valRange, chExcl)
    %
    % Find channels with a voltage range (max - min) above criterion. 
    %
    % INPUT ARGS
    % data          -   fieldtrip data
    % valRange      -   maximum range value, above which is an artefact
    % chExcl        -   (optional) logical index of channels. Useful to
    %                   exclude all but frontal channels
    %
    % OUTPUT ARGS
    % reject        -   artefact definition in fieltrip format. Not very
    %                   useful and may not work
    
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
    
%     art = eegAR_Summarise(data, art);

end
