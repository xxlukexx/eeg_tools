function smry = eegAR_Summarise(data, smry)

    % art = eegAR_Summarise(data, art)
    %
    % Summary statistics about artefact detection. 
    numTrials = size(data.art, 2);
    numChannels = size(data.art, 1);
    
    % combos - trial x channel combinations
    anyArt = any(data.art, 3);
    smry.combos.total = numel(anyArt);
    smry.combos.good = sum(~anyArt(:));
    smry.combos.bad = sum(anyArt(:));
    smry.combos.propGood = prop(~anyArt(:));
    
    % trials 
    trArt = any(anyArt, 1);
    smry.trials.marks = trArt;
    smry.trials.total = length(trArt);
    smry.trials.good = sum(~trArt);
    smry.trials.bad = sum(trArt);
    smry.trials.propGood = smry.trials.good / smry.trials.total;
    smry.trials.channelProp = sum(anyArt, 1) ./ numChannels;
    
    % channels
    chArt = any(anyArt, 2);
    smry.channels.marks = chArt;
    smry.channels.total = length(chArt);
    smry.channels.good = sum(~chArt);
    smry.channels.bad = sum(chArt);
    smry.channels.propGood = smry.channels.good / smry.channels.total;
    smry.channels.trialProp = sum(anyArt, 2) ./ numTrials;
        
    % breakdown by event
    if isfield(data, 'trialinfo')
        % get event subscripts
        [ev_u, ~, ev_s] = unique(data.trialinfo);
        % calculate stats over each event type
        ev_total = accumarray(ev_s, trArt, [], @(x) size(x, 1))';
        ev_tpc = accumarray(ev_s, ~trArt, [], @sum)';
        ev_prop = accumarray(ev_s, 1 - trArt, [], @prop)';
        if iscell(ev_u)
            varNames = cellfun(@(x) sprintf('Cond_%s', x), ev_u,...
                'uniform', false);
        else
            varNames = arrayfun(@(x) sprintf('Cond_%d', x), ev_u,...
                'uniform', false);
        end
        smry.event = array2table([ev_total; ev_tpc; ev_prop], 'RowNames',...
            {'Total', 'Num_good', 'Prop_good'}, 'VariableNames', varNames);
    end
        
end