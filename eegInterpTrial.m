function [data, chanInterp, trialInterp, totInterp, propInterp, ...
		interpMat, interpNeigh, cantInterp] = ...
		eegInterpTrial(data, art, distance, neighbours, minimumGoodNeighbours)
	%EEGINTERPTRIAL Repair marked channel-by-trial segments with FieldTrip.
	%
	% ART may be a logical channel x trial array, a layered logical array, or
	% a structure with a .matrix field. Historical defaults are retained.

	if nargin < 3 || isempty(distance)
		distance = 50;
	end

	if nargin < 5 || isempty(minimumGoodNeighbours)
		minimumGoodNeighbours = 3;
	end

	if isstruct(art)
		art = art.matrix;
	end

	if ndims(art) == 3
		art = any(art, 3);
	end

	art = logical(art);
	numChannels = numel(data.label);
	numTrials = numel(data.trial);
	assert(isequal(size(art), [numChannels, numTrials]), ...
		'eegInterpTrial:ArtifactSizeMismatch', ...
		'Artifact marks must be channels by trials.')

	if nargin < 4 || isempty(neighbours)
		cfg = [];
		cfg.method = 'distance';
		cfg.elec = data.elec;
		cfg.neighbourdist = distance;
		cfg.feedback = 'no';
		neighbours = ft_prepare_neighbours(cfg, data);
	end

	interpMat = false(numChannels, numTrials);
	interpNeigh = cell(numChannels, numTrials);
	cantInterp = false(numChannels, numTrials);

	% Subject-level parallelism is handled by the calling batch. Keeping this
	% loop serial avoids nested pools and makes FieldTrip failures attributable
	% to one trial.
	for trial = 1:numTrials
		bad = art(:, trial);

		if ~any(bad)
			continue
		end

		[canInterpolate, badLabels, usableNeighbours] = ...
			eegAR_FindInterpChans( ...
				data, bad, false, neighbours, minimumGoodNeighbours);
		cantInterp(:, trial) = bad & ~canInterpolate;

		if ~any(canInterpolate)
			continue
		end

		cfg = [];
		cfg.trials = trial;
		cfg.showcallinfo = 'no';
		trialData = ft_selectdata(cfg, localFieldTripSignal(data)); %#ok<NASGU>

		cfg = [];
		cfg.method = 'average';
		cfg.badchannel = badLabels;
		cfg.neighbours = usableNeighbours;
		cfg.feedback = 'no';
		cfg.showcallinfo = 'no';
		% FieldTrip prints one status block for every repaired trial. Suppress
		% that chatter here; the caller records aggregate repair counts.
		evalc('repaired = ft_channelrepair(cfg, trialData);');
		data.trial{trial} = repaired.trial{1};
		interpMat(canInterpolate, trial) = true;

		for channel = find(canInterpolate)'
			entry = find(strcmpi({usableNeighbours.label}, data.label{channel}), 1);

			if ~isempty(entry)
				interpNeigh{channel, trial} = ...
					usableNeighbours(entry).neighblabel;
			end
		end
	end

	chanInterp = sum(interpMat, 2);
	trialInterp = sum(interpMat, 1);
	totInterp = sum(interpMat, 'all');
	propInterp = totInterp / numel(interpMat);
	data.interp = interpMat;
	data.interpNeigh = interpNeigh;
	data.cantInterp = cantInterp;
end


function signal = localFieldTripSignal(data)
	signal = data;
	customFields = { ...
		'art', 'art_type', 'art_cfg', ...
		'interp', 'interpNeigh', 'cantInterp', ...
		'artifact_history', 'exclude_from_ref'};
	present = intersect(customFields, fieldnames(signal));

	if ~isempty(present)
		signal = rmfield(signal, present);
	end
end
