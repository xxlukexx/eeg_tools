function smry = eegAR_Summarise(data, smry)

    % art = eegAR_Summarise(data, art)
    %
    % Summary statistics about artefact detection. 
    
    smry.numBad = sum(data.art(:));
    smry.numGood = sum(~data.art(:));
    smry.propBad = smry.numBad / (smry.numBad + smry.numGood);
    smry.trialsBad = sum(any(data.art, 1));
    smry.trialsGood = sum(all(~data.art, 1));
    smry.trialsProp = smry.trialsBad / (smry.trialsBad + smry.trialsGood);
    smry.trialBreakdown = sum(data.art, 1);
    smry.chansBad = sum(any(data.art, 2));
    smry.chansGood = sum(all(~data.art, 2));
    smry.chansProp = smry.chansBad / (smry.chansBad + smry.chansGood);
    smry.chanBreakdown = sum(data.art, 2);
    smry.chanLabel = data.label;
    
end