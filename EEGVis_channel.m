classdef EEGVis_channel < handle
    
    properties
        Data EEGVis_data
        X
        Y
        Width
        Height
        CurrentTrial = 1
        Ylim = [-100, 100]
        BGColour = [030, 030, 050]        
        LineColour = [100, 200, 100];
        ArtefactColour = [200, 100, 100];
        AxesColour = [200, 200, 200];
    end
    
    properties (SetAccess = private)
        ChannelName
        Ptr
    end
    
    properties (Access = private)
        channelIdx
        subjectAverage
    end
    
    methods
        
        function obj = EEGVis_channel(data, channel_name, viewpane_ptr, x, y, w, h)
            
            % store data objects
            obj.Data = data; 
            
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
            obj.subjectAverage = nanmean(all_trials, 3);
            obj.subjectAverage = obj.subjectAverage(obj.channelIdx, :);
            
        end
        
        function Update(obj)
            
            
            
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
            
                [coords_avg, x_px_avg, y_px_avg] = obj.Voltage2Pixels(t, obj.subjectAverage);
                
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

            % draw
            
                % axes
                Screen('DrawLine', obj.Ptr, obj.AxesColour .* .6, zero_x_px, 0, zero_x_px, obj.Height)
                Screen('DrawLine', obj.Ptr, obj.AxesColour .* .6, 0, zero_y_px, obj.Width, zero_y_px)
        
                % eeg
                Screen('DrawLines', obj.Ptr, coords, 1, line_col, [], 1);
                Screen('DrawLines', obj.Ptr, coords_avg, 3, obj.AxesColour, [], 1);                
                
                % frame and label
                Screen('FrameRect', obj.Ptr, line_col, [0, 0, obj.Width, obj.Height]);
                Screen('DrawText', obj.Ptr, obj.ChannelName, 2, 2, obj.AxesColour);
                
                % artefact types
                if has_art
                    Screen('DrawText', obj.Ptr, art_str, 2, 20, line_col);
                end
            
            fprintf('Channel %s drawn\n', obj.ChannelName)
            
        end
        
        function [xyForDrawLines, x_px, y_px] = Voltage2Pixels(obj, t, eeg)
            
            % Normalize time data to range from 0 to 1
            tNorm = (t - min(t)) / (max(t) - min(t));

            % Scale normalized time values to fit within channel width
            x_px = tNorm * obj.Width;            
            
            % Scale EEG values according to Ylim
            % First, normalize eeg values based on Ylim
            eegNorm = (eeg - obj.Ylim(1)) / (obj.Ylim(2) - obj.Ylim(1));
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
        
    end
    
end