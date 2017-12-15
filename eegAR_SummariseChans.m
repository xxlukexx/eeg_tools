function [bad, prop] = eegAR_SummariseChans(art, crit)

    prop = mean(art.matrix, 2);
    bad = prop > crit;
    
end