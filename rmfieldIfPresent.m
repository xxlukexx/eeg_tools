function s = rmfieldIfPresent(s, fields_remove)

    for f = 1:length(fields_remove)
        if isfield(s, fields_remove{f})
            s = rmfield(s, fields_remove{f});
        end
    end
    
end