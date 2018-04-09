function [data, chanInterp, trialInterp, totInterp, propInterp,...
     interpNeigh, cantInterp] =...
    eegInterpTrial2(data, distance, nb)

    % [data, chanInterp, trialInterp, totInterp, propInterp,...
    %       interpMat, interpNeigh, cantInterp] =...
    %       eegInterpTrial(data, art, distance, nb)
    %
    % Interpolate channels on a per-trial basis. 
    %
    % INPUT ARGS
    % data          -   fieldtrip data
    % art           -   artefact matrix, logical, [channels x trials]
    % distance      -   (optional) max distance to neighbouring electrodes
    %                   for them to be be interpolated from (def. 50ms)
    % nb            -   (optional) fieldtrip neighbours structure. Will be
    %                   calculated if not supplied. Save time by passing a
    %                   previously used structure. 
    %
    % OUTPUT ARGS
    % data          -   intepolated data
    % chanInterp    -   number of interpolated channels per trial
    % trialInterp   -   number of interpolated trials per channel
    % totInterp     -   total number of channel x trial interpolations
    % propInterp    -   proportion of channel x trial combinations that
    %                   were interpolated
    % interpMat     -   [channel x trial] matrix, indicating which channel
    %                   x trial combinations were interpolated
    % interpNeigh   -   for each channel, indices of neighbouring channels
    %                   that were used to interpolate from
    % cantInterp    -   indices of channels that were bad, but could not be
    %                   interpolated due to having no clean neighbours
    
    numChans = length(data.label);
    numTrials = length(data.trial);
    
    % flatten art structure so that we interpolate artefacts regardless of
    % what layer they are in (i.e. regardless of artefact type)
    art = any(data.art, 3);
    
    numBad = 0;
    numInterp = 0;
    interpMat = false(numChans, numTrials);
    interpNeigh = cell(numChans, numTrials);
    cantInterp = false(numChans, numTrials);

    if ~exist('distance', 'var') || isempty(distance)
        distance = 50;
    end
    
    % get ft neighbours structure for determining electrodes to intepolate
    % from 
    if ~exist('nb', 'var')
        cfg = [];
        cfg.channel = data.label;
        cfg.method = 'distance';
        cfg.layout = data.elec;
        cfg.neighbourdist = distance;
        nb = ft_prepare_neighbours(cfg, data); 
    end
    
    % flags to store which trials/channels were interpolated/excluded
    interp = false(length(data.label), length(data.trial));
    excl = false(length(data.label), length(data.trial));
    
    % loop through trials
    tmp_trial = data.trial;
    tmp_canInterp = cell(numTrials, 1);
    tmp_bad = cell(numTrials, 1);
    parfor tr = 1:numTrials
        
        % check that there are some channels with artefacts on this current
        % trial
        if ~any(art(:, tr)), continue, end
        
        % select data from current trial        
        cfg = [];
        cfg.trials = false(numTrials, 1);
        cfg.trials(tr) = true;
        chans = data.label;
        cfg.channel = chans;
        data_stripped = rmfieldIfPresent(data,...
            {'interp', 'interpNeigh', 'art', 'chanExcl', 'art_type'});
        tmp = ft_selectdata(cfg, data_stripped);
        
        % extract channels with artefacts on this trial
        bad = art(:, tr);
        
        % find non-bad neighbours
        [canInterp, canInterpLabs, canInterpNb, canInterpSmry] =...
            eegAR_FindInterpChans(data, bad, false, nb);
        
        % store indices of channels that can't be interpolated
        cantInterp(:, tr) = bad & ~canInterp;
                
        
        if any(canInterp)
            % interpolate
            cfg = [];
            cfg.method = 'spline';
            cfg.badchannel = canInterpLabs;
            cfg.neighbours = canInterpNb;
            cfg.trials = 1;
            tmpi = ft_channelrepair(cfg, tmp);

            % replace original trial data
%             data.trial{tr} = tmpi.trial{:};

            % store interpolated data in temp structure
            tmp_trial{tr} = tmpi.trial{1};            
            tmp_bad{tr} = bad;
            tmp_canInterp{tr} = canInterp;
        end

    end
    
    % update flags
    for tr = 1:numTrials
        data.trial{tr} = tmp_trial{tr};
        interpNeigh(tmp_canInterp{tr}, tr) = tmp_canInterp(tr);    
        interp(tmp_canInterp{tr}, tr) = true;
        excl(tmp_bad{tr} & ~tmp_canInterp{tr}, tr) = true;   
    end
            
    % summarise interpolation
    data.interp = interp;
    data.cantInterp = cantInterp;
    data.interp_summary.trialsIntPerChan = sum(interp, 2);                    % num channels with any trials interpolated
    data.interp_summary.chansIntPerTrial = sum(interp, 1);                   % num trials with any channels interpolated
    data.interp_summary.totalNumIntSegs = sum(interp(:));                     % total num of chan x trial interpolations
    data.interp_summary.propSegsInt = data.interp_summary.totalNumIntSegs / length(interp(:));     % prop of chan x trial interpolations
    data.interp_summary.intNeighbours = interpNeigh;
    
end