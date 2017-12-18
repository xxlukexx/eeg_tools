function [bad, prop] = eegAR_SummariseChans(art, crit)

    % [bad, prop] = eegAR_SummariseChans(art, crit)
    %
    % Takes an artefact structure art and calculates the proportion of valid
    % trials per channels. Applies a criterion (e.g. .5) to these
    % proportions and returns a logical index, with each element
    % representing whether each channel exceeds the criterion
    
    prop = mean(art.matrix, 2);
    bad = prop > crit;
    
end