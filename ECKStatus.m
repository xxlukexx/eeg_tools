classdef ECKStatus < handle
    
    properties
    end
    
    properties (Dependent)
        Status
    end

    properties (SetAccess=private, GetAccess=public)
    end
    
    properties (SetAccess=private, GetAccess=private)
    end
    
    properties (Dependent, SetAccess=private, GetAccess=public)
    end
    
    properties (Access=private)
        oldStatus
        status
    end
    
    events
    end
    
    methods

        function P = ECKStatus(newStatus)
            P.Status = newStatus;
        end
        
        function PrintStatus(P)
            if ~isempty(P.oldStatus) 
                strBackSpace = sprintf('%s', repmat('\b', 1, length(P.oldStatus)));
                fprintf(strBackSpace);
            end
            if ~isempty(P.Status)
                fprintf('%s', P.Status)
            end
        end
        
        function set.Status(P, newVal)
            P.oldStatus = P.Status;
            P.status = newVal;
            P.PrintStatus            
        end
        
        function newVal = get.Status(P)
            newVal = P.status;
        end
        
    end
    
end