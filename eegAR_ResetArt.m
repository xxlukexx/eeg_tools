function data = eegAR_ResetArt(data, type)

    % get number of chans/trials
    numChans        = size(data.trial{1}, 1);
    numTrials       = length(data.trial);
    m               = false(numChans, numTrials);
    
    % does art field exist?
    if ~isfield(data, 'art')
        data.art = false(numChans, numTrials);
        data.art_type = {type};
    elseif ~isfield(data, 'art_type')
        error('.art structure found but no corresponding .art_type.')
    end
    
    % check sizes
    if size(data.art, 1) ~= size(m, 1) || size(data.art, 2) ~= size(m, 2)
        error('Size mismatch between existing .art structure and new structure.')
    end
        
    % lookup marks for this type
    found = strcmpi(data.art_type, type);
    if sum(found) > 1
        error('Multiple entries found for artefact type %s.', type)
    elseif ~any(found)
        % create new entry
        idx = length(data.art_type);
        data.art_type{idx + 1} = type;
        data.art(:, :, idx + 1) = m;
    else
        % update existing
        data.art(:, :, found) = m;
    end
    
end