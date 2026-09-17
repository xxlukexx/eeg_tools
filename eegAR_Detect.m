function data = eegAR_Detect(data, varargin)
	%EEGAR_DETECT Mark artifacts on channel-by-trial FieldTrip data.
	%
	% DATA.art is a logical channel x trial x detector array. DATA.art_type
	% names its detector layers and DATA.art_cfg records the settings used.
	% Existing calls retain their historical defaults and combine new marks
	% with an existing layer of the same name.
	%
	% Amplitude thresholds are interpreted in the native stored units unless
	% 'amplitude_unit' is supplied. Physical units require DATA.chanunit so
	% thresholds can be converted separately for each channel.

	localValidateData(data)

	parser = inputParser;
	addParameter(parser, 'method', '', ...
		@(value) ischar(value) || (isstring(value) && isscalar(value)))
	addParameter(parser, 'threshold', [], @isnumeric)
	addParameter(parser, 'maxsd', 2.5, @isnumeric)
	addParameter(parser, 'maxr2', 0.75, @isnumeric)
	addParameter(parser, 'filter_band', [3, 10], @isnumeric)
	addParameter(parser, 'filter_order', 4, @isnumeric)
	addParameter(parser, 'minimum_duration_sec', 0.050, @isnumeric)
	addParameter(parser, 'excluded_channels', [])
	addParameter(parser, 'time_range', [-inf, inf], @isnumeric)
	addParameter(parser, 'step_voltage', inf, @isnumeric)
	addParameter(parser, 'flat_threshold', 0.0001, @isnumeric)
	addParameter(parser, 'amplitude_unit', 'native', ...
		@(value) ischar(value) || (isstring(value) && isscalar(value)))
	addParameter(parser, 'artifact_type', '', ...
		@(value) ischar(value) || (isstring(value) && isscalar(value)))
	addParameter(parser, 'update_mode', 'combine', ...
		@(value) ischar(value) || (isstring(value) && isscalar(value)))
	parse(parser, varargin{:})

	method = lower(string(parser.Results.method));
	threshold = parser.Results.threshold;
	maxStandardDeviations = parser.Results.maxsd;
	maximumRSquared = parser.Results.maxr2;
	filterBand = parser.Results.filter_band;
	filterOrder = parser.Results.filter_order;
	minimumDuration = parser.Results.minimum_duration_sec;
	timeRange = parser.Results.time_range;
	stepVoltage = parser.Results.step_voltage;
	flatThreshold = parser.Results.flat_threshold;
	amplitudeUnit = string(parser.Results.amplitude_unit);
	artifactType = string(parser.Results.artifact_type);
	updateMode = string(parser.Results.update_mode);

	if strlength(artifactType) == 0
		artifactType = method;
	end

	numChannels = size(data.trial{1}, 1);
	numTrials = numel(data.trial);
	excluded = parser.Results.excluded_channels;

	if isempty(excluded)
		excluded = false(numChannels, 1);
	end

	assert(islogical(excluded) && isvector(excluded) && ...
		numel(excluded) == numChannels, ...
		'eegAR:InvalidExcludedChannels', ...
		'excluded_channels must contain one logical value per channel.')
	excluded = excluded(:);

	assert(isvector(timeRange) && numel(timeRange) == 2 && ...
		timeRange(1) <= timeRange(2), ...
		'eegAR:InvalidTimeRange', ...
		'time_range must be an increasing two-element numeric vector.')

	localValidateMethodParameters( ...
		method, threshold, maxStandardDeviations, maximumRSquared, ...
		stepVoltage, flatThreshold, filterBand, filterOrder, minimumDuration)

	marks = false(numChannels, numTrials);
	alphaPowerZ = [];
	blinkCriterion = [];

	% Cohort-relative detector inputs are prepared once before the channel
	% and trial loops.
	if method == "alpha"
		alphaPower = cellfun(@(trial) mean(real(pwelch( ...
			trial', [], [], 7.5:0.5:12.5, data.fsample, 'power'))), ...
			data.trial, 'UniformOutput', false);
		alphaPower = vertcat(alphaPower{:})';
		alphaPowerZ = zscore(alphaPower, [], 2);
	elseif method == "eogstat"
		cfg = [];
		cfg.bpfilter = 'yes';
		cfg.bpfreq = filterBand;
		cfg.bpfiltorder = filterOrder;
		blinkData = ft_preprocessing(cfg, localFieldTripSignal(data));
		zData = eegZScoreSegs(blinkData);
		blinkCriterion = cellfun( ...
			@(trial) abs(trial) > maxStandardDeviations, ...
			zData.trial, 'UniformOutput', false);
	end

	for channel = 1:numChannels
		if excluded(channel)
			continue
		end

		for trial = 1:numTrials
			[firstSample, lastSample] = localTimeWindow( ...
				data.time{trial}, timeRange);
			segment = data.trial{trial}(channel, firstSample:lastSample);

			switch method
				case "minmax"
					bounds = localThresholdInChannelUnits( ...
						threshold, amplitudeUnit, data, channel);
					marks(channel, trial) = ...
						any(segment < bounds(1)) || any(segment > bounds(2));

				case "range"
					limit = localThresholdInChannelUnits( ...
						threshold, amplitudeUnit, data, channel);
					marks(channel, trial) = max(segment) - min(segment) >= limit;

				case "flat"
					limit = localThresholdInChannelUnits( ...
						flatThreshold, amplitudeUnit, data, channel);
					marks(channel, trial) = all(abs(segment) < limit);

				case "alpha"
					marks(channel, trial) = ...
						alphaPowerZ(channel, trial) >= maxStandardDeviations;

				case "eogstat"
					blink = localHasRun( ...
						blinkCriterion{trial}(channel, firstSample:lastSample), ...
						minimumDuration * data.fsample);
					drift = false;

					if ~blink
						drift = localLinearRSquared( ...
							data.time{trial}(firstSample:lastSample), segment) >= ...
							maximumRSquared;
					end

					marks(channel, trial) = blink || drift;

				case "step"
					limit = localThresholdInChannelUnits( ...
						stepVoltage, amplitudeUnit, data, channel);
					marks(channel, trial) = any(abs(diff(segment)) > limit);
			end
		end
	end

	settings = parser.Results;
	settings.method = char(method);
	settings.artifact_type = char(artifactType);
	settings.update_mode = char(updateMode);
	data = eegAR_UpdateArt( ...
		data, marks, artifactType, ...
		'mode', updateMode, ...
		'settings', settings);
end


function localValidateData(data)
	assert(isstruct(data) && isfield(data, 'time') && ...
		isfield(data, 'trial') && isfield(data, 'fsample'), ...
		'eegAR:InvalidFieldTripData', ...
		'Data must be a segmented FieldTrip raw structure.')
	assert(iscell(data.trial) && ~isempty(data.trial) && ...
		iscell(data.time) && numel(data.time) == numel(data.trial), ...
		'eegAR:InvalidFieldTripData', ...
		'FieldTrip trial and time fields must be aligned cell arrays.')
end


function localValidateMethodParameters( ...
		method, threshold, maxStandardDeviations, maximumRSquared, ...
		stepVoltage, flatThreshold, filterBand, filterOrder, minimumDuration)
	assert(ismember(method, ...
		["minmax", "range", "flat", "alpha", "eogstat", "step"]), ...
		'eegAR:UnknownMethod', ...
		'Unknown artifact-detection method: %s.', method)

	if method == "minmax"
		assert(isvector(threshold) && numel(threshold) == 2 && ...
			threshold(1) < threshold(2), ...
			'eegAR:InvalidThreshold', ...
			'Minmax threshold must be [minimum maximum].')
	elseif method == "range"
		assert(isscalar(threshold) && threshold >= 0, ...
			'eegAR:InvalidThreshold', ...
			'Range threshold must be a non-negative scalar.')
	elseif method == "alpha"
		assert(isscalar(maxStandardDeviations) && ...
			maxStandardDeviations >= 0, ...
			'eegAR:InvalidThreshold', ...
			'Alpha maxsd must be a non-negative scalar.')
	elseif method == "eogstat"
		assert(isscalar(maxStandardDeviations) && ...
			maxStandardDeviations >= 0 && ...
			isscalar(maximumRSquared) && maximumRSquared >= 0 && ...
			maximumRSquared <= 1 && ...
			isvector(filterBand) && numel(filterBand) == 2 && ...
			filterBand(1) > 0 && filterBand(1) < filterBand(2) && ...
			isscalar(filterOrder) && filterOrder >= 1 && ...
			isscalar(minimumDuration) && minimumDuration >= 0, ...
			'eegAR:InvalidThreshold', ...
			'EOG maxsd and maxr2 values are invalid.')
	elseif method == "step"
		assert(isscalar(stepVoltage) && stepVoltage >= 0, ...
			'eegAR:InvalidThreshold', ...
			'step_voltage must be a non-negative scalar.')
	elseif method == "flat"
		assert(isscalar(flatThreshold) && flatThreshold >= 0, ...
			'eegAR:InvalidThreshold', ...
			'flat_threshold must be a non-negative scalar.')
	end
end


function [firstSample, lastSample] = localTimeWindow(time, range)
	firstSample = find(time >= range(1), 1, 'first');
	lastSample = find(time <= range(2), 1, 'last');

	if isempty(firstSample)
		firstSample = 1;
	end

	if isempty(lastSample)
		lastSample = numel(time);
	end
end


function threshold = localThresholdInChannelUnits( ...
		threshold, suppliedUnit, data, channel)
	suppliedUnit = localNormaliseUnit(suppliedUnit);

	if suppliedUnit == "native"
		return
	end

	assert(isfield(data, 'chanunit') && numel(data.chanunit) >= channel, ...
		'eegAR:MissingChannelUnit', ...
		'Physical artifact thresholds require FieldTrip chanunit metadata.')
	dataUnit = localNormaliseUnit(string(data.chanunit{channel}));
	assert(dataUnit ~= "native", 'eegAR:MissingChannelUnit', ...
		'Channel %s has no recognised amplitude unit.', data.label{channel})
	threshold = threshold .* ...
		(localVoltsPerUnit(suppliedUnit) / localVoltsPerUnit(dataUnit));
end


function unit = localNormaliseUnit(unit)
	unit = lower(strtrim(string(unit)));
	unit = replace(unit, ["µ", "μ"], "u");

	if ismember(unit, ["", "native", "unknown"])
		unit = "native";
	elseif unit == "volt" || unit == "volts"
		unit = "v";
	elseif unit == "millivolt" || unit == "millivolts"
		unit = "mv";
	elseif unit == "microvolt" || unit == "microvolts"
		unit = "uv";
	elseif unit == "nanovolt" || unit == "nanovolts"
		unit = "nv";
	end

	assert(ismember(unit, ["native", "v", "mv", "uv", "nv"]), ...
		'eegAR:UnknownAmplitudeUnit', ...
		'Unsupported amplitude unit: %s.', unit)
end


function scale = localVoltsPerUnit(unit)
	switch unit
		case "v"
			scale = 1;
		case "mv"
			scale = 1e-3;
		case "uv"
			scale = 1e-6;
		case "nv"
			scale = 1e-9;
		otherwise
			error('eegAR:UnknownAmplitudeUnit', ...
				'Cannot convert the native amplitude unit.')
	end
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


function result = localHasRun(mask, minimumSamples)
	mask = logical(mask(:));
	edges = diff([false; mask; false]);
	starts = find(edges == 1);
	stops = find(edges == -1) - 1;
	result = any((stops - starts + 1) > minimumSamples);
end


function value = localLinearRSquared(time, signal)
	time = double(time(:));
	signal = double(signal(:));
	time = time - mean(time);
	signal = signal - mean(signal);
	denominator = sqrt(sum(time .^ 2) * sum(signal .^ 2));

	if denominator == 0
		value = 0;
	else
		value = (sum(time .* signal) / denominator) ^ 2;
	end
end
