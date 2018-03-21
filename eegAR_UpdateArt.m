function data = eegAR_UpdateArt(data, m, type)
% data = EEGAR_UPDATEART(data, m, type) creates or updates an existing
% artefact structure with new artefact data. DATA is the fieldtrip data
% structure that is being worked on. It may or may not have an existing
% .art field. M is a logical [channel x trial] matrix, where true indicates
% the presence of an artefact on a particular trial for a particular
% channel, and false indicates no artefact (i.e. clean). TYPE is the type
% of artefact represent in M (e.g. 'minmax' or 'manual').
%
% if no .art field exists in DATA then a new one will be created. If an
% existing .art field exists, the function will search for an entry of type
% TYPE. If none exists, it will create one. If an existing entry for TYPE
% exists, the artefacts described in M will be combined with the existing
% artefacts of the same type using a logical OR. This means that new
% artefact marks will be combined with the existing, without anything being
% overwritten. To clear artefacts once a trial x channel segment has been
% successfully interpolated, call eegAR_ResetArtByInterp. 
%

    % get number of chans/trials
    numChans        = size(data.trial{1}, 1);
    numTrials       = length(data.trial);
    
    % does art field exist?
    if ~isfield(data, 'art');
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
        data.art(:, :, found) = data.art(:, :, found) | m;
    end

end