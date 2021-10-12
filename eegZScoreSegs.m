function zData = eegZScoreSegs(data)

    lens = cellfun(@(x) size(x, 2), data.trial);
    cont = horzcat(data.trial{:});
    zcont = zscore(cont, [], 2);
    zData = data;
    
    for tr = 1:length(data.trial)
        s1 = 1 + ((tr - 1) * lens(tr));
        s2 = tr * lens(tr);
        zData.trial{tr} = zcont(:, s1:s2);
    end

end