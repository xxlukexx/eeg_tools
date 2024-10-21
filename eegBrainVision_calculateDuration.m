function [durationSeconds, numChannels, samplingInterval] =...
    eegBrainVision_calculateDuration(path_vhdr)

    % Open the .vhdr file
    fid = fopen(path_vhdr, 'r');
    if fid == -1
        error('Unable to open the vhdr file');
    end

    % Initialize variabless
    samplingInterval = NaN;
    numChannels = NaN;
    dataFile = '';

    % Read through the file to extract the relevant information
    while ~feof(fid)
        line = fgetl(fid);

        % Extract Sampling Interval in microseconds
        if contains(line, 'SamplingInterval=')
            samplingInterval = str2double(extractAfter(line, 'SamplingInterval='));
        end

        % Extract Number of Channels
        if contains(line, 'NumberOfChannels=')
            numChannels = str2double(extractAfter(line, 'NumberOfChannels='));
        end

        % Extract Data File name
        if contains(line, 'DataFile=')
            dataFile = extractAfter(line, 'DataFile=');
        end
    end

    % Close the file after reading
    fclose(fid);

    % Check if all the necessary information was extracted
    if isnan(samplingInterval) || isnan(numChannels) || isempty(dataFile)
        error('Missing required information from the vhdr file');
    end

    % Load the .eeg file to calculate the duration
    
        % two ways of finding the file, either use the filename as
        % specified in the header file (preferred), or look for the same
        % filename as header file, but with vhdr replaced with eeg. In
        % cases where the file has been manually renamed, this latter
        % option may be necessary
        
        % option 1 -- path from header
        [path, ~, ~] = fileparts(path_vhdr);
        path_eeg_from_header = fullfile(path, dataFile);   
        
        if ~exist(path_eeg_from_header, 'file')
            % option 2 -- path from switching vhdr to eeg extension
            path_eeg_from_extension = strrep(path_vhdr, 'vhdr', 'eeg');
            % make this the path to load
            path_eeg = path_eeg_from_extension;
        else
            path_eeg = path_eeg_from_header;
        end
        
        if ~exist(path_eeg, 'file')
            error('Missing .eeg file, tried both: \n\t%s\n\t%s\n',...
                path_eeg_from_header, path_eeg_from_extension)
        end
        
    % Assume the .eeg file is in the same directory as the .vhdr file


    % Get the size of the .eeg file
    fileInfo = dir(path_eeg);
    fileSizeBytes = fileInfo.bytes;

    % Calculate the number of data points in the file
    % Each data point is 4 bytes (IEEE_FLOAT_32) per channel
    bytesPerSample = 4 * numChannels;

    % Total number of samples in the EEG data
    numSamples = fileSizeBytes / bytesPerSample;

    % Calculate duration in seconds (samplingInterval is in microseconds)
    durationSeconds = numSamples * (samplingInterval * 1e-6);

    % Store the duration in the summary structure
    smry.duration = durationSeconds;
    smry.num_channels = numChannels;
    smry.fs = samplingInterval;

end