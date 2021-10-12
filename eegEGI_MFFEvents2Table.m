function tab = eegEGI_MFFEvents2Table(path_mff)

    if ~exist(path_mff, 'file')
        error('File not found: %s')
    end
    
    % find events XML file inside the MFF
    file_ev = teFindFile(path_mff, 'Events*.xml', '-largest');
    if isempty(file_ev)
        error('No files named Events*.xml found in MFF file.')
    end
    
    % check that we have the xml2struct function 
    if exist('xml2struct', 'file') ~= 2
        error('Cannot find the xml2struct.m function.')
    end
    fprintf('Reading events from MFF file: %s...\n', path_mff)
    xml = xml2struct(file_ev);
    
    % parse XML and build table of event info
    
        fprintf('Parsing events...\n');
    
        % flatten XML struct, because none of the information we need on
        % events is hierachical. 
        ev = cellfun(@lm_flattenStruct, xml.eventTrack.event,...
            'UniformOutput', false);
        
        % convert cell array of structs to struct array, then to a table
        ev = vertcat(ev{:});
        tab = struct2table(ev);
        
        fprintf('Read %d events.\n', size(tab, 1));
        
        % remove any _XXX from variable names
        parts = cellfun(@(x) strsplit(x, '_'), tab.Properties.VariableNames,...
            'UniformOutput', false);
        tab.Properties.VariableNames = lower(...
            cellfun(@(x) x{1}, parts, 'UniformOutput', false));
        
    % convert EGI absolute event times to both posix and relative (zeroed
    % to first event) times
 
        % get session start time
        t_start = eegEGI_MFFReadSessionStartTime(path_mff);
        
        % convert times to posix
        tab.posixtime = eegEGI_absTime2Relative(tab.begintime);
        tab.reltime = tab.posixtime - t_start;

end