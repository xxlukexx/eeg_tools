function [data, events, t] = eegEnobio2Fieldtrip(file_easy)
% Reads Neuroelectrics .easy, and produces a fieldtrip data structure. It
% looks for a matching header (.info) file with the same filename. 

% check input file

    if exist('file_easy', 'var') && isempty(file_easy)
        if iscell(file_easy)
            error('Multiple EEG files.')
        elseif ~ischar(file_easy)
            error('Path to .easy file in incorrect format (not char)')
        elseif ~exist(file_easy, 'file')
            error('File not found: %s', file_easy)
        end
    end
    
% use the path and filename to construct a matching .info file for the
% .easy file. 
    
    % break apart absolute path into path and filename
    [pth, nme, ~] = fileparts(file_easy);
    
    % build a path to the expected .info file
    file_info = sprintf('%s.%s', fullfile(pth, nme), 'info');
    
    % check that the .info file exists
    if ~exist(file_info, 'file')
        warning('.info file [%s] not found. Will attempt to recreate.',...
            file_info)
        recreateHeader = true;
    else
        recreateHeader = false;
    end
    
% attempt to load the raw data from the .easy file. Since this is in ASCII
% format, we can use Matlab's load function to get a matrix containing the
% EEG data

    fprintf('Attempting to load raw (.easy) file...\n');    
    try
        raw = load(file_easy);

    catch ERR_loadRaw
        error('Error loading raw (.easy) file. Error was:\n%s',...
            ERR_loadRaw.message)

    end
    fprintf('Success\n')   
    
% attempt to load the header (.info) file. This uses the Neuroelectrics
% NE_ReadInfoFile function, and returns the number of channels, sampling
% rate, channel labels and number of samples

    if ~recreateHeader
    % read from disk
        
        fprintf('Attempting to load header (.info) file...\n');
        try
            [numChans, fs, chanLabels, numSamples] =...
                NE_ReadInfoFile(file_info, 9);
            
            % read first sample field from info file
            fid = fopen(file_info);
            str = fscanf(fid, '%s');
            s1 = strfind(str, 'StartDate(firstEEGtimestamp):') +...
                length('StartDate(firstEEGtimestamp):');
            s2 = strfind(str, 'Deviceclass:') - 1;
            firstSamp = str2double(str(s1:s2));
            fclose(fid);

        catch ERR_loadInfo
            error('Error loading info file. Error was:\n%s',...
                ERR_loadInfo.message)

        end 
        fprintf('Success\n') 
        
    else
    % recreate
    
        % Enobio .easy files have nChans + 5 columns (last 5 are
        % accelerometer [x, y, z], marker, timestamp)
        numChans = size(raw, 2) - 5;
        
        % sample rate for all Enobio's at time of writing is hard 500Hz,
        % but check against the timestamps in case this changes in future
        fs = round(1000 / median(diff(raw(:, end))));
        if fs ~= 500
            warning('Calculated sample rate was %.2fHz, 500Hz was expected.',...
                fs)
        end
        
        % cannot determine channel labels without the info file, so label
        % them ch1, ch2, etc.
        chanLabels = arrayfun(@(x) sprintf('Ch%0d', x), 1:numChans,...
            'uniform', false);
        warning('Default channel labels were used.')
        
        % number of samples is easy
        numSamples = size(raw, 1);
        
        % first sample is left as empty, since it is not available (it
        % doesn't seem to be the same thing as the first timestamp, I
        % suspect this is not corrected by the synchroniser)
        firstSamp = [];
        
    end
    
% put the header info into a fieldtrip-compatible struct
    
    hdr.numChans        = numChans;
    hdr.fs              = fs;
    hdr.chanLabels      = chanLabels;
    hdr.numSamples      = numSamples;
    
    
% convert the raw data from the .easy file to fieldtrip format. Since this
% is continuous data, we create one "trial" by placing both a vector of
% timestamps (ft .time field) and matrix of EEG data (ft .trial field) in a
% one-element cell array
        
    % channel labels are a cell array of strings - we take these from the
    % header (.info) file
    data.label = chanLabels;
    
    % the time vector comes from the last column of the raw matrix. The
    % timestamps are in POSIX format so we zero these. They are also
    % integers in ms, so convert to seconds
    data.time = {(raw(:, end) - raw(1, end)) / 1e3};
    
    % raw EEG data is in the first n columns of the raw matrix, where n =
    % numChans. The data are in nanovolts, so convert to microvolts
    data.trial = {raw(:, 1:numChans)' ./ 1e3};  
    
    % append the header struct
    data.enobio_hdr = hdr;
    
    % set sampling rate
    data.fsample = fs;
    
    % since this is one long "trial", add sampleinfo encompassing the
    % indices of the first an last sample
    data.sampleinfo = [1, numSamples];
    
    % remove any leading/trailing spaces in electrode labels
    data.label = strrep(data.label, ' ', '');
    
% convert events. These are stored in the penultimate column of the raw
% matrix. Most of these values are 0, which means "no event on this sample
% of data". Anything non-zero is an event. 

%     % if events weren't requested as an output arg, skip this bit
%     if nargout == 1, return, end

    % get sample indices of events
    ev_sample = find(raw(:, end - 1) ~= 0);
    numEvents = length(ev_sample);  
    
    % all events are of type "eeg" so replicate this for the number of
    % events
    ev_type = repmat({'eeg'}, numEvents, 1);
    
    % use the sample indices to find the values of events in the raw matrix
    ev_value = raw(ev_sample, end - 1);
    
    % put all values into a cell array
    ev_cell = [num2cell(ev_sample), ev_type, num2cell(ev_value)];
    
    % now convert to struct
    events = cell2struct(ev_cell, {'sample', 'type', 'value'}, 2);
    
    % store struct in main ft_data
    data.events = events;
    
% extract timestamps from enobio data and convert to seconds
    
    if nargin == 2, return, end
    t = raw(:, end) / 1000;
    
    % write timestamps into .abstime field
    data.abstime = t;
    
end