function art = eegAR_Summarise(data, art)

    art.numBad = sum(art.matrix(:));
    art.numGood = sum(~art.matrix(:));
    art.propBad = art.numBad / (art.numBad + art.numGood);
    art.trialsBad = sum(any(art.matrix, 1));
    art.trialsGood = sum(all(~art.matrix, 1));
    art.trialsProp = art.trialsBad / (art.trialsBad + art.trialsGood);
    art.trialBreakdown = sum(art.matrix, 1);
    art.chansBad = sum(any(art.matrix, 2));
    art.chansGood = sum(all(~art.matrix, 2));
    art.chansProp = art.chansBad / (art.chansBad + art.chansGood);
    art.chanBreakdown = sum(art.matrix, 2);
    art.chanLabel = data.label;
    
end