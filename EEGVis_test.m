load('/Users/luke/Library/CloudStorage/OneDrive-King''sCollegeLondon/R1_alpha_20240220/02_clean/99141000203100_test_ft_clean.mat')

port = teViewport;
data = EEGVis_data(data_clean);
vis = EEGVis_viewpane(data);
port.Viewpane('eegvis') = vis;

while true
    port.Refresh;
end