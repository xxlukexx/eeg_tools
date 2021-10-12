function data = eegAR_Detect(data, varargin)
% data = EEGAR_DETECT(data, varargin) detects artefacts on channel x trial
% segments of fieldtrip EEG data. DATA is a fieldtrip data structure. The
% method and parameters for detecting artefacts are listed below. 
%
% DATA STRUCTURE:
% The output of this function is .art and .art_type fields in DATA. The
% .art field is a logical [channels x trials x type] matrix. The third
% dimension - type - allows information to be recorded about different
% types of artefacts. For example, if aretfacts were first detected using
% min/max voltages, the first element in the third dimension would
% represent, for each channel x trial combination, whether or not an
% artefact was present according to this method. If data were then
% inspected manually, an additional element would be added to the third
% dimensions, so that the first element was the output of the mix/max
% method, and the second element was the output of the manual inspection
%
%   data.art(:, :, 1)     - all channel x trial segments, mix/max method
%   data.art(:, :, 2)     - all channel x trial segments, manual
%
% As additional methods are used, additional elements will be added to the
% third dimension of the .art matrix. As this happens, the .art_type field
% will record a string description of the method:
%
%   data.art_type{1}      - 'minmax'
%   data.art_type{2}      - 'manual'
%
% Artefacts of any time can be found by collapsing the matrix across its
% third dimensions:
%
%   art_any = any(art, 3);
% 
% Manual artefacts can be identified by querying the first element of the
% third dimension of the matrix:
%
%   art_manual = art(:, :, 1);
%
%
% OPTIONS & PARAMETERS
% Options and parameters are specified in key/value pairs. They can be
% specified in any order, but logically it makes sense to specify the
% artefact detection method first. 
%
% The method is defined by using the 'method' keyword, e.g.
%
%   data = eegAR_Detect(data, 'method', 'minmax')
%
% Valid methods are:
%
%   - minmax: define artefacts as segments with voltage above or 
%   below a value (e.g. +/- 100uV). Takes one parameter:
%
%       - threshold     -   [minVoltage, maxVoltage] the voltage in uV
%                           beyond which an artefact is detected
%   
%   - range: define artefacts as voltages outside of a range. Takes one 
%   parameter:
%   
%       - threshold     -   the range of voltages (max - min) that, when
%                           exceeded, represent an artefact (e.g. 100)
%
%   - flat: find segments that are entirely flat. No parameters. 
% 
%   - alpha: detects alpha bursts, by marking channel x trial segments with 
%   an alpha power exceeding valMax standard deviations of the mean. This 
%   is achieved by z-scoring the data for all trials (therefore valMax is
%   relative to the distribution of alpha power at all channels over all
%   trials). 
%
%       - maxsd         -   number of SDs to detect alpha bursts at
%       
%   eogstat - detects blinks and eye movements statistically. Uses two 
%   criteria: 1) samples outside crit SDs from the mean voltage across the
%   trials; and, 2) channels which fit a second order polynomial curve 
%   with a R2 > 0.6. (1) is quite good at detecting the shape of blinks 
%   in frontal channels. (2) detects drifts across the channel (usually 
%   an eye movement). 
%
%       - maxsd         -   samples with voltage > maxsd SDs from the mean 
%                           will be detected (default 2.5)
%       - maxr2         -   curve fits > maxr2 will be detected (default
%                           R2 = 0.6)
%
%   step_voltage - detects a step/jump in sample-to-sample voltage above
%   a criterion. 
%
%       - crit_voltage  -   step/jump > crit_voltage between any 
%                           consecutive samples are marked as artefact
%                           trials
%
% GENERAL PARAMETERS
% In addition to specifying the method and associated paramters, there are
% also general parameters that apply to all methods: 
%   
%   - excluded_channels -   logical index of all channels. Only elements of
%                           the array set to true will be checked for
%                           artefacts. This is useful if you want to detect
%                           artefacts on only a subset of channels, e.g.
%                           just frontal channels for blinks/eye movements.
%                           
%   - time_range        -   limit artefact detection to a particular time
%                           range within each segment. 


    %% parse inputs
    if ~exist('data', 'var') || isempty(data)
        error('Must supply a data structure as the first argument.')
    end
    if ~isstruct(data) || ~isfield(data, 'time') || ~isfield(data, 'trial') ||...
            ~isfield(data, 'fsample')
        error('data structure must be a valid fieldtrip structure.')
    end

    parser          =   inputParser;
    addParameter(   parser, 'method',                               @ischar  )
    addParameter(   parser, 'threshold',            [],             @isnumeric)
    addParameter(   parser, 'maxsd',                2.5,            @isnumeric)
    addParameter(   parser, 'maxr2',                0.75,           @isnumeric)
    addParameter(   parser, 'excluded_channels',    []              )
    addParameter(   parser, 'time_range',           [-inf, inf]     )
    addParameter(   parser, 'step_voltage',         inf             )
    parse(          parser, varargin{:});
    method          =   parser.Results.method;
    thresh          =   parser.Results.threshold;
    maxsd           =   parser.Results.maxsd;
    maxr2           =   parser.Results.maxr2;
    chExcl          =   parser.Results.excluded_channels;
    trange          =   parser.Results.time_range;
    step_volt       =   parser.Results.step_voltage;

    % get number of chans/trials
    numChans        = size(data.trial{1}, 1);
    numTrials       = length(data.trial);
    
    wb = waitbar(0, 'Detecting artefacts...');    

    % excluded channels
    if isempty(chExcl)
        chExcl = false(numChans, 1);
    end
    if ~islogical(chExcl) || ~isvector(chExcl) ||...
            length(chExcl) ~= numChans
        error('excluded_channels value must be a logical vector, with an element for each channel in DATA.')
    end

    % time range
    if ~isnumeric(trange) || ~isvector(trange) || length(trange) ~= 2 
        error('time_range value must be a two-element numeric vector, e.g. [time1, time2].')
    end

    switch method
        case 'minmax'
            % check param
            if isempty(thresh)
                error('Must specify a threshold value for the minmax method.')
            elseif ~isnumeric(thresh) || ~isvector(thresh) ||...
                    length(thresh) ~= 2
                error('threshold value must be numeric two-element vector.')
            end

        case 'range'
            % check param
            if isempty(thresh)
                error('Must specify a threshold value for the range method.')
            elseif ~isnumeric(thresh) || ~isscalar(thresh) || thresh < 0
                error('threshold value must be positive numeric scalar.')
            end

        case 'flat'

        case 'alpha'
            % check param
            if ~isnumeric(maxsd) || ~isscalar(maxsd) || maxsd < 0
                error('maxsd value must be positive numeric scalar.')
            end

        case 'eogstat'
            % check param
            if ~isnumeric(maxsd) || ~isscalar(maxsd) || maxsd < 0
                error('maxsd value must be positive numeric scalar.')
            end
            if ~isnumeric(maxr2) || ~isscalar(maxr2) || maxr2 < 0 || maxr2 > 1
                error('maxr2 value must be positive numeric scalar < 1.')
            end     
            % defaults
            blinkLen = 0.050;
           
        case 'step'
            % check param
            if ~isnumeric(step_volt) || ~isscalar(step_volt) || step_volt < 0
                error('step_voltage must be a positive numeric scalar.')
            end

        otherwise 
            error('Unknown method. See help for a list of valid methods.')
    end

    %% detect
    % init matrix variable
    mat = false(numChans, numTrials);

    % if using alpha method, pre-calc power values 
    if strcmpi(method, 'alpha')
        wb = waitbar(0, wb, 'Pre-computing alpha power...');
        alpha_power = cellfun(@(x)...
            mean(real(pwelch(x', [], [], 7.5:.5:12.5, data.fsample, 'power'))),...
            data.trial, 'uniform', false);
        alpha_power = vertcat(alpha_power{:})';  
        alpha_power_z = zscore(alpha_power, [], 2);
    end

    % if using eogstat method, filter data and precompute z scores
    if strcmpi(method, 'eogstat')
        wb = waitbar(0, wb, 'Pre-processing for EOG...');
        % BP filter 0.1-15Hz for blinks
        cfg = [];
        cfg.bpfilter = 'yes';
        cfg.bpfreq = [3, 10];
        cfg.bpfiltorder = 4;
        data_blink = ft_preprocessing(cfg, data);   
        % compute channel zscores for each trial
        wb = waitbar(0, wb, 'Pre-computing EOG stats...');
        zdata = eegZScoreSegs(data_blink);
        zcrit = cellfun(@(x) abs(x) > maxsd, zdata.trial, 'uniform', false); 
        % separate matrices
        blink = false(numChans, numTrials);
        drift = false(numChans, numTrials);
    end

    % loop through channels
    for ch = 1:numChans

        % check excluded electrodes
        curChan = data.label{ch};
        chanExclLabels = data.label(chExcl);
        if ismember(curChan, chanExclLabels), continue, end
        if mod(ch, 10) == 0
            msg = sprintf('Detecting artefacts in %s (%d of %d)...',...
                curChan, ch, numChans);
            wb = waitbar(ch / numChans, wb, msg);
        end
        
        % loop through trials
%         nsp = numSubplots(16);
%         spc = 1;
%         fig = figure('visible', 'off');
        for tr = 1:numTrials

            % convert time range from secs to samples, clamp to trial
            % length, store data in seg variable
            s1 = find(data.time{tr} >= trange(1), 1, 'first');
            s2 = find(data.time{tr} >= trange(2), 1, 'first');
            if isempty(s1), s1 = 1; end
            if isempty(s2), s2 = length(data.time{tr}); end
            seg = data.trial{tr}(ch, s1:s2);

            % detect
            switch method
                case 'minmax'
                    mat(ch, tr)  = any(seg < thresh(1)) | any(seg > thresh(2));
                case 'range'
                    mat(ch, tr) = max(seg) - min(seg) >= thresh;            
                case 'flat'
                    mat(ch, tr) = all(abs(seg) < .0001);
                case 'alpha'
                    mat(ch, tr) = alpha_power_z(ch, tr) >= maxsd;
                case 'eogstat'
                    % detect blinks                
                    ct = findcontig2(zcrit{tr}(ch, s1:s2)', 1);
                    if ~isempty(ct)
                        len = ct(:, 3) / data.fsample;
                        blink(ch, tr) = any(len > blinkLen);
                    end             
%                     % fit gaussian to blinks
%                     [ft, gof] =...
%                         fit(data_blink.time{tr}', data_blink.trial{tr}(ch, :)', 'gauss2');
%                     subplot(nsp(1), nsp(2), spc)
%                     spc = spc + 1;
%                     plot(data_blink.time{tr}, data_blink.trial{tr}(ch, :))
%                     hold on
%                     plot(ft)
%                     title(num2str(gof.rsquare))
%                     fprintf('Trial %d\n', tr)
                    % detect drift
                    if ~blink(ch, tr)
                        gof.rsquare = corr(data.time{tr}', seg') .^ 2;
%                         [~, gof] = fit(data.time{tr}', seg', 'poly1');
                        drift(ch, tr) = gof.rsquare >= maxr2;
                    end
                    mat(ch, tr) = blink(ch, tr) || drift(ch, tr);
                case 'step'
                    mat(ch, tr) = any(abs(diff(seg)) > step_volt);
            end

        end
%         set(fig, 'visible', 'on')

    end
    
    wb = waitbar(1, wb, 'Updating artefact marks...');
    data = eegAR_UpdateArt(data, mat, method);
    
    delete(wb)

end
