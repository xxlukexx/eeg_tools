function art = eegAR_Combine(varargin)

    % note that entries in varargin can be empty instead of artefact
    % structs. This allows for optional artefact detection in the calling
    % script, which, if disabled, returns an empty variable which will then
    % be ignored by this function
    
    if nargin < 3
        error('Must supply at least two artefact structures')
    end
    
    if ~strcmpi(ft_datatype(varargin{1}), 'raw')
        error('First argument must be fieldtrip data.')
    end
    
    % check whether final arg is cell array of strings listing artefact
    % type
    if iscellstr(varargin{end}) 
        types = varargin{end};
        numTypes = length(types);
        if numTypes ~= length(varargin) - 2     
            error('Number of types must match number of artefact structures.')
        end
        art.type = cell(size(varargin{2}.matrix));
        typePres = true;
        numArt = length(varargin) - 1;
    else
        typePres = false;
        numArt = length(varargin);
    end
    
    % combine 
    art.matrix = false(size(varargin{2}.matrix));
    for a = 2:numArt
        if ~isempty(varargin{a})
            art.matrix = art.matrix | varargin{a}.matrix;
            if typePres
                cur = art.type(varargin{a}.matrix);
                blank = cellfun(@isempty, cur);
                cur(~blank) = cellfun(@(x) [x, '_', types{a - 1}], cur(~blank),...
                    'uniform', false);
                cur(blank) = cellfun(@(x) types{a - 1}, cur(blank),...
                    'uniform', false);
                art.type(varargin{a}.matrix) = cur;
            end
        end
    end

    % summarise
    art = eegAR_Summarise(varargin{1}, art);

end