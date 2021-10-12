function event = eeg_char2enobio(c)
    
    % convert to cell array of binary numbers
    bin = arrayfun(@dec2bin, c, 'uniform', false);
    
    % convert to one long binary number, then to int32
    event = bin2dec(horzcat(bin{:}));

end
    
    