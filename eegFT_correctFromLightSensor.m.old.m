function data_ft = eegFT_correctFromLightSensor(data_ft, light)

    if ~light.found
        warning('Light sensor channel not found.')
        return
    end
    
    % make table from light marker output
    tab = struct2table(data_ft.events);
    
    % store pre-corrected values
    tab.sample_uncorrected = tab.sample;
    
    for e = 1:size(tab, 1)
        
        idx_ft = find(light.mrk_ft_samps == tab.sample(e));
        if ~isempty(idx_ft)
            tab.sample(e) = light.mrk_light_samps(idx_ft);
        end
        
    end
    
    data_ft.events = table2struct(tab);
    
    
%     % get indices of ft events from light table. Remove NaNs (these are
%     % light markers that could not be matched to ft events)
%     idx = light.mrk_ft_samps;
%     val_corr = light.mrk_light_samps;
%     notMatched = isnan(idx);
%     idx(notMatched) = [];
%     val_corr(notMatched) = [];
%     
%     idx_ft = arrayfun(@(x) find(tab.sample == x), idx, 'UniformOutput', false)
%     
%     % replace original ft event indices with light marker sample indices
%     tab.sample(idx_ft) = val_corr;

end