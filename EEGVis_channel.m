classdef EEGVis_channel < handle
    
    properties
        Data EEGVis_data
        X
        Y
        Width
        Height
        CurrentTrial = 1
        YLim = [-100, 100]
        BGColour = [030, 030, 050]        
        LineColour = [100, 200, 100];
        ArtefactColour = [200, 100, 100];
        AxesColour = [200, 200, 200];
        CursorColour = [200, 200, 050];
        Debug = false
    end
    
    properties (SetAccess = private)
        ChannelName
        Ptr
        HasMouse = false
    end
    
    properties (Access = private)
        channelIdx
        subjectAverage
        viewpane
        relativeMousePos
        needsDraw = true
    end
    
    methods
        
        function obj = EEGVis_channel(data, channel_name, viewpane_ptr, x, y, w, h, viewpane)
            
            % store data objects
            obj.Data = data; 
            obj.viewpane = viewpane;
            
            % ensure channel_name exists in data
            obj.channelIdx = find(strcmpi(obj.Data.Data.label, channel_name));
            if isempty(obj.channelIdx) 
                error('Channel %s not found in data.', channel_name)
            end
            obj.ChannelName = channel_name;
            
            % store position 
            obj.X = x;
            obj.Y = y;
            obj.Width = w;
            obj.Height = h;
               
            % make drawing texture
            rect = [obj.X, obj.Y, obj.X + obj.Width, obj.Y + obj.Height];
            obj.Ptr = Screen('OpenOffscreenWindow', viewpane_ptr, obj.BGColour, rect);
            
            % enable alpha blending
            Screen('BlendFunction', obj.Ptr, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            
            % default text size
            Screen('TextSize', obj.Ptr, 14)
            
            % make average
            obj.MakeAverage
            
            obj.Draw
            
        end
        
        function MakeAverage(obj)
            
            if ~isempty(obj.Data.Art)
                any_art = any(obj.Data.Art, 3);
                idx_art_trial = any_art(obj.channelIdx, :);
            else
                idx_art_trial = false(1, obj.Data.NumTrials);
            end
          
            all_trials = cat(3, obj.Data.Data.trial{~idx_art_trial});
            if isempty(all_trials)
                obj.subjectAverage = nan;
            else
                obj.subjectAverage = nanmean(all_trials, 3);
                obj.subjectAverage = obj.subjectAverage(obj.channelIdx, :);
            end
            
        end
        
        function didDraw = Update(obj)
            
            if obj.Debug
                fprintf('[EEGVis_channel.Update]: Needs drawing: %d\n', obj.needsDraw)
            end            
            
            didDraw = false;
            if obj.needsDraw
                obj.Draw
                obj.needsDraw = false;
                didDraw = true;
            end
            
        end
        
        function Draw(obj)
            
            % clear
            Screen('FillRect', obj.Ptr, obj.BGColour)
            
            % extract time and EEG data for the current trial, as vectors
            t = obj.Data.Data.time{obj.CurrentTrial};
            eeg = obj.Data.Data.trial{obj.CurrentTrial}(obj.channelIdx, :);
            
            % scale time and volate to pixels

                [coords, x_px, y_px] = obj.Voltage2Pixels(t, eeg);
                
            % scale time and average to pixels
            
                if ~isnan(obj.subjectAverage)
                    [coords_avg, x_px_avg, y_px_avg] = obj.Voltage2Pixels(t, obj.subjectAverage);
                    average_available = true;
                else 
                    coords_avg = nan;
                    average_available = false;
                end
                    
                
            % find position of x and y axis lines
            
                % find zero point in time and voltage
                idx_zero_x = find(abs(t) == min(abs(t)), 1);
                idx_zero_y = find(abs(eeg) == min(abs(eeg)), 1);
                
                % find pixel values for zero points
                zero_x_px = x_px(idx_zero_x);
                zero_y_px = y_px(idx_zero_y);
                
            % determine presence of artefacts
            
                line_col = obj.LineColour;
                if ~isempty(obj.Data.Art)
                    this_channel_art = squeeze(obj.Data.Art(obj.channelIdx, obj.CurrentTrial, :));
                    has_art = any(this_channel_art);
                    if has_art
                        art_str = sprintf('%s / ', obj.Data.Data.art_type{this_channel_art});
                        art_str = art_str(1:end - 3);
                        line_col = obj.ArtefactColour;
                    end
                end
                
            % if the mouse is over this channel, draw a vertical cursor
            % line
            
                if obj.HasMouse
                    
                    mx = obj.relativeMousePos(1);
                    my = obj.relativeMousePos(2);
                    
                    % get cursor pos
                    cx = mx;
                    cy1 = 0;
                    cy2 = obj.Height;
                    
                    % get latency and voltage at mouse 
                    
                        % find proportion of width and height that mouse
                        % pos represents
                        mx_prop = mx / obj.Width;
                        my_prop = my / obj.Height;
                        
                        % convert from prop to time and voltage
                        s1 = round(mx_prop * length(t));
                        if s1 < 1, s1 = 1; end
                        if s1 > length(t); s1 = length(t); end
                        mx_t = t(s1);
                        my_eeg = eeg(s1);
                        
                        % make label string
                        str_cursor = sprintf('[%dms, %.2fµV]', mx_t * 1000, my_eeg); 
                        
                end

            % draw
            
                % axes
                Screen('DrawLine', obj.Ptr, obj.AxesColour .* .6, zero_x_px, 0, zero_x_px, obj.Height)
                Screen('DrawLine', obj.Ptr, obj.AxesColour .* .6, 0, zero_y_px, obj.Width, zero_y_px)
        
                % eeg
                Screen('DrawLines', obj.Ptr, coords, 1, line_col, [], 1);
                if average_available
                    Screen('DrawLines', obj.Ptr, coords_avg, 3, obj.AxesColour, [], 1);                
                end
                
                % frame and label
                Screen('FrameRect', obj.Ptr, line_col, [0, 0, obj.Width, obj.Height]);
                Screen('DrawText', obj.Ptr, obj.ChannelName, 2, 2, obj.AxesColour);
                
                % artefact types
                if has_art
                    Screen('DrawText', obj.Ptr, art_str, 2, 20, line_col);
                end
                
                % cursor
                if obj.HasMouse
                    Screen('DrawLine', obj.Ptr, obj.CursorColour, cx, cy1, cx, cy2)
                    Screen('DrawText', obj.Ptr, str_cursor, mx, my - 20, obj.CursorColour);
                end
            
            if obj.Debug
                fprintf('[EEGVis_channel.Draw]: Channel %s drawn\n', obj.ChannelName)
            end
            
        end
        
        function MouseHitTest(obj, mx, my)
            
            hadMouse = obj.HasMouse;
            
            % is the mouse over this channel?
            obj.HasMouse =...
                mx >= obj.X &&...
                mx < obj.X + obj.Width &&...
                my >= obj.Y &&...
                my < obj.Y + obj.Height;
            
            % get the mouse pos relative to the rect of this object 
            if obj.HasMouse
                mx_rel = mx - obj.X;
                my_rel = my - obj.Y;
                obj.relativeMousePos = [mx_rel, my_rel];
            
%                 if obj.Debug
%                     fprintf('[EEGVis_channel.MouseHitTest]: Channel %s has the mouse\n', obj.ChannelName)
%                 end       
                
            end
            
            % redraw if we currently have the mouse, or if we had it last
            % update and don't this update
            obj.needsDraw = obj.HasMouse || hadMouse;
            
        end
        
        function [xyForDrawLines, x_px, y_px] = Voltage2Pixels(obj, t, eeg)
            
            % Normalize time data to range from 0 to 1
            tNorm = (t - min(t)) / (max(t) - min(t));

            % Scale normalized time values to fit within channel width
            x_px = tNorm * obj.Width;            
            
            % Scale EEG values according to Ylim
            % First, normalize eeg values based on Ylim
            eegNorm = (eeg - obj.YLim(1)) / (obj.YLim(2) - obj.YLim(1));
            % Then, scale to fit within channel height (invert y-axis)
            y_px = (1 - eegNorm) * obj.Height; 

            % Combine x and y coordinates
            eeg_px = [x_px; y_px]';    

            % Assuming eeg_px is an N x 2 matrix where N is the number of points
            N = size(eeg_px, 1);

            % Preallocate xyForDrawLines with one less than double the number of points (to account for the duplicated points)
            xyForDrawLines = zeros(2, 2*N-2);

            % Loop through each point to duplicate them accordingly
            for i = 1:(N-1)
                % Start point of current line segment
                xyForDrawLines(:, 2*i-1) = eeg_px(i, :)';
                % End point of current line segment (which is the start of the next)
                xyForDrawLines(:, 2*i) = eeg_px(i+1, :)';
            end
                
        end
        
        function set.Debug(obj, val)
            obj.Debug = val;
            fprintf('Debug set to %d\n', val);
        end
        
    end
    
end