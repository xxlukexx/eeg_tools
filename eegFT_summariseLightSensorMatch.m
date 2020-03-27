function smry = eegFT_summariseLightSensorMatch(out)

    smry = [];
    
    if ~out.found
        smry = []; 
        return
    end
    
    % find matched light markers only
    idx_matched = ~isnan(out.error);
    val = out.mrk_ft_value(idx_matched);
    err = out.error(idx_matched) * 1e3;    
    
    smry.numLightMarkers = length(out.mrk_light_samps);
    smry.numMatchedLightMarkers = sum(idx_matched);
    smry.propMatchedLightMarkers = prop(idx_matched);
    smry.error_mu = mean(err) / 1e3;
    smry.error_med = median(err) / 1e3;
    smry.error_sd = std(err) / 1e3;
    
% calculate error by marker
    
    % marker type subs
    [type_u, ~, type_s] = unique(val);
    
    % aggregate error in ms
    m_mu = accumarray(type_s, err, [], @mean);
    m_med = accumarray(type_s, err, [], @median);
    m_sd = accumarray(type_s, err, [], @std);
    
    tab = table;
    tab.event = type_u;
    tab.error_mu = m_mu / 1e3;
    tab.error_med = m_med / 1e3;
    tab.error_sd = m_sd / 1e3;
       
%     subplot(1, 2, 1)
%     notBoxPlot(err, type_s, 'jitter', 0.5)
%     set(gca, 'XTickLabel', type_u)
%     
%     subplot(1, 2, 2)
%     hold on
%     for t = 1:length(type_u)
%         histogram(err(t == type_s), 'DisplayStyle', 'stairs', 'BinWidth', 5)
%     end
%     legend(arrayfun(@num2str, type_u, 'UniformOutput', false))

end
