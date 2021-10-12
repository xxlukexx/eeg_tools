function t_posix = eegEGI_absTime2Relative(t_abs)
    
    if ischar(t_abs)
        t_abs = {t_abs};
    elseif ~iscellstr(t_abs)
        error('Must pass either a char (string) or cellstr (cell array of strings) to this function.')
    end
    num = length(t_abs);

    t_posix = nan(num, 1);
    for i = 1:num
        t_posix(i) = egi2posix(t_abs{i});        
    end

end

function t_posix = egi2posix(t_abs)

    % e.g. '2019-06-04T14:54:53.218984+01:00'
    
    if ~ischar(t_abs) || length(t_abs) ~= 32
        error('t_abs must be char of length 32.')
    end
    
    % first check that we have the pattern of ummutable characters (such as
    % - and +)
    immut = t_abs([5, 8, 11, 14, 17, 20, 27, 30]);
    if ~strcmp(immut, '--T::.+:')
        error('Unreadable time format: %s', t_abs);
    end

    % matlab does not handle microsecs so convert the portion up to seconds
    % using datetime, then store the microsecs separately
    t1 = datetime(t_abs(1:19), 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss');
    t_posix = posixtime(t1);
    
    % now add microsecs
    microsecs = str2double(t_abs(21:26));
    t_posix = t_posix + (microsecs / 1e6);

end