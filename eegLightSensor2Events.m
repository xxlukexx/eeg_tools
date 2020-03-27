function mrk = eegLightSensor2Events(data, thresh)
% takes a vector of EEG data from one channel, and thresholds it to find
% the on/offset of light sensor activity. Extracts onset and produces event
% markers for each. 
%
% data is a double vector of voltages
%
% thresh is the threshold voltage value in µV, above which activation of
% the light sensor is assumed
%
% mrk is a vector of sample indices corresponding to the start of each
% light sensor activation. Note that this function doesn't deal in
% timestamps - these can optionally be used later on if a time vector is
% available, but since not all EEG provides this we restrict ourselves to
% samples here. 
%
% data are quite noisy when the light sensor is on (one example shows a
% range of ~10µV). Currently not attempting to smooth/denoise this, since
% that is likely to shift the onset, and accurate onset is what we care
% about. 

% setup

    % check input
    if ~isnumeric(data) || ~isvector(data)
        error('data must be a numeric vector of voltage values.')
    end
    
    % default threshold is 1000µV
    if ~exist('thresh', 'var') || isempty(thresh)
        thresh = 1000;
    end
    
% threshold

    % logical index of all samples during which the light sensor was active
    idx = data >= thresh;
    
    % convert to contiguous structure to find on/offsets
    ct = findcontig2(idx);
    
    % extract onset
    mrk = ct(:, 1);

end