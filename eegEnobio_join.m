function [suc, oc, data_out, info_out] = eegEnobio_join(path_out, varargin)

    suc = false;
    oc = 'unknown error';
    data_out = [];
    info_out = [];

    % check all input args are chars (paths to enobio data)
    if ~all(cellfun(@ischar, varargin))
        suc = false;
        oc = 'not all input arguments were char';
        return
    end
    
    num = length(varargin);
    if num == 1
        oc = 'only one data file passed';
        return
    end
    
    % can pass path to either .easy or .info, regardless, make sure both
    % are available
    [pth, fil, ~] = cellfun(@fileparts, varargin, 'UniformOutput', false);
    ext_easy = repmat({'.easy'}, 1, num);
    ext_info = repmat({'.info'}, 1, num);
    paths_easy = fullfile(pth, cellfun(@(x, y) [x, y], fil, ext_easy, 'UniformOutput', false));
    paths_info = fullfile(pth, cellfun(@(x, y) [x, y], fil, ext_info, 'UniformOutput', false));
    if ~all(cellfun(@(x) exist(x, 'file'), paths_easy))
        oc = 'could not find .easy files for all inputs';
        return
    end
    if ~all(cellfun(@(x) exist(x, 'file'), paths_info))
        oc = 'could not find .info files for all inputs';
        return
    end
    
    fprintf('Joining %d enobio files...\n', num);
    
    % load easy
    easy = cellfun(@load, paths_easy, 'UniformOutput', false);
    
    % join easy, then sort by timestamps to ensure correct order
    jeasy = vertcat(easy{:});
    [~, so] = sort(jeasy(:, end));
    jeasy = jeasy(so, :);
    data_out = array2table(jeasy);
    
    % check that timestamps increase monotonically. This should catch
    % duplicate timestamps as well, but (todo) monitor this and ensure
    % extra code isn't needed
    if any(diff(jeasy(:, end)) <= 0)
        suc = false;
        oc = 'joined timestamps did increase monotonically, check that these files should be joined';
        return
    end
    
    % additionally check for duplicates. Shouldn't be necessary but double
    % check
    if length(jeasy(:, end)) ~= length(unique(jeasy(:, end)))
        suc = false;
        oc = 'duplicate timestamps found in joined data';
    end
    
    % join info by taking the first info file and updating its "Number of
    % Records of EEG" field with the new, joined, value
    numSamps = size(jeasy, 1);
    info_out = fileread(paths_info{1});
    s1 = strfind(info_out, 'Number of records of EEG: ') +...
        length('Number of records of EEG: ');
    nl = strfind(info_out, newline);
    s2 = nl(find(nl > s1, 1, 'first')) - 1;
    numSamps_old = info_out(s1:s2);
    info_out = strrep(info_out, numSamps_old, num2str(numSamps));
    
    if ~isempty(path_out)

        % write updated info file
        filename_out = [fil{1}, '_joined.info'];
        file_out_info = fullfile(path_out, filename_out);
        fid = fopen(file_out_info, 'w+');
        fprintf(fid, '%s', info_out);
        fclose(fid);

        % write joined file
        filename_out = [fil{1}, '_joined.easy'];
        file_out_easy = fullfile(path_out, filename_out);
        writetable(data_out, file_out_easy,...
            'WriteVariableNames', false, 'FileType', 'text')    
        
    end

    suc = true;
    oc = '';
    

end