function [tab_count, tab_prop] = eegAR_BatchSummariseType(smry)

    stat = ECKStatus('Summarising artefact types...');
    
    % find unique artefact types
    num = length(smry);
    numTrialElec = zeros(num, 1);
    allTypes = {};
    for s = 1:num
        stat.Status = sprintf('Finding unique artefact types... %.1f%%...',...
            s / num * 100);
        at = smry(s).artType;
        empt = cellfun(@isempty, at);
        at(empt) = [];
        u1 = unique(at);
        parts = cellfun(@(x) strsplit(x, '_'), u1, 'uniform', false);
        parts = horzcat(parts{:});
        u2 = unique(parts);
        allTypes = [allTypes; u2'];
        numTrialElec(s) = numel(smry(s).art);
    end
    u = unique(allTypes);
    
    % prepare table to store results
    cnt = zeros(num, length(u));
    prop = zeros(num, length(u));
    
    % for each dataset, count number of each type
    guid = parProgress('INIT');
    parfor s = 1:num
        parProgress(guid, s, num);
        fprintf('Counting artefact types... %.1f%%...\n',...
            parReadProgress(guid) * 100);        
        at = smry(s).artType;
        
        % find trials with artefacts on any electrode
        artTr = any(smry(s).art, 1)
        
        % find list of artefact types for each trial
        for tr = 1:length(artTr)
            % get artefact types for this trial
            typeTr = at(:, tr);
            % remove empty
            typeTr(cellfun(@isempty, typeTr)) = [];
            % count
            uTypeTr = {};
            for t = 1:length(typeTr)
                uTypeTr = [uTypeTr, strsplit(typeTr{t}, '_')];
            end
            uTypeTr = unique(uTypeTr);     
            for v = 1:length(uTypeTr)
                idx = find(strcmpi(u, uTypeTr{v}), 1, 'first');
                tmp = cnt(s, :);
                tmp(idx) = tmp(idx) + 1;
                cnt(s, :) = tmp;     
            end
        end
    end

    % calculate proportions
    for s = 1:num
        prop(s, :) = cnt(s, :) ./ size(smry(s).art, 2);
    end
    
    tab_count = array2table(cnt, 'variablenames', u);
    tab_prop = array2table(prop, 'variablenames', u);
    
    figure
    bar(cnt, 'stacked', 'barwidth', 1)
    hold on
    stairs(cellfun(@(x) size(x, 2), {smry.art}), 'r', 'linewidth', 2)
    xlabel('Participant')
    ylabel('Number of trials with artefact')
    legend([u; 'Total trials'])
    
    clear stat
    
end
