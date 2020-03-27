function eegAR_Visualise(varargin)

    % eegAR_Visualise(varargin)
    %
    % Displays a heatmap of channels (rows) with good and bad trials marked
    % in different colours
    
    num = length(varargin);
    numSP = numSubplots(num);
    for i = 1:num
        subplot(numSP(1), numSP(2), i)
        imagesc(varargin{i});
        title(sprintf('%d bad', sum(varargin{i}(:))))
    end

end