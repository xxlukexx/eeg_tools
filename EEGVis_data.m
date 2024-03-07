classdef EEGVis_data < handle
    
    properties
        
    end
    
    properties (SetAccess = private)
        Data
        Layout
        Art
    end
    
    properties (Dependent, SetAccess = private)
        NumChannels
        NumTrials
    end
    
    methods
        
        function obj = EEGVis_data(fieldtrip_data)
            
            % ensure fieldtrip is installed
            try
                ft_defaults
            catch ERR
                error('Error when trying to intialise fieldtrip (make sure it is installed)\n\n\t%s', ERR.message)
            end
            
            if ~isstruct(fieldtrip_data) ||...
                    ~isfield(fieldtrip_data, 'trial') ||...
                    ~isfield(fieldtrip_data, 'time') ||...
                    ~isfield(fieldtrip_data, 'label') 
                
                error('Must pass a fieldtrip data structure')
                
            end
            
            obj.Data = fieldtrip_data;
            
            % attempt to load layout info for this dataset
            obj.LoadLayout
            
            % attempt to read artefact marks
            obj.ReadArtefactMarks
            
        end
        
        function LoadLayout(obj, layout_file)
            
            % default to 10-10 layout 
            if ~exist('layout_file', 'var') || isempty(layout_file)
                layout_file = 'EEG1010.lay';
            end
            
            try
                cfg = [];
                cfg.layout = layout_file;
                obj.Layout = ft_prepare_layout(cfg, obj.Data);
            catch ERR
                error('Error when attempting to load a layout file:\n\n\t%s', ERR.message)
            end
            
        end
        
        function ReadArtefactMarks(obj)
            
            if isfield(obj.Data, 'art')
                obj.Art = obj.Data.art;
            end
            
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