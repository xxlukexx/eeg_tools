function [ indices ] = findcontig( search, sought )
    %UNTITLED2 Summary of this function goes here
    %   Detailed explanation goes here

    indices=[];

    founds=find(search==sought);
    if isempty(founds)
        % sought value not found in search array
        return
    end

    notfounds=find(search~=sought);
    if isempty(notfounds)
        % search array was full of sought values
        indices=[1,size(search,1), 1];
    end

    curVal=1;
    while curVal < size(founds,1)
        startIdx=founds(curVal);
        endIdx=notfounds(find(notfounds>founds(curVal),1,'first'))-1;
        if isempty(endIdx)
            % sought values continue till end
            endIdx=size(search,1);
            curVal=size(founds,1);
        else
            curVal=find(founds>endIdx,1,'first');
        end
        indices=[indices; startIdx, endIdx, endIdx-startIdx+1];
    end

end

