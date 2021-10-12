function eegFT_testPlotLightSensor(ft_data)

    [found, chan] = eegFT_findLightSensorChannel(ft_data);
    if ~found
        error('No light sensor channel found.')
    end
    chan = find(chan);
%     chan = 8;

    event = ft_data.events;
    
        
        cfg = [];
        cfg.detrend = 'yes';
%     cfg.bpfilt = 'yes';
%     cfg.bpfreq = [0.1, 40];
    ft_data = ft_preprocessing(cfg, ft_data);
    ft_data.events = event;

    wantedEvents = [21, 22, 23, 24, 25, 26, 27, 28, 29];
%     wantedEvents = 21;

    % get trial onset samples and event values
    samps = [event.sample]';
    vals = [event.value]';  
    
    % face -> 500ms
    idx = ismember(vals, wantedEvents);
    samps = samps(idx);
    vals = vals(idx);
    
    % define trial duration and baseline
    duration_secs = .800;
    baseline_secs = .200;
    duration_samps = round(duration_secs * 500);
    baseline_samps = round(baseline_secs * 500);
    
    % define trials
    s1 = round(samps - baseline_samps);
    s2 = round(samps + duration_samps);
    offset = repmat(-baseline_samps, size(s1));
    
    % return fieldtrip trial definition
    cfg = [];
    cfg.trl = [s1, s2, offset, vals];
    
    

    
     data_seg = ft_redefinetrial(cfg, ft_data);
    
    figure
    subplot(2, 1, 1)
    numTrials = length(data_seg.trial);
    for t = 1:numTrials
        
        plot(data_seg.time{t}, data_seg.trial{t}(chan, :))
        hold on
        
    end
    
    [data_cor, smry] = eegFT_correctFromLightSensor(ft_data, [], [], 21);
    
    
  % get trial onset samples and event values
  event = data_cor.events;
    samps = [event.sample]';
    vals = [event.value]';  
    
    % face -> 500ms
    idx = ismember(vals, wantedEvents);
    samps = samps(idx);
    vals = vals(idx);
    
    % define trial duration and baseline
    duration_secs = .800;
    baseline_secs = .200;
    duration_samps = round(duration_secs * 500);
    baseline_samps = round(baseline_secs * 500);
    
    % define trials
    s1 = round(samps - baseline_samps);
    s2 = round(samps + duration_samps);
    offset = repmat(-baseline_samps, size(s1));
    
    % return fieldtrip trial definition
    cfg = [];
    cfg.trl = [s1, s2, offset, vals];
     data_cor_seg = ft_redefinetrial(cfg, data_cor);

    subplot(2, 1, 2)
    numTrials = length(data_seg.trial);
    for t = 1:numTrials
        
        plot(data_cor_seg.time{t}, data_cor_seg.trial{t}(chan, :))
        hold on
        
    end
    
    
end
    
    
