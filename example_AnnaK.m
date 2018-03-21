ft_defaults
% load, rename to data
load('/Users/luke/Downloads/A20_filt.mat')
data = A20_filt;
% load electrode locations
data.elec = ft_read_sens('/Users/luke/Google Drive/Experiments/face erp/fieldtrip-20161116/template/electrode/GSN-HydroCel-129.sfp');
% select only EEG channels
cfg = [];
cfg.channel = 'eeg';
data = ft_selectdata(cfg, data);
% detect
data_clean = eegAR_Detect(data, 'method', 'alpha', 'maxsd', 2.5);
data_clean = eegAR_Detect(data_clean, 'method', 'range', 'threshold', 15);
data_clean = eegAR_Detect(data_clean, 'method', 'minmax', 'threshold', [-5, 5]);
% find channels that are noisy throughout - can optionally interpolate
% these
chanNoisy = eegAR_ChannelThreshold(data_final, .9);
% interpolate
data_int = eegInterpTrial2(data_clean, 5);
% reset AR marks post-interpolation (so interpolated channels aren't marked
% as having artefacts any more)
data_int = eegAR_ResetArtFromInterp(data_int);
% manual edit
vis = ECKEEGVis;
vis.Data = data_int;
vis.StartInteractive
% flatten artefact types
art_any = any(data_final.art, 3);       
artByChan = sum(art_any, 2);
artByTrial = sum(art_any, 1);
% summarise
subplot(2, 1, 1)
bar(artByTrial)
xlabel('Trial')
set(gca, 'XTick', 1:length(data_final.trial))
set(gca, 'XTickLabelRotation', 90)
ylabel('Num chans with artefacts')
subplot(2, 1, 2)
bar(artByChan)
xlabel('Channel')
set(gca, 'XTick', 1:length(data_final.label))
set(gca, 'XTickLabel', data_final.label)
set(gca, 'XTickLabelRotation', 90)
ylabel('Num trials with artefacts')


