function eegAR_Summary(data, art)

    % eegAR_Summary(data, art)
    %
    % Displays a summary table of number and proportion of artefacts per
    % channel
    
    numArt = sum(art.matrix, 2);
    propArt = arrayfun(@(x) sprintf('%.1f%%', x),...
        (numArt / length(data.trial) * 100), 'uniform', false);
    
    tab = table(numArt, propArt, 'rownames', data.label',...
        'variablenames', {'Num_Artefacts', 'Prop_Artefacts'});
    disp(tab)
    
end