function [art, reject] =...
    eegAR_EOGStat(data, crit, chExcl, timeRange, rerefChan)

    % art = eegAR_EOGStat(data, crit, chExcl, timeRange, rerefChan)
    %
    % Detects blinks. Uses two criteria: 1) samples outside crit SDs from
    % the mean voltage across thet trials; and, 2) channels which fit a
    % second order polynomial curve with a R2 > 0.6. (1) is quite good at
    % detecting the shape of blinks in frontal channels. (2) detects drifts
    % across the channel (usually an eye movement). 
    %
    % data          -   fieldtrip data
    % crit          -   samples with voltage > crit SDs from the mean will
    %                   be detected
    % chExcl        -   (optional) logical index of channels. Useful to
    %                   exclude all but frontal channels
    % timeRange     -   time range upon which to detect artefacts (relative
    %                   to trial onset)
    
    % check whether any channels are being excluded
    if ~exist('chExcl', 'var') || isempty(chExcl)
        chExcl = false(size(data.label));
    end
    
    if ~exist('timeRange', 'var') || isempty(timeRange)
        timeRange = [-inf, inf];
    end
    
    if ~exist('crit', 'var') || isempty(crit)
        crit = 2.5;
        warning('eegAR_EOGStat: criterion not supplied, defaulting to %.1f SDs',...
            crit);
    end
    
    if ~exist('rerefChan', 'var') || isempty(rerefChan)
        rerefChan = 'Oz';
    end
    
    numChans = length(data.label);
    numTrials = length(data.trial);
    blinkLen = 0.100;
    
    % median filter to remove noise
    data.trial = cellfun(@(x) medfilt1(x', 20)', data.trial,...
        'uniform', false);
    
    % BP filter 0.1-15Hz for blinks
    cfg = [];
    cfg.bpfilter = 'yes';
    cfg.bpfreq = [1, 15];
    cfg.bpfiltorder = 4;
    data_blink = ft_preprocessing(cfg, data);
    
    art.matrix = false(numChans, numTrials);
    blink = false(numChans, numTrials);
    drift = false(numChans, numTrials);
    reject = [];    
    
    % compute channel zscores for each trial
    zdata = eegZScoreSegs(data_blink);
    zcrit = cellfun(@(x) x > crit, zdata.trial, 'uniform', false);   
    
    for tr = 1:numTrials
        
        for ch = 1:numChans
            
            % check excluded electrodes
            if ~any(strcmpi(data.label(chExcl), data.label{ch}))
                
                % get time range
                s1 = find(data.time{tr} >= timeRange(1), 1, 'first');
                s2 = find(data.time{tr} >= timeRange(2), 1, 'first');
                if isempty(s1), s1 = 1; end
                if isempty(s2), s2 = length(data.time{tr}); end
                
                % detect blink artefacts                
                ct = findcontig(zcrit{tr}(ch, s1:s2)', 1);
                if ~isempty(ct)
                    len = ct(:, 3) / data.fsample;
                    blink(ch, tr) = any(len > blinkLen);
                end             
                
                % detect drift
                if ~blink(ch, tr)
                    [~, gof] = fit(data.time{tr}', data.trial{tr}(ch, :)',...
                        'poly2');
                    drift(ch, tr) = gof.rsquare >= .6;
                end

            end
        end
        
        art.matrix(ch, tr) = blink(ch, tr) | drift(ch, tr);
        
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