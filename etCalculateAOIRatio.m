function tab = etCalculateAOIRatio(tab, var1, var2, outVar)

    if ~ismember(var1, tab.Properties.VariableNames)
        error('Table variable %s not found.', var1)
    end

    if ~ismember(var2, tab.Properties.VariableNames)
        error('Table variable %s not found.', var2)
    end
    
    if ~exist('outVar', 'var') || isempty(outVar)
        % make output variable name
        outVar = sprintf('%s_%s_ratio', var1, var2);
    end
    
    % calculate ratio and write to table
    val = tab.(var1) ./ (tab.(var1) + tab.(var2));
    tab.(outVar) = val;
    
    % reorder columns so that new ratio variable is as close to var1/2 as
    % possible. This can only be done on Matlab R2018 onwards, so check
    % first
    if iskeyword('movevars')
        idx_var1 = find(strcmpi(var1, tab.Properties.VariableNames), 1);
        tab = movevars(tab, outVar, 'After', var1);
    end
    
end