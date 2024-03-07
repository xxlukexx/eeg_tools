classdef EEGVis_data < handle
    
    properties
        
    end
    
    properties (SetAccess = private)
        Data
    end
    
    properties (Dependent, SetAccess = private)
        NumChannels
        NumTrials
    end
    
    methods
        
        function obj = EEGVis_data(fieldtrip_data)
            
            if ~isstruct(fieldtrip_data) ||...
                    ~isfield(fieldtrip_data, 'trial') ||...
                    ~isfield(fieldtrip_data, 'time') ||...
                    ~isfield(fieldtrip_data, 'label') 
                
                error('Must pass a fieldtrip data structure')
                
            end
            
            obj.Data = fieldtrip_data;
            
        end
        
        % get/set
        function val = get.NumChannels(obj)
            if isempty(obj.Data)
                val = [];
            else
                val = length(obj.Data.label);
            end
        end
        
        function val = get.NumTrials(obj)
            if isempty(obj.Data)
                val = [];
            else
                val = length(obj.Data.trial);
            end
        end 
        
    end
    
end