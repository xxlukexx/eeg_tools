function start_posix = eegEGI_MFFReadSessionStartTime(path_mff)

    if ~exist(path_mff, 'file')
        error('File not found: %s')
    end
    
    % find events XML file inside the MFF
    file_info = fullfile(path_mff, 'info.xml');
    if isempty(file_info)
        error('No files named info.xml found in MFF file.')
    end
    
    % check that we have the xml2struct function 
    if exist('xml2struct', 'file') ~= 2
        error('Cannot find the xml2struct.m function.')
    end
    fprintf('Reading events from MFF file: %s...\n', path_mff)
    xml = xml2struct(file_info);
    
    info = lm_flattenStruct(xml.fileInfo);
    start_egi = info.recordTime_Text;
    start_posix = eegEGI_absTime2Relative(start_egi);
    
end