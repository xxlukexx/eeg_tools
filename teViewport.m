classdef teViewport < handle
    
    properties
        Viewpane@teCollection
        WindowScale = .5;
        BackgroundColour = [158, 104, 175]        
    end
    
    properties (Dependent)
        IsOpen
        MonitorNumber 
        FullScreen 
        PositionPreset
        Size
    end
    
    properties (Dependent, SetAccess = private)
        ScreenResolution
        NumberOfViewpanes
    end
    
    properties (Access = private)
        % main settings
        prMonitorNumber 
        prPositionPreset
        prFullScreen = true
        prIsOpen = false;
        prWindowSize
        prWindowSizeSetManually = false
        prWinPtr
        % housekeeping
        prPTBOldSyncTests
        prPTBOldWarningFlag
        % listeners
        lsViewpane_AddItem
        lsViewpane_RemoveItem
        lsViewpane_Clear
    end

    methods 
        
        % constructor
        function obj = teViewport(varargin)
            % check PTB
            AssertOpenGL
            % disable sync tests and set PTB verbosity to minimum
            obj.prPTBOldSyncTests =...
                Screen('Preference', 'SkipSyncTests', 2);
            obj.prPTBOldWarningFlag =...
                Screen('Preference', 'SuppressAllWarnings', 1);
            % screen defaults
            obj.MonitorNumber = max(Screen('screens'));
            obj.PositionPreset = 'topleft';
            % if only one monitor, cannot be fullscreen
            if max(Screen('Screens')) == 0
                obj.prFullScreen = false;
            end
            % set window size coords
            obj.SetWindowSize
            % open window
            obj.Open       
            % init view pane collection
            obj.Viewpane = teCollection('teViewpane');
            obj.Viewpane.ChildProps = {'DrawBuffer'};
            % listeners
            obj.lsViewpane_AddItem = addlistener(obj.Viewpane,...
                'ItemAdded', @obj.InitialiseViewpane);
            obj.lsViewpane_RemoveItem = addlistener(obj.Viewpane,...
                'ItemRemoved', @obj.DestroyViewpane);   
            obj.lsViewpane_RemoveItem = addlistener(obj.Viewpane,...
                'ItemsCleared', @obj.DestroyAllViewpanes);                  
        end
        
        % destructor
        function delete(obj)
            % close open screen
            if obj.prIsOpen
                obj.Close
            end
           % reset PTB prefs
            Screen('Preference', 'SkipSyncTests', obj.prPTBOldSyncTests);
            Screen('Preference', 'SuppressAllWarnings',...
                obj.prPTBOldWarningFlag);
        end
        
        % screen
        function Open(obj)
            if obj.prIsOpen
                error('Screen already open.')
            end
            % if fullscreen, set flag to pass to PTB and set rect for
            % PTB window size
            if obj.prFullScreen
                fullscreenFlag = [];
                rect = [];
            else
                rect = obj.prWindowSize;
                fullscreenFlag = [];
            end
            % open window
            obj.prWinPtr = Screen('OpenWindow', obj.MonitorNumber,...
                obj.BackgroundColour, rect, [], [], [], 1, [], fullscreenFlag);
            % set up alpha blending and text font and antialiasing 
            Screen('BlendFunction', obj.prWinPtr, GL_SRC_ALPHA,...
                GL_ONE_MINUS_SRC_ALPHA);
            Screen('Preference', 'TextAlphaBlending', 1)
            Screen('TextFont', obj.prWinPtr, 'Menlo');
            % set flag
            obj.prIsOpen = true;
        end
        
        function Close(obj)
            if ~obj.prIsOpen
                error('Screen is not open.')
            end
            Screen('Close', obj.prWinPtr);
            obj.prIsOpen = false;
        end
        
        function Reopen(obj)
            if obj.prIsOpen
                obj.Close
                obj.Open
            end
        end   
        
        function Draw(obj)
            if isempty(obj.Viewpane)
                return
            end
            % loop through viewpanes and get all buffer commands
            numCmd = sum(cellfun(@size, obj.Viewpane.DrawBuffer));
            fn = cell(numCmd, 1);
            args = cell(numCmd, 1);
            s1 = 1;
            for i = 1:obj.Viewpane.Count
                vpa = obj.Viewpane.Items(i);
                % get drawbuffer
                s2 = obj.Viewpane.DrawBuffer{i}.Count;
                fn(s1:s2) = obj.Viewpane.Items{i}.DrawBuffer.function';
                args(s1:s2) = obj.Viewpane.Items{i}.DrawBuffer.args';
                s1 = s2 + 1;
            end
            % batch commands by function
            [fn_u, fn_i, fn_s] = unique(fn);
            numFn = length(fn_u);
            for i = 1:numFn
                % get indices to all args for this function
                idx = fn_s == i;
                % determine function 
                switch fn_u{i}
                    case 'FillRect'
                        % cols on 1st arg, rect on 2nd arg
                        allCols = cellfun(@(x) x{1}, args(idx),...
                            'uniform', false);
                        allCols = vertcat(allCols{:});
                        allRect = cellfun(@(x) x{2}, args(idx),...
                            'uniform', false);
                        allRect = vertcat(allRect{:});
                        % scale to norm
                        allRect = allRect / vpa.UnitScale;
                        % scale to px
                        allRect(:, [1, 3]) = allRect(:, [1, 3]) * obj.Size(3);
                        allRect(:, [2, 4]) = allRect(:, [2, 4]) * obj.Size(4);
                        % draw
                        Screen('FillRect', vpa.Ptr, allCols', allRect')
                end
            end
        end
        
        % viewpane management
        function InitialiseViewpane(obj, col, eventData)
            % get item
            vpa = col(eventData.Data);
            % open offscreen window
            vpa.Ptr = Screen('OpenOffscreenWindow', obj.prWinPtr,...
                [0, 0, 0, 0], obj.Size);
            % set view pane props
            vpa.AspectRatio = obj.Size(3) / obj.Size(4);
            vpa.Valid = true;
        end
        
        function DestroyViewpane(~, col, eventData)
            % get item
            vpa = col(eventData.Data);
            % close window
            Screen('Close', vpa.Ptr);
        end
        
        function DestroyAllViewpanes(~, col, ~)
            vpa = col.Items;
            % close all
            alreadyClosed = nan(size(vpa));
            for i = 1:length(vpa)
                ptrToClose = vpa{i}.Ptr;
                if ~ismember(ptrToClose, alreadyClosed)
                    Screen('Close', ptrToClose);
                    alreadyClosed(i) = ptrToClose;
                end
            end
        end
             
        % get / set 
        function val = get.IsOpen(obj)
            val = obj.prIsOpen;
        end
        
        function val = get.MonitorNumber(obj)
            val = obj.prMonitorNumber;
        end
        
        function set.MonitorNumber(obj, val)
            % set prop
            changed = ~isequal(val, obj.prMonitorNumber);
            obj.prMonitorNumber = val;
            if changed && obj.IsOpen
                obj.Reopen
            end
        end
                
        function val = get.FullScreen(obj)
            val = obj.prFullScreen;
        end
        
        function set.FullScreen(obj, val)
            % check val
            if ~islogical(val) && ~isscalar(val)
                error('FullScreen must be a logical scalar (true/false)')
            end
            % set val
            changed = ~isequal(obj.prFullScreen, val);
            obj.prFullScreen = val;
            % figure out window coords from the preset
            obj.SetWindowSize
            if changed && obj.IsOpen
                obj.Reopen
            end
        end
        
        function val = get.ScreenResolution(obj)
            val = Screen('Rect', obj.MonitorNumber);
        end
        
        function val = get.Size(obj)
            val = obj.prWindowSize;
        end
        
        function set.Size(obj, val)
            % check value
            if ~isnumeric(val) || ~isvector(val) || length(val) ~= 4 ||...
                    any(val) < 0
                error('Size must be a positive numeric vector of length 4.')
            elseif val(1) > val(3) || val(2) > val(4)
                error('Impossible rect values in Size - [x2, y2] must be < [x1, y1].')
            elseif val(3) > obj.ScreenResolution(3) ||...
                    val(4) > obj.ScreenResolution(4)
                error('Size cannot extend beyond the edges of the screen.')
            end
            % assign value and set flag to indicate a manual setting so
            % that preset is ignored
            obj.prWindowSize = val;
            obj.prWindowSizeSetManually = true;
        end
        
        function val = get.PositionPreset(obj)
            if obj.prWindowSizeSetManually
                val = 'manual';
            elseif obj.FullScreen
                val = 'fullscreen';
            else    
                val = obj.prPositionPreset;
            end
        end
        
        function set.PositionPreset(obj, val)
            % check value
            if ~ischar(val) || ~ismember(val, {'topleft', 'topright',...
                    'bottomleft', 'bottomright'})
                error(['Valid values for PositionPreset are: ''topleft'', ',...
                    '''topright'', ''bottomleft'', ''bottomright'''])
            end
            % set val
            changed = ~isequal(val, obj.prPositionPreset);
            obj.prPositionPreset = val;
            % set flag to indicate that a preset is being used, as opposed
            % to window size having been set manually
            obj.prWindowSizeSetManually = false;
            % figure out window coords from the preset
            obj.SetWindowSize
            if changed && obj.IsOpen && ~obj.FullScreen
                obj.Reopen
            end
        end
        
        function val = get.NumberOfViewpanes(obj)
            val = numel(obj.Viewpane);
        end
        
    end
    
    methods (Hidden, Access = private)
        
        % utilities
        function SetWindowSize(obj)
            if obj.prFullScreen
                obj.prWindowSize = obj.ScreenResolution;
            elseif ~obj.prWindowSizeSetManually
                % calculate to-be-set width and height of window from width and
                % height of screen
                w = obj.ScreenResolution(3) * obj.WindowScale;
                h = obj.ScreenResolution(4) * obj.WindowScale;
                % find x1, y1 from preset
                switch lower(obj.prPositionPreset)
                    case 'topleft'
                        x1 = 0;
                        y1 = 0;
                    case 'topright'
                        x1 = obj.ScreenResolution(3) - w;
                        y1 = 0;
                    case 'bottomleft'
                        x1 = 0;
                        y1 = obj.ScreenResolution(4) - h;
                    case 'bottomright'
                        x1 = obj.ScreenResolution(3) - w;
                        y1 = obj.ScreenResolution(4) - h;
                    otherwise
                        error('Invalid preset. Valid presets are: topleft, topright, bottomleft, bottomright.')
                end
                % set x2, y2 using width and height
                x2 = x1 + w;
                y2 = y1 + h;
                % set
                obj.prWindowSize = [x1, y1, x2, y2];
            end
        end          
        
    end
    
end