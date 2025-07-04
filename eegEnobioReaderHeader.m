function res = eegEnobioReaderHeader(file_info)
%EEGENOBIOREADERHEADER  Parse Enobio header text into a MATLAB struct.
%
%   res = eegEnobioReaderHeader(file_info) takes the raw header contents
%   returned by an Enobio EEG system (as a char array, string, or cell
%   array of character vectors) and converts every key‑value line of the
%   form "Name: Value" into a field/value pair inside the struct res.
%
%   • Field names are converted to valid MATLAB identifiers using
%     matlab.lang.makeValidName.  Spaces, parentheses, etc. are removed or
%     replaced with underscores so you can access them as res.FieldName.
%   • Numeric values (e.g. "3026" or "0") are automatically converted to
%     double; everything else is stored as text.
%   • Duplicate keys are gathered into a cell array (e.g. the EEG montage
%     entries "Channel 1: P7", "Channel 2: P4", … become
%     res.Channel_1, res.Channel_2, …).
%   • Parsing stops at the line starting with "Trigger information:", as
%     the trigger table is usually formatted differently and was not
%     requested.
%
%   Example:
%       txt = fileread('session_header.txt');
%       hdr = eegEnobioReaderHeader(txt);
%       disp(hdr.StartDate_firstEEGtimestamp_);  % numeric Unix time‑stamp
%
% ----------------------------------------------------------------------
% 1. Normalise input into a cell array of trimmed strings
% ----------------------------------------------------------------------
if ischar(file_info) || (isstring(file_info) && isscalar(file_info))
    lines = regexp(file_info, '\r?\n', 'split');
elseif isstring(file_info)
    lines = cellstr(file_info);
elseif iscellstr(file_info)
    lines = file_info;
else
    error('file_info must be a char, string, or cellstr.');
end

% Strip leading/trailing white‑space from each line
lines = strtrim(lines(:)');

% ----------------------------------------------------------------------
% 2. Iterate through lines, extracting "key: value" pairs
% ----------------------------------------------------------------------
res = struct();

for k = 1:numel(lines)
    ln = lines{k};

    % Stop when the Trigger section begins (not needed per instruction)
    if startsWith(ln, 'Trigger information', 'IgnoreCase', true)
        break;
    end

    % Skip empty lines and those without a colon
    cIdx = find(ln == ':', 1, 'first');
    if isempty(cIdx)
        continue;
    end

    keyRaw   = strtrim(ln(1:cIdx-1));
    valueRaw = strtrim(ln(cIdx+1:end));

    % Convert to valid MATLAB field name
    % (matlab.lang.makeValidName is R2015b+. Fallback otherwise.)
    if exist('matlab.lang.makeValidName', 'file')
        fieldName = matlab.lang.makeValidName(keyRaw, 'ReplacementStyle', 'delete');
    else
        fieldName = regexprep(keyRaw, '[^a-zA-Z0-9]', '_');
        % Ensure it does not start with a number
        if ~isempty(fieldName) && isstrprop(fieldName(1), 'digit')
            fieldName = ['x_' fieldName];
        end
    end

    % Attempt numeric conversion (purely numeric strings only)
    numericValue = str2double(valueRaw);
    if ~isnan(numericValue) && ~isempty(regexpi(valueRaw, '^\s*[+-]?[0-9\.eE]+\s*$'))
        parsedValue = numericValue;
    else
        parsedValue = valueRaw;  % leave as char
    end

    % Handle duplicates (put into cell array)
    if isfield(res, fieldName)
        if ~iscell(res.(fieldName))
            res.(fieldName) = {res.(fieldName)}; %#ok<STRNU>
        end
        res.(fieldName){end+1} = parsedValue;
    else
        res.(fieldName) = parsedValue;
    end
end

end % function
