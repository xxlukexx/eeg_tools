function [suc, oc, t1, t2, data_type] =...
    eegEnobio_readFirstAndLastSampleFromInfoFile(path_info)

    % Initialize output variables
    suc = false;
    oc = 'unknown error';
    t1 = nan;
    t2 = nan;
    data_type = 'unrecognised';

    try
        % Open the file for reading
        fid = fopen(path_info, 'rt');
        if fid == -1
            oc = 'File cannot be opened';
            return;
        end

        % Read the file line by line
        while ~feof(fid)
            line = fgetl(fid);

            % Find the first timestamp
            if contains(line, 'StartDate (firstEEGtimestamp):')
                t1_str = strtrim(extractAfter(line, 'StartDate (firstEEGtimestamp):'));
                t1 = str2double(t1_str) / 1000;
            end

            % Find the number of EEG records
            if contains(line, 'Number of records of EEG:')
                num_records_str = strtrim(extractAfter(line, 'Number of records of EEG:'));
                num_records = str2double(num_records_str);
            end

            % Find the EEG sampling rate
            if contains(line, 'EEG sampling rate:')
                sampling_rate_str = strtrim(extractAfter(line, 'EEG sampling rate:'));
                sampling_rate = str2double(extractBefore(sampling_rate_str, ' Samples/second'));
            end
        end

        % Close the file
        fclose(fid);

        % Calculate the last timestamp
        if ~isnan(t1) && ~isnan(num_records) && ~isnan(sampling_rate)
            duration_seconds = num_records / sampling_rate;
            t2 = t1 + duration_seconds;
            data_type = 'enobio';
            suc = true;
            oc = '';
        else
            oc = 'Required information not found in the file';
        end

    catch
        oc = 'Error occurred while reading the file';
        if fid ~= -1
            fclose(fid);
        end
    end

end
