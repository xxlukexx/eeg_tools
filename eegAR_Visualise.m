function eegAR_Visualise(varargin)

    num = length(varargin);
    numSP = numSubplots(num);
    for i = 1:num
        subplot(numSP(1), numSP(2), i)
        imagesc(varargin{i}.matrix);
        title(sprintf('%d bad', sum(varargin{i}.matrix(:))))
    end

end