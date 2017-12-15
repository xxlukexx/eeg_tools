function [canInterp, canInterpLab, nb, summary] =...
    eegAR_FindInterpChans(data, bad, cmdEcho, nb)

    % defaults
    canInterp = false(size(bad));
    canInterpLab = {};
    summary = table;
    
    % find electrode neighbours, for interpolation
    if ~exist('nb', 'var')
        cfg = [];
        cfg.method = 'distance';
        cfg.layout = 'EEG1010.lay';
        nb = ft_prepare_neighbours(cfg, data); 
    end
    
    % check that the bad vector matches the size of the data
    if length(bad) ~= length(data.label)
        error('bad vector must be of same size as data.label')
    end
    
    if ~exist('cmdEcho', 'var') || isempty(cmdEcho)
        cmdEcho = true;
    end
    
    % if no chans marked as bad, quit
    if ~any(bad), return, end

    % loop through channels, find those with electrode labels in the
    % neighbout struct
    numChans = length(data.label);
    nbFound = false(size(bad));
    nbLabs = cell(size(bad));
    nbInvalidLabs = cell(size(bad));
    nbValidLabs = cell(size(bad));
    nbAllValid = false(size(bad));
    for ch = 1:numChans
        
        % only check if the channel is marked as bad
        if ~bad(ch), continue, end
        
        % look for channel in nb struct
        found = find(strcmpi({nb.label}, data.label{ch}));
        
        % if not found, we cannot interp
        if isempty(found)
            canInterp(ch) = false;
        else
            % check whether any of the neighbours are also bad. Get indices
            % of neighbours, and cross reference with bad vector
            
            % mark neighbours found as true
            nbFound(ch) = true;
            
            % find indices in the bad vector by matching label names
            nbIdx = cellfun(@(x) find(strcmpi(data.label, x)),...
                nb(found).neighblabel);
            
            % get labels of neighbours
            labs = cellfun(@(x) [x, ' '], data.label(nbIdx),...
                'uniform', false);
            nbLabs{ch} = horzcat(labs{:});
            
            % check whether any neighbours are also bad
            nbAllValid(ch) = length(nbIdx(~bad(nbIdx))) >= 3;
            
            % get labels of also bad neighbours
            labs = cellfun(@(x) [x, ' '], data.label(nbIdx(bad(nbIdx))),...
                'uniform', false);
            nbInvalidLabs{ch} = horzcat(labs{:});
            
            % get labels of good neighbours
            labs = cellfun(@(x) [x, ' '], data.label(nbIdx(~bad(nbIdx))),...
                'uniform', false);
            nbValidLabs{ch} = horzcat(labs{:});
            nb(found).neighblabel = data.label(nbIdx(~bad(nbIdx)));
            
            % update 
            canInterp(ch) = nbAllValid(ch);
        end

    end
    
    summary = table(...
            data.label(bad),...
            nbFound(bad),...
            nbLabs(bad),...
            nbInvalidLabs(bad),...
            nbValidLabs(bad),...
            nbAllValid(bad),...
            canInterp(bad),...
        'variablenames', {...
            'channel',...
            'neighbour_found',...
            'neighbours',...
            'neighbours_invalid',...
            'neighbours_valid',...
            'neighbours_all_valid',...
            'can_interp',...
        });
    
    if cmdEcho, disp(summary), end
    
    % if any can be interpolated, make string of labels
    if any(canInterp(bad))
%         labs = cellfun(@(x) [x, ' '], data.label(canInterp(bad)),...
%             'uniform', false);
%         canInterpLab = horzcat(labs{:});
        canInterpLab = data.label(canInterp);
    end
    
end