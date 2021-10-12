function [chanLabel, chanIdx] = eegAR_ChannelThreshold(data, threshold)
%[chanLabel, chanIdx] = EEGAR_CHANNELTHRESHOLD(data, threshold) finds
%channels with proportion of artefacts > threshold. chanLabel is a cell
%array of string containing the labels of thoes channels above threshold,
%chanIdx are the numeric indices of those channels. 

    % get number of chans/trials
    numChans        = size(data.trial{1}, 1);
    numTrials       = length(data.trial);
    
    % does art field exist?
    if ~isfield(data, 'art') 
        error('.art field not found.')
    end
    
    % get, and flatten, art, then compute prop per channel
    art = any(data.art, 3);
    prop = sum(art, 2) / numTrials;
    exceeds = prop >= threshold;
    chanLabel = data.label(exceeds);
    chanIdx = find(exceeds);
    
end
    