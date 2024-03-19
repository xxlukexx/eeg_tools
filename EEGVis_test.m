% load('/Users/luke/Library/CloudStorage/OneDrive-King''sCollegeLondon/R1_alpha_20240220/02_clean_1_30/694129804972808_retest_ft_clean.mat')

port = teViewport;
port.FullScreen = false;
data = EEGVis_data(data_clean);
tl = vpaTimeline_EEGArtefacts(data_clean);
vis = EEGVis_viewpane(data);
port.Viewpane('eegvis') = vis;
port.Viewpane('timeline') = tl;

while true
    port.Draw;
    port.Refresh;
end