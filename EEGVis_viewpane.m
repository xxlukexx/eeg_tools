classdef EEGVis_viewpane < teViewpane
    
    properties
        CurrentTrial = 1
        FGColour = [200, 200, 200]
        BGColour = [030, 030, 050]      
        Debug = false
    end
    
    properties (SetAccess = private)
        Data EEGVis_data
        Channels 
        TimeLine
    end
    
    properties (Dependent, SetAccess = private)
        Valid 
    end
    
    properties (Access = private)
        isInitialised = false
        channelLayoutPx
        yLimChange = [0, 0]
    end
    
    events
        MouseOverChannel
        MouseClickOnChannel
    end
    
    methods
        
        function obj = EEGVis_viewpane(data)
            
            % store data
            obj.Data = data; 
                        
        end
        
        function Update(obj)
            

                
        end
        
        function Initialise(obj)
             
            % create channel layout in pixels for display
            obj.MakeChannelLayout
            
            % make channel objects
            obj.MakeChannels
            
            % add keypress event listerner
            addlistener(obj.Parent, 'KeyPressed', @obj.HandleKeyboard);
            
            obj.isInitialised = true;
            
        end
        
        function MakeChannelLayout(obj)
            
            pos_x = obj.Data.Layout.pos(:, 1);
            pos_y = obj.Data.Layout.pos(:, 2);
            
            % centre with [0, 0] being top-left
            pos_x = pos_x + abs(min(pos_x));
            pos_y = pos_y + abs(min(pos_y));
            
            % normalise between 0-1 on both axes
            pos_x = pos_x ./ max(pos_x);
            pos_y = pos_y ./ max(pos_y);
            
            % flip y axis
            pos_y = 1 - pos_y;
            
            % convert to pixels
            obj.channelLayoutPx =...
                round([pos_x .* obj.Width, pos_y .* obj.Height]);
            
        end
        
        function MakeChannels(obj)
            
            obj.Channels = cell(obj.Data.NumChannels, 1);
            for c = 1:obj.Data.NumChannels
                
                % find layout position for this channel
                idx_layout = strcmpi(obj.Data.Layout.label, obj.Data.Data.label{c});
                
                % create channel object
                obj.Channels{c} = EEGVis_channel(...
                    obj.Data,...                            
                    obj.Data.Data.label{c},...
                    obj.ParentPtr,...
                    obj.channelLayoutPx(idx_layout, 1),...
                    obj.channelLayoutPx(idx_layout, 2),...
                    120, 120,...
                    obj);
                
                % set debug
                obj.Channels{c}.Debug = obj.Debug;
                
            end
            
        end
        
        function Draw(obj)
            
            if ~obj.isInitialised
                obj.Initialise
            end
       
            % clear
            Screen('FillRect', obj.Ptr, obj.BGColour);
            
%             Screen('FrameRect', obj.Ptr, [255, 000, 255], [0, 0, obj.Size]);
            
            for c = 1:length(obj.Channels)
                
                obj.Channels{c}.Update;         
                
                x = obj.Channels{c}.X;
                y = obj.Channels{c}.Y;
                w = obj.Channels{c}.Width;
                h = obj.Channels{c}.Height;
                rect_dest = [x, y, x + w, y + h];
                channel_ptr = obj.Channels{c}.Ptr;

                Screen('DrawTexture', obj.Ptr, channel_ptr, [], rect_dest);
                
            end
            
            str_trial = sprintf('Trial %04d of %04d', obj.CurrentTrial, obj.Data.NumTrials);
            Screen('DrawText', obj.Ptr, str_trial, 2, 2, obj.FGColour);
            
%             obj.TimeLine.Draw;
            
            if obj.Debug
                fprintf('[EEGVis_viewpane.Draw]: finished drawing\n')
            end
            
        end
        
        function HandleKeyboard(obj, ~, event)
            
            keyName = KbName(event.Data{1});
            if isscalar(keyName) || ischar(keyName)
                
                switch keyName

                    case 'LeftArrow'
                        obj.MoveToPreviousTrial
                    case 'RightArrow'
                        obj.MoveToNextTrial
                    case 'UpArrow'
                        obj.IncreaseYLim
                    case 'DownArrow'
                        obj.DecreaseYLim
                end
                
            end
            
        end
        
        function MoveToPreviousTrial(obj)
            ct = obj.CurrentTrial - 1;
            if ct < 1
                ct = 1;
            end
            obj.CurrentTrial = ct;
        end
        
        function MoveToNextTrial(obj)
            ct = obj.CurrentTrial + 1;
            if ct > obj.Data.NumTrials
                ct = obj.Data.NumTrials;
            end
            obj.CurrentTrial = ct;
        end
        
        function CurrentTrialChanged(obj)
            fprintf('Trial changed to %d\n', obj.CurrentTrial);
            for c = 1:length(obj.Channels)
                obj.Channels{c}.CurrentTrial = obj.CurrentTrial;
                obj.Channels{c}.Draw
            end
            obj.Parent.Draw
        end
        
        function IncreaseYLim(obj)
            obj.yLimChange = [1.4, 1.4];
            obj.YLimChanged
        end
        
        function DecreaseYLim(obj)
            obj.yLimChange = [.7, .7];
            obj.YLimChanged
        end
        
        function YLimChanged(obj)
                       
            for c = 1:length(obj.Channels)
                obj.Channels{c}.YLim = obj.Channels{c}.YLim ./ obj.yLimChange;
                obj.Channels{c}.Draw;
            end
            
            obj.yLimChange = [0, 0];
            
        end
        
        function HandleMouseMove(obj, ~, event)
            
            % find the channel that the mouse is over
            mx = event.Source.MouseX;
            my = event.Source.MouseY;
            
            for c = 1:length(obj.Channels)
                obj.Channels{c}.MouseHitTest(mx, my);
            end
            
        end
        
        % get/set
        function val = get.Valid(~)
            val = true;
        end
        
        function set.CurrentTrial(obj, val)
            obj.CurrentTrial = val;
            obj.CurrentTrialChanged
        end
        
    end
    
end