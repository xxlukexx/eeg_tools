function [suc, oc, smry] = eegEnobio_join(varargin)

    suc = false;
    oc = 'unknown error';

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
    [~, so] = sort(jeasy(:, 13));
    jeasy = jeasy(so, :);
    
    % join info by taking the first info file and updating its "Number of
    % Records of EEG" field with the new, joined, value
    numSamps = size(jeasy, 1);
    info = fileread(paths_info{1});
    s1 = strfind(info, 'Number of records of EEG: ') +...
        length('Number of records of EEG: ');
    nl = strfind(info, newline);
    s2 = nl(find(nl > s1, 1, 'first')) - 1;
    numSamps_old = info(s1:s2);
    info = strrep(info, numSamps_old, num2str(numSamps));

    % write updated info file
    filename_out = [fil{1}, '_joined.info'];
    path_out = fullfile(pth{1}, filename_out);
    fid = fopen(path_out, 'w+');
    fprintf(fid, '%s', info);
    fclose(fid);
    
    % write joined file
    filename_out = [fil{1}, '_joined.easy'];
    path_out = fullfile(pth{1}, filename_out);
    writetable(array2table(jeasy), path_out,...
        'WriteVariableNames', false, 'FileType', 'text')    

    suc = true;
    oc = '';
    

end