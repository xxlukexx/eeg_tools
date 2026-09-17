function data = eegAR_UpdateArt(data, m, type, varargin)
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
% successfully interpolated, call eegAR_ResetArtFromInterp.
%
% Optional name/value inputs preserve the historical combine behaviour:
%
%   'mode'       - 'combine' (default) or 'replace'
%   'settings'   - detector settings stored alongside .art_type
%

	parser = inputParser;
	addParameter(parser, 'mode', 'combine', ...
		@(value) ischar(value) || (isstring(value) && isscalar(value)))
	addParameter(parser, 'settings', struct, ...
		@(value) isstruct(value) && isscalar(value))
	parse(parser, varargin{:})

	mode = lower(string(parser.Results.mode));
	assert(ismember(mode, ["combine", "replace"]), ...
		'eegAR:InvalidUpdateMode', ...
		'Artifact update mode must be combine or replace.')

	type = char(string(type));
	m = logical(m);
	numChannels = size(data.trial{1}, 1);
	numTrials = numel(data.trial);

	if ~isfield(data, 'art')
		data.art = false(numChannels, numTrials, 0);
		data.art_type = cell(1, 0);
	elseif ~isfield(data, 'art_type')
		error('.art structure found but no corresponding .art_type.')
	end

	assert(size(m, 1) == numChannels && size(m, 2) == numTrials, ...
		'eegAR:ArtifactSizeMismatch', ...
		'Artifact matrix must be channels by trials.')
	assert(size(data.art, 1) == numChannels && ...
		size(data.art, 2) == numTrials, ...
		'eegAR:ArtifactSizeMismatch', ...
		'Existing artifact marks do not match the data dimensions.')

	if ~isfield(data, 'art_cfg')
		data.art_cfg = cell(size(data.art_type));
	elseif numel(data.art_cfg) < numel(data.art_type)
		data.art_cfg(end + 1:numel(data.art_type)) = {struct};
	end

	found = find(strcmpi(data.art_type, type));
	assert(numel(found) <= 1, 'eegAR:DuplicateArtifactType', ...
		'Multiple entries found for artifact type %s.', type)

	if isempty(found)
		index = numel(data.art_type) + 1;
		data.art_type{index} = type;
		data.art(:, :, index) = m;
	else
		index = found;

		if mode == "combine"
			data.art(:, :, index) = data.art(:, :, index) | m;
		else
			data.art(:, :, index) = m;
		end
	end

	data.art_cfg{index} = parser.Results.settings;
end
