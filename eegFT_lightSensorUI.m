classdef eegFT_lightSensorUI < handle
    
    properties
        Data    
        Session teSession
        
        % colours
            BackgroundColor = [0.15, 0.15, 0.20]
            ForegroundColor = [0.90, 0.85, 0.75]
            LightSensorColor = [0.60, 0.65, 0.85]
            EventColor = [0.60, 0.35, 0.20];
            CalculatedColor = [1.0, 0.0, 1.0];
            IgnoreColor = [0.45, 0.15, 0.20]
            AttendColor = [0.15, 0.45, 0.20]
            
        DrawLightSensorSampleDelta = true
        Crit_DurationRange = [0.140, 0.210];
        Crit_ThresholdZ = 4;
    end
    
    properties (SetAccess = private)
        idxLightSensorChannel
        WantedEEGEvents
        ValidReason = 'uninitialised'
    end
    
    properties (Dependent, SetAccess = private)
        Valid
        LightSensorChannelLabel 
        DurationEEG
        DurationSession
    end
    
    properties (Access = private)
        % general
        debug = true;

        % ui 
        uiFig
        uiGraph
            uiGraph_axes
                % zoom
                ui_zoomRectHandle
                ui_zoomStartPoint
                ui_mouseIsDown = false
                % select
                ui_selectedRectHandle
                ui_selectedStartPoint
                ui_graphSelection
        uiControls
        uiSessionInfo
            uiSessionInfo_label
        uiEvents
            uiEvents_table
            uiEvents_beingUpdated = false
            uiEvents_selection
        uiBeingCreated = false
        uiBeingUpdated = false

            % button controls
            ui_btnScrollLeft
            ui_btnScrollRight
            ui_btnHorizZoomIn
            ui_btnHorizZoomOut
            ui_btnHorizZoomReset
            ui_btnVertZoomIn
            ui_btnVertZoomOut
            ui_btnVertZoomReset
            ui_btnMouseZoom
            ui_btnMouseSelect
            ui_btnIgnoreSelection
            ui_btnLightSensor2Events
            
            % tools
            uiCurrentTool = 'none'
            
        % zoom etc
        leftEdgeX
        visibleDuration
        amplitudeYLim
        amplitudeScale
        
        % events
        formattedEvents
        selectedEventIdx = nan
        lightSensorEventTable 

        % data
        lsDelta
        lsDelta_z
        visibleDataDownsampled
        visibleDataOriginal
        visibleTimeDownsampled
        visibleTimeOriginal
        visiblePreprocDataDownsampled
        visibleDeltaDownsampled
        visibleDeltaZDownsampled
        preprocData
        ignoredSegments 
    end
    
    properties (Constant)
        CONST_DEF_LEFT_EDGE_X = 0;
        CONST_DEF_VISIBLE_DURATION = 600;
        CONST_DEF_AMPLITUDE_SCALE = 1;
        CONST_MIN_AMPLITUDE_Y_RANGE = 1;    % µV
    end
        
    methods
        
        function obj = eegFT_lightSensorUI(ft_data, ses_data, wanted_eeg_events, idx_ls_channel)
            
            % a light sensor channel index and optionally be specified, if
            % it's not then set it to be empty
            if ~exist('idx_ls_channel', 'var') 
                idx_ls_channel = [];
            end
            
            if ~exist('wanted_eeg_events', 'var')
                wanted_eeg_events = [];
            end
            obj.WantedEEGEvents = wanted_eeg_events;
            
            % store FT data
            obj.Data = ft_data;
            
            % store session data
            obj.Session = ses_data;
            
            % find light sensor channel in the EEG data
            obj.FindLightSensor(idx_ls_channel)
            obj.PreprocessLightSensor;
            obj.PostprocessLightSensor;
            
            % turn off inane TEX interpreter for labels
            set(groot, 'defaultTextInterpreter', 'none');
            set(groot, 'defaultLegendInterpreter', 'none');
            set(groot, 'defaultAxesTickLabelInterpreter', 'none');
            set(groot, 'defaultColorbarTickLabelInterpreter', 'none');
            
        end
        
        function delete(obj)
            try
                delete(obj.uiFig)
            catch ERR
                fprintf('[deconstructor]: Error deleting figure: %s\n', ERR.Message);
            end
        end
        
        % data
        
        function FindLightSensor(obj, idx_ls_channel)
            
            channel_specified = ~isempty(idx_ls_channel);
            
            % if channel is specified then set it and do nothing more
            if channel_specified
                obj.idxLightSensorChannel = idx_ls_channel;
                return
            end
            
            % if channel wasn't specified then try to ID it
            
                 [anyFound, idx_chan, reason, ft_data] =...
                     eegFT_findLightSensorChannel(obj.Data);
                 
                 % no light sensor data found
                 if ~anyFound
                     error('Automatic ID of the light sensor channel failed: %s',...
                         reason)
                 end
                 
                 % store
                 obj.idxLightSensorChannel = idx_chan;
            
        end
        
        function PreprocessLightSensor(obj)
            
            % 1. HP filter
            cfg = [];
            cfg.dftfilter = 'yes';
%             cfg.dftfreq = 50;
%             cfg.polyremoval = 'yes';
%             cfg.hpfilter = 'yes';
%             cfg.hpfreq = 1;
%             cfg.hpfilttype = 'firws'; % but, firws, fir, firls
%             cfg.lpfilter = 'yes';
%             cfg.lpfreq = 20;
%             cfg.hpfiltord = 1;
            obj.preprocData = ft_preprocessing(cfg, obj.Data);
   
        end
        
        function PostprocessLightSensor(obj)
            
            ls = obj.ApplyIgnoredSegments;

            % sample delta
            obj.lsDelta = [nan, diff(ls)];
            
%             obj.lsDelta_z = movingAverageZScore(obj.lsDelta, 5, 1, 500);
            obj.lsDelta_z = nanzscore(obj.lsDelta);
            
        end

        function ls = ApplyIgnoredSegments(obj)

            % pull the light sensor data from the fieldtrip structure in
            % obj.Data, then set any periods within ignoredSegments to NaN
            ls = obj.Data.trial{1}(obj.idxLightSensorChannel, :);

            num_ignored_segs = size(obj.ignoredSegments, 1);
            if num_ignored_segs > 0
                
                for s = 1:num_ignored_segs
                    
                    % ignoredSegments are [t1, t2] times in seconds
                    s1 = obj.EEGTime2Sample(obj.ignoredSegments(s, 1));
                    s2 = obj.EEGTime2Sample(obj.ignoredSegments(s, 2)); 
                
                    ls(s1:s2) = nan;
                    
                end

            end

        end
        
        function LightSensor2Events(obj)
            
            % we want 1) threshold sample deltas 2) refer to raw values and
            % find runs with flat slope that 3) ends with another spike
            
            obj.PostprocessLightSensor;
            
            % create sample deltas and investigate timing of gaps between
            % pairs
%             ls = obj.ApplyIgnoredSegments;
%             ls = obj.Data.trial{1}(obj.idxLightSensorChannel, :);
            t = obj.Data.time{1};
%             t = obj.visibleTimeDownsampled;
%             ls = obj.visibleDataDownsampled;
%             ls_delta = obj.lsDelta;
            ls_delta_z = obj.lsDelta_z;
%             ls_delta = [nan, diff(ls)]; 
%             ls_delta_z = nanzscore(ls_delta);
            
            thresh_z = obj.Crit_ThresholdZ;
            idx_thresh = abs(ls_delta_z) >= thresh_z;
            idx_thresh_on = ls_delta_z >= thresh_z;
            idx_thresh_off = ls_delta_z <= -thresh_z;
            
            % thresholded values may be runs of several samples but we only
            % want one onset. find runs of samples and find the onset of
            % each. 
            ct = findcontig2(~idx_thresh);
            
%                 % temp for visible data -- add left edge sample index
%                 left_edge_samples = obj.EEGTime2Sample(obj.leftEdgeX);
%                 ct(:, 1:2) = ct(:, 1:2) + left_edge_samples;
            
            ctt = contig2time(ct, t);
            
            ct_on = findcontig2(idx_thresh_on);
            ct_off = findcontig2(idx_thresh_off);
            
%                 % temp for visible data -- add left edge sample index
%                 ct_on(:, 1:2) = ct_on(:, 1:2) + left_edge_samples;
%                 ct_off(:, 1:2) = ct_off(:, 1:2) + left_edge_samples;
            
            num_on = size(ct_on, 1);
            num_off = size(ct_off, 1);
%             if num_on > num_off
%                 ct_on(end, :) = [];
%             end
%             num_on = size(ct_on, 1);
%             num_off = size(ct_off, 1);
            
            ctt_on = contig2time(ct_on, t);            
            ctt_off = contig2time(ct_off, t);
            
            
            

            % calculate the duration of each run
%             dur = ctt_off(:, 1) - ctt_on(:, 1);
            
            % create events
            tab_events = table;
%             tab_events.local_time = ctt_on(:, 1);
            tab_events.label = repmat({'LIGHT_SENSOR_ON'}, num_on, 1);
            tab_events.eeg_code = nan(num_on, 1);
            tab_events.wanted = true(num_on, 1);
            tab_events.sample = ct_on(:, 1);
            tab_events.timestamp = nan(num_on, 1);
            tab_events.source = repmat({'light_sensor'}, num_on, 1);
            tab_events = sortrows(tab_events, 'sample');
            
            obj.lightSensorEventTable = tab_events;
            
            delete(obj.uiEvents_table)
            obj.CreateUI_Events

            
        end
                
        function SyncData(obj)
            
            [sync, tracker_synced] = ...
                teSyncEEG_fieldtrip(obj.Session.Tracker, obj.Data);
            
            
            
            
            
            
            
            
            
        end
        
        function MarkIgnored(obj)
            
            % assuming a selection has been set, append it to the end of
            % the current list of ignored segments
            
            if isempty(obj.ui_graphSelection), return, end
                
            obj.ignoredSegments =...
                [obj.ignoredSegments; obj.ui_graphSelection];
            
            obj.Draw
            
        end
        
        % graph
        
        function UpdateGraph(obj)
            
            if obj.debug
                fprintf('[UpdateGraph]: running\n');
            end
            
            % set default values if this is the first run
            
                if isempty(obj.leftEdgeX)
                    obj.leftEdgeX = obj.CONST_DEF_LEFT_EDGE_X;
                end
                if isempty(obj.visibleDuration)
                    obj.visibleDuration = obj.CONST_DEF_VISIBLE_DURATION;
                end
                if isempty(obj.amplitudeScale)
                    obj.amplitudeScale = obj.CONST_DEF_AMPLITUDE_SCALE;
                end
                if isempty(obj.amplitudeYLim)
                    yl_min = min(obj.Data.trial{1}(:));
                    yl_max = max(obj.Data.trial{1}(:));
                    obj.amplitudeYLim = [yl_min, yl_max];
                end
                
            % manage bounds and data limits on the x-axis (time)

                % ensure that the visible duration doesn't exceed the data
                % duration
                if obj.visibleDuration > obj.DurationEEG
                    obj.visibleDuration = obj.DurationEEG;
                    obj.leftEdgeX = 0;

                    if obj.debug
                        fprintf('[UpdateGraph]: Visible duration (%.1f) exceeded data duration (%.1f)\n', obj.visibleDuration, obj.DurationEEG);
                    end
                end

                % ensure that the current view doesn't exceed the data on the 
                % x-axis
                rightEdgeX = obj.leftEdgeX + obj.visibleDuration;
                if rightEdgeX > obj.DurationEEG
                    rightEdgeX = obj.DurationEEG;
                    obj.leftEdgeX = rightEdgeX - obj.visibleDuration;

                    if obj.debug
                        fprintf('[UpdateGraph]: Right edge (%.1f) exceeded data duration (%.1f)\n', rightEdgeX, obj.DurationEEG);
                    end                

                end

                % ensure that the left hand doesn't exceed zero
                if obj.leftEdgeX < 0
                    obj.leftEdgeX = 0;

                    if obj.debug
                        fprintf('[UpdateGraph]: Left edge (%.1f) less than zero\n', obj.leftEdgeX);
                    end
                end 
                
            % manage bounds on the y-axis (amplitude)
            
                % range (zoom) of the y-axis must not exceed minimum
                amp_range = obj.amplitudeYLim(2) - obj.amplitudeYLim(1);
                if amp_range < obj.CONST_MIN_AMPLITUDE_Y_RANGE
                    obj.amplitudeYLim(2) =...
                        obj.amplitudeYLim(1) + obj.CONST_MIN_AMPLITUDE_Y_RANGE; 
                end

            % segment and download data for display

                % Convert left and right edge of visible data from seconds to samples
                left_edge_secs = obj.leftEdgeX;
                right_edge_secs = obj.leftEdgeX + obj.visibleDuration;
                s1 = obj.EEGTime2Sample(left_edge_secs);
                s2 = obj.EEGTime2Sample(right_edge_secs);
                
                % ensure that the width is at least 10 samples
                if (s2 - s1) < 10
                    s2 = s1 + 10;
                end
                
                % segment data and timestamps
                data = obj.Data.trial{1}(:, s1:s2);
                ls_delta = obj.lsDelta(s1:s2);
                ls_delta_z = obj.lsDelta_z(s1:s2);
                t = obj.Data.time{1}(s1:s2);

                ls = data(obj.idxLightSensorChannel, :);
%                 ls_pp = obj.preprocData.trial{1}(obj.idxLightSensorChannel, s1:s2);
                [obj.visibleDataDownsampled, obj.visibleTimeDownsampled] = obj.DownsampleData(ls, t);
%                 [obj.visiblePreprocDataDownsampled, ~] = obj.DownsampleData(ls_pp, t);
                [obj.visibleDeltaDownsampled, ~] = obj.DownsampleData(ls_delta, t);
                [obj.visibleDeltaZDownsampled, ~] = obj.DownsampleData(ls_delta_z, t);    
            
        end
        
        function Draw(obj)
            
            obj.uiEvents_beingUpdated = true;
            
            obj.DrawGraph;
            obj.DrawEvents;
            obj.DrawYAxis;
            obj.DrawLightSensorCalculations
            obj.DrawIgnoredSegments
            
            obj.uiEvents_beingUpdated = false;
            
        end
        
        function DrawGraph(obj)

            fprintf('[DrawGraph]: running\n');
            
            cla(obj.uiGraph_axes)

            if ~obj.Valid
                if obj.debug, fprintf('[DrawGraph]: exiting, object invalid\n'); end
                return;
            end

            % Plot the downsampled data
            plot(obj.visibleTimeDownsampled, obj.visibleDataDownsampled,...
                'Parent', obj.uiGraph_axes, ...
                'linewidth', 2.5, ...
                'color', obj.LightSensorColor, ...
                'ButtonDownFcn', @obj.uiGraph_MouseDown, ...
                'HitTest', 'on', ...
                'PickableParts', 'all');
            set(obj.uiGraph_axes, 'Color', obj.BackgroundColor);         

            % Set the x-axis limits
            left_edge_secs = obj.leftEdgeX;
            right_edge_secs = obj.leftEdgeX + obj.visibleDuration;
            xlim([left_edge_secs, right_edge_secs]);

            % y-axis
            % Calculate the center and range of the current y-axis limits
            meanY = mean(obj.amplitudeYLim);
            rangeY = diff(obj.amplitudeYLim) / 2;

            % Adjust the y-axis limits to ensure the data is centered
            ylim_scaled = [meanY - rangeY, meanY + rangeY];

            % Apply the new y-axis limits
            ylim(ylim_scaled);

        end

        function [ls_downsampled, t_downsampled] = DownsampleData(obj, ls, t)

            % Determine the number of pixels in the width of the plot area
            pixel_position = getpixelposition(obj.uiGraph_axes);
            num_pixels = pixel_position(3);

            % Calculate the downsampling factor, make it 4x higher to allow
            % for some antialiasing/smoothing when drawn
            num_data_points = length(ls);
            downsample_factor = round(0.01 * max(1, floor(num_data_points / num_pixels)));
            if downsample_factor <= 0
                downsample_factor = 1;
            end

            % Downsample the data
            if downsample_factor > 1
                ls_downsampled = downsample(ls, downsample_factor);
                t_downsampled = downsample(t, downsample_factor);
            else
                t_downsampled = t;
                ls_downsampled = ls;
            end
            
%             fprintf('size in: %d, size out: %d\n', length(ls), length(ls_downsampled));
            
        end
        
        function DrawEvents(obj)
            
            if obj.debug, fprintf('[DrawEvents]: running\n'); end            

            tab = obj.formattedEvents;
            if isempty(tab)
                return;
            end
            
            % add a flag to indicate the currently-selected event
            row_selected = false(size(tab, 1), 1);
            if ~isnan(obj.selectedEventIdx)
                row_selected(obj.selectedEventIdx) = true;
            end

            % Convert the left and right edge of the visible graph to sample
            % indices by searching the table. Use this to filter the table
            % for just the visible events
            left_edge_secs = obj.leftEdgeX;
            right_edge_secs = obj.leftEdgeX + obj.visibleDuration;
            idx_visible = tab.local_time >= left_edge_secs &...
                tab.local_time <= right_edge_secs;
            tab = tab(idx_visible, :);
            row_selected = row_selected(idx_visible);
            num_events = size(tab, 1);     
            
%             % find the event closest to the centre of the graph
%             time_centre = left_edge_secs + obj.visibleDuration / 2;
%             idx_closest = find(obj.formattedEvents.local_time <= time_centre, 1, 'last');
%             obj.ScrollEventsToIndex(idx_closest);

            % If we have >100 events, skip some to keep to this maximum
            if num_events > 50
                step = ceil(num_events / 100);
                idx_step = 1:step:num_events;
                tab = tab(idx_step, :);
                num_events = size(tab, 1);
                filtering_events = true;
            else
                filtering_events = false;
            end

            hold(obj.uiGraph_axes, 'on')

            for i = 1:num_events
                
                % get x coord (event timestamp)
                event_time = tab.local_time(i); 
                
                % extract the label from the HTML-formatted data in the
                % table
                tokens = regexp(tab.label{i}, '<font color="[^"]+">([^<]+)</font>', 'tokens');
                tokens = cellfun(@(x) x{1}, tokens, 'UniformOutput', false);
                str_lab = sprintf('%s_', tokens{:});
                str_lab(end) = [];
                                
                % wanted events are plotted with obj.EventColor, unwanted
                % are dimmed out (but still plotted)
                line_width = 1.5;
                
                if contains(tab.source{i}, 'light_sensor')
                    col_event = obj.LightSensorColor;
                else
                    col_event = obj.EventColor;
                end
                
                if row_selected(i)
                    
                    % selected events are brighter
                    col = mean([...
                        col_event;...
                        obj.ForegroundColor], 1);
                    line_width = 2.5;
                    
                elseif tab.wanted(i)
                    
                    col = col_event;
                    
                else
                    
                    % unwanted events are dimmer
                    col = mean([...
                        col_event;...
                        obj.BackgroundColor], 1);
                    
                end
                
                % plot a line
                xline(event_time, '-', str_lab,...
                    'Parent', obj.uiGraph_axes, ...
                    'color', col,...
                    'LineWidth', line_width,...
                    'interpreter', 'none',...
                    'hittest', 'off');
                
            end

            % if we are filtering events (not showing all of them due to the number)
            % then put warning text in orange at the top right of the visible area
            % of the graph
            if filtering_events
                y = obj.uiGraph_axes.YLim(1);
                text(obj.leftEdgeX + obj.visibleDuration, y,...
                    '⚠ Filtering some events',...
                    'Parent', obj.uiGraph_axes, ...
                    'color', [1, .5, 0], ...
                    'FontSize', 24,...
                    'HorizontalAlignment', 'right', ...
                    'VerticalAlignment', 'bottom');
            end
            
            hold(obj.uiGraph_axes, 'off')
            
        end
        
        function DrawYAxis(obj)
        % draw a single white y-axis that spans the y limits of the data 
        % giving the user a visual indicator of the spread of the
        % currently-visible data, and aiding selection a threshold 
        
            ls = obj.visibleDataDownsampled;
            
            % find extents of y data
            y_min = min(ls);
            y_max = max(ls);
            y_range = y_max - y_min;
            
            % adjust so that the axis is near to the top of the screen
            ylim_range = diff(obj.amplitudeYLim) * .1;
            y_min = obj.amplitudeYLim(2) - ylim_range;
            y_max = obj.amplitudeYLim(2) - ylim_range - y_range;
            
            % draw the y-axis 10% from the left edge
            x = obj.leftEdgeX + (obj.visibleDuration * .1);
            x_whisker = obj.visibleDuration * .025;
            
            % main vertical axis
            line([x, x], [y_min, y_max],...
                'parent', obj.uiGraph_axes,...
                'linewidth', 2.5,...
                'color', obj.ForegroundColor);
            
            % x-whiskers
            x1 = x - (x_whisker / 2);
            x2 = x + (x_whisker / 2);
            line([x1, x2], [y_min, y_min],...
                'parent', obj.uiGraph_axes,...
                'linewidth', 2.5,...
                'color', obj.ForegroundColor);
            line([x1, x2], [y_max, y_max],...
                'parent', obj.uiGraph_axes,...
                'linewidth', 2.5,...
                'color', obj.ForegroundColor);      
            
            % text
            y_center = (y_min + y_max) / 2;
            y_range_str = sprintf('%.1fµV', y_range); 
            tx = x - (obj.visibleDuration * .01);
            text('Parent', obj.uiGraph_axes, ...
                 'Position', [tx, y_center], ...
                 'String', y_range_str, ...
                 'Rotation', 90, ...
                 'VerticalAlignment', 'middle', ...
                 'HorizontalAlignment', 'center', ...
                 'FontSize', 12, ...
                 'Color', obj.ForegroundColor);            
            
        end
        
        function DrawLightSensorCalculations(obj)
            
            hold(obj.uiGraph_axes, 'on')            
            
            % get lights sensor data and timestamps
            ls = obj.visibleDataDownsampled;
            t = obj.visibleTimeDownsampled;
            
            if obj.DrawLightSensorSampleDelta
                
                % calcualte the sample delta between light sensor samples
                ls_raw_delta = obj.visibleDeltaDownsampled;
                ls_delta = min(ls) + ls_raw_delta;
                
                % make an array of colours based on magnitude of sample
                % delta
                col_delta = hot(length(ls_delta));
                [~, ord] = sort(ls_delta);
                col_delta = col_delta(ord, :);
                
                % plot the change as a time series
                plot(t, ls_delta, ...
                    'Parent', obj.uiGraph_axes, ...
                    'linewidth', 2.5, ...
                    'color', obj.CalculatedColor, ...
                    'HitTest', 'on', ...
                    'PickableParts', 'all');           
                
                % highlight individual data points and colour to determine
                % magnitude and direction
                scatter(t, ls_delta, 10, col_delta, 'filled', ...
                    'Parent', obj.uiGraph_axes, ...
                    'HitTest', 'on', ...
                    'PickableParts', 'all');                
                
            end
            
            hold(obj.uiGraph_axes, 'off')
            
        end

        function DrawIgnoredSegments(obj)
            
            if isempty(obj.ignoredSegments), return, end

            % find any ignored segments within the current view/time range. 
            % ignored segments are pairs of [t1, t2] in obj.ignoredSegments
            idx_in_view = obj.leftEdgeX <= obj.ignoredSegments(:, 1) & ...
                obj.ignoredSegments(:, 2) <= obj.leftEdgeX + obj.visibleDuration;
            segs_in_view = obj.ignoredSegments(idx_in_view, :);
            num_segs = size(segs_in_view, 1);

            % loop through all segs in view
            for i = 1:num_segs

                % ignored segs are semi-transparent filled rectangles of 
                % color obj.IgnoredColor
                t1 = segs_in_view(i, 1);
                t2 = segs_in_view(i, 2);
                x = [t1, t2, t2, t1];
                y_min = obj.uiGraph_axes.YLim(1);
                y_max = obj.uiGraph_axes.YLim(2);
                y = [y_min, y_min, y_max, y_max];
                patch('Parent', obj.uiGraph_axes, ...
                    'XData', x, ...
                    'YData', y, ...
                    'FaceColor', obj.IgnoreColor, ...
                    'FaceAlpha', .5, ...
                    'HitTest', 'off', ...
                    'PickableParts', 'none');

            end

        end

        % UI
        
        function CreateUI(obj)
            
            % UI contains:
            %
            %   1. EEG/light sensor/event view - scrollable, zoomable
            %   visualisation of light sensor activations as a time series,
            %   EEG event markers, session event markers and light sensor
            %   markers
            %
            %   2. Controls - scroll/zoom etc
            %
            %   3. Session/metadatainfo - num channels, num events etc
            %
            %   4. Matched EEG/session events - a table of EEG events, with
            %   corresponding matched session events, light sensor events
            %   etc. Clicking will scroll the visualisation to that event
            
            obj.uiBeingCreated = true;
            obj.uiBeingUpdated = true;
            
            % create figure=
            obj.uiFig = figure(...
                'MenuBar', 'none',...
                'ToolBar', 'none',...
                'Color', obj.BackgroundColor,...
                'Units', 'pixels',...
                'ResizeFcn', @obj.UpdateUI,...
                'WindowButtonDownFcn', @obj.uiGraph_MouseDown,...
                'Visible', 'off');
            
            % figure out UI sizes
            pos = obj.uiMakePositions;
            
            % window
            
                obj.uiFig.Position = pos.uiFig;
                
            % graph
            
                obj.uiGraph = uipanel(...
                    'Parent', obj.uiFig,...
                    'Units', 'pixels',...
                    'Position', pos.uiGraph,...
                    'BackgroundColor', obj.BackgroundColor);
                
                % Create the axes for the plot
                obj.uiGraph_axes = axes(...
                    'Parent', obj.uiGraph,...
                    'Units', 'normalized',...
                    'Color', obj.BackgroundColor,...
                    'ButtonDownFcn', @obj.uiGraph_MouseDown,...
                    'HitTest', 'on',...
                    'PickableParts', 'all',...
                    'Position', [0, 0, 1, 1]);        
                set(obj.uiGraph_axes, 'Color', obj.BackgroundColor);   
                
            % controls
                
                obj.uiControls = uipanel(...
                    'Parent', obj.uiFig,...
                    'Units', 'pixels',...
                    'Position', pos.uiControls,...
                    'BackgroundColor', obj.BackgroundColor);      
                obj.CreateUI_Controls
                
            % info
            
                obj.uiSessionInfo = uipanel(...
                    'Parent', obj.uiFig,...
                    'Units', 'pixels',...
                    'Position', pos.uiSessionInfo,...
                    'BackgroundColor', obj.BackgroundColor);       
                obj.CreateUI_SessionInfo
                
            % events
            
                obj.uiEvents = uipanel(...
                    'Parent', obj.uiFig,...
                    'Units', 'pixels',...
                    'Position', pos.uiEvents,...
                    'BackgroundColor', obj.BackgroundColor);               
                obj.CreateUI_Events
                
            % make window visible
            obj.uiFig.Visible = 'on';
            
            obj.uiBeingUpdated = false;         
            obj.uiBeingCreated = false;     
            
            % update graph
            obj.UpdateGraph
            obj.Draw
            
        end
        
        function CreateUI_SessionInfo(obj)
            
            str = sprintf('Light sensor channel: %s\n',...
                obj.LightSensorChannelLabel);
            str = sprintf('%sDuration (EEG | session): %.0fs | %.0fs\n',...
                str, obj.DurationEEG, obj.DurationSession);
            
            obj.uiSessionInfo_label = uicontrol(...
                'Parent', obj.uiSessionInfo,...
                'Units', 'normalized',...
                'Position', [0, 0, 1, 1],...
                'ForegroundColor', obj.ForegroundColor,...
                'BackgroundColor', obj.BackgroundColor,...
                'Style', 'text',...
                'FontSize', 16,...
                'String', str);
            
        end
        
        function CreateUI_Events(obj)
            
            % format EEG events into a table
            
                tab_eeg = struct2table(obj.Data.events);
                
                % rename column headers to match session table
                tab_eeg.Properties.VariableNames{'value'} = 'eeg_code';
                tab_eeg.Properties.VariableNames{'type'} = 'source';

                
                % if we have an abstime (absolute time, not standard
                % fieldtrip but present in enobio data) then use that.
                % Otherwise, use the standard fieldtrip timestamps (with an
                % arbitrary zero point)
                if isfield(obj.Data, 'abstime')
                    t_eeg = obj.Data.abstime;
                else
                    t_eeg = obj.Data.time{1};
                end
                
                % look up timestamps for each event onset, remove "sample"
                % column
                tab_eeg.timestamp = t_eeg(tab_eeg.sample);
                
                % append "wanted" column
                if isempty(obj.WantedEEGEvents)
                    tab_eeg.wanted = true(size(tab_eeg, 1), 1);
                else
                    tab_eeg.wanted = ismember(tab_eeg.eeg_code, obj.WantedEEGEvents);
                end           
                
                % if registered events are available, look up labels for
                % the EEG events. Otherwise use a string of the eeg code
                
                    if isprop(obj.Session, 'RegisteredEvents') &&...
                            ~isempty(obj.Session.RegisteredEvents)

                        % look up codes
                        tab_eeg.label = teCodes2RegisteredEvents(...
                            obj.Session.RegisteredEvents, tab_eeg.eeg_code);    

                    else
                        
                        tab_eeg.label = cellstr(num2str(tab_eeg.eeg_code));
                        
                    end
                
           % cat both tables
                    
                tab = [tab_eeg; obj.lightSensorEventTable];
                tab = sortrows(tab, 'sample');
                
            % colour code cells
            
                % Color code cells by source
                [src_u, ~, src_s] = unique(tab.source);
                num_sources = length(src_u);
                cols_src = cool(num_sources) .* 0.4; % Dim the colors
                fg_col = obj.ForegroundColor;
                fg_col_str = sprintf('#%02X%02X%02X', round(fg_col * 255)); % Convert to hex

                for s = 1:num_sources
                    idx = s == src_s;
                    bg_col_str = sprintf('#%02X%02X%02X', round(cols_src(s, :) * 255));
                    str = sprintf('<html><table><tr><td bgcolor=%s><font color="%s">%s</font></td></tr></table></html>', bg_col_str, fg_col_str, src_u{s});
                    tab.source(idx) = repmat({str}, sum(idx), 1);        
                end
                
            % create session time variable (time elapsed from 0 at session
            % start)
            tab.local_time = obj.Data.time{1}(tab.sample);
                
            tab = movevars(...
                tab,...
                {'local_time', 'label', 'eeg_code', 'source', 'wanted'},...
                'before', 1);
            
            % Color code each section of the label
            
                % Define a function to blend colors with white
                blend_with_white = @(color, blend_factor) min(1, color + blend_factor * (1 - color));
                blend_factor = 0.65; % Closer to 1 means lighter colors

                % Original colors to blend
                original_colors = {
                    [1, 0, 0], % Red
                    [0, 1, 0], % Green
                    [0, 0, 1], % Blue
                    [1, 1, 0], % Yellow
                    [1, 0, 1], % Magenta
                    [0, 1, 1], % Cyan
                    [1, 1, 1]  % White
                };

                % Blend colors with white
                blended_colors = cellfun(@(c) blend_with_white(c, blend_factor), original_colors, 'UniformOutput', false);

                % Convert blended colors to hex
                blended_colors_hex = cellfun(@(c) sprintf('#%02X%02X%02X', round(c * 255)), blended_colors, 'UniformOutput', false);

                % Color code each section of the label
                for i = 1:height(tab)
                    label_parts = split(tab.label{i}, '_');
                    colored_label = '';
                    for j = 1:length(label_parts)
                        color = blended_colors_hex{mod(j-1, length(blended_colors_hex)) + 1}; % Cycle through colors
                        colored_label = strcat(colored_label, sprintf('<font color="%s">%s</font>', color, label_parts{j}));
                        if j < length(label_parts)
                            colored_label = strcat(colored_label, '_');
                        end
                    end
                    tab.label{i} = strcat('<html><body>', colored_label, '</body></html>');
                end       
            
            obj.uiEvents_table = uitable(...
                'Parent', obj.uiEvents,...
                'Units', 'normalized',...
                'Position', [0, 0, 1, 1],...
                'ForegroundColor', obj.ForegroundColor,...
                'BackgroundColor', obj.BackgroundColor,...
                'Data', table2cell(tab),...
                'FontSize', 14,...
                'ColumnFormat', {'bank', [], [], [], [], 'long g'},...
                'ColumnWidth',  'auto',...
                'ColumnName', tab.Properties.VariableNames,...
                'CellSelectionCallback', @obj.uiEvents_Click);

            % Adjust the header colors if needed
            jScrollPane = findjobj(obj.uiEvents_table);
            jTable = jScrollPane.getViewport.getView;
            jTable.setSelectionBackground(java.awt.Color(0.2, 0.2, 0.2));
            jTable.setSelectionForeground(java.awt.Color(1, 1, 1));
            jTable.setGridColor(java.awt.Color(0.3, 0.3, 0.3));
            jTable.setForeground(java.awt.Color(1, 1, 1));
            jTable.setBackground(java.awt.Color(0.1, 0.1, 0.1));            
            
            uitableAutoColumnHeaders(obj.uiEvents_table);
            
            obj.formattedEvents = tab;
            
        end
        
        function CreateUI_Controls(obj)
            
            % buttons we want are: 
            % 
            % 1. horizontal scroll left
            % 2. horizontal scroll right
            % 3. vertical zoom increase
            % 4. vertical zoom decrease
            % 5. vertical zoom reset
            % 6. horizontal zoom increase
            % 7. horizontal zoom decrease
            % 8. horizontal zoom reset

            % figure out spacing/positions

            buttons = {...
                'ui_btnScrollLeft',         '←'             ;...  % Left arrow
                'ui_btnScrollRight',        '→'             ;...  % Right arrow
                'ui_btnHorizZoomIn',        '⇔+'            ;...  % Horizontal double arrow with plus
                'ui_btnHorizZoomOut',       '⇔-'            ;...  % Horizontal double arrow with minus
                'ui_btnHorizZoomReset',     '↺'             ;...  % Counterclockwise arrow (reset)
                'ui_btnVertZoomIn',         '⇑+'            ;...  % Upwards double arrow with plus
                'ui_btnVertZoomOut',        '⇓-'            ;...  % Downwards double arrow with minus
                'ui_btnVertZoomReset',      '↺'             ;...  % Counterclockwise arrow (reset)
                'ui_btnMouseZoom',          'Zoom'          ;...
                'ui_btnMouseSelect',        'Select'        ;...
                'ui_btnIgnoreSelection',    'Ignore'        ;...
                'ui_btnLightSensor2Events'  'LS2Events'     ;...
            };

            num_buttons = size(buttons, 1);
            w_button = 90;
            h_panel = getpixelposition(obj.uiControls);
            h_button = h_panel(4);
            h_gap = h_button * .05;
            for b = 1:num_buttons
                obj.(buttons{b}) = uicontrol(...
                    'style', 'pushbutton', ...
                    'Parent', obj.uiControls, ...
                    'Units', 'pixels', ...
                    'position', [w_button * (b-1), h_gap, w_button, h_button - (2 * h_gap)], ...
                    'String', buttons{b, 2}, ...
                    'FontSize', 24, ...
                    'Callback', @obj.ui_btnClick,...
                    'Tag', buttons{b, 1},...
                    'BackgroundColor', obj.BackgroundColor,...
                    'ForegroundColor', obj.ForegroundColor,...
                    'Visible', 'on');
            end

        end
                
        function UpdateUI(obj, ~, event)
            
            if obj.uiBeingUpdated, return, end

            obj.uiBeingUpdated = true;            
            
            % get updated positions
            pos = obj.uiMakePositions;
            
            obj.uiControls.Position = pos.uiControls;
            obj.uiEvents.Position = pos.uiEvents;
            obj.uiSessionInfo.Position = pos.uiSessionInfo;
            obj.uiGraph.Position = pos.uiGraph;
            
            obj.uiBeingUpdated = false;            
            
        end

        function ScrollEventsToIndex(obj, idx)
            
            if obj.debug
                fprintf('[ScrollEventsToIndex]: running\n');
                dbs = dbstack;
                for i = 1:length(dbstack)
                    disp(dbstack(i))
                end
            end            

            % Disable the CellSelectionCallback
            originalCallback = get(obj.uiEvents_table, 'CellSelectionCallback');
            set(obj.uiEvents_table, 'CellSelectionCallback', []);

            % Perform the update
            obj.uiEvents_beingUpdated = true;

            % get the java object of the table
            jScrollPane = findjobj(obj.uiEvents_table);
            jTable = jScrollPane.getViewport.getView;   

            jTable.changeSelection(idx - 1, 1, false, false);
            jTable.scrollRectToVisible(jTable.getCellRect(idx - 1, 0, true));

            % Re-enable the CellSelectionCallback
            set(obj.uiEvents_table, 'CellSelectionCallback', originalCallback);

            obj.uiEvents_beingUpdated = false;
            
        end


        % ui callbacks

        function ui_btnClick(obj, src, ~)

            % Define the step sizes for scrolling and zooming
            scrollStep = 0.1;  % Adjust as needed
            zoomFactor = 1.2;  % Adjust as needed
            vertZoomFactor = 1.2;  % Adjust as needed

            % Identify the source of the callback using the Tag property
            needs_redraw = true;
            switch src.Tag
                
                case 'ui_btnScrollLeft'  % Scroll Left
                    obj.leftEdgeX = obj.leftEdgeX - scrollStep * obj.visibleDuration;
                    
                case 'ui_btnScrollRight'  % Scroll Right
                    obj.leftEdgeX = obj.leftEdgeX + scrollStep * obj.visibleDuration;
                    
                case 'ui_btnHorizZoomIn'  % Horizontal Zoom In
                    centerX = obj.leftEdgeX + obj.visibleDuration / 2;
                    obj.visibleDuration = obj.visibleDuration / zoomFactor;
                    obj.leftEdgeX = centerX - obj.visibleDuration / 2;
                    
                case 'ui_btnHorizZoomOut'  % Horizontal Zoom Out
                    centerX = obj.leftEdgeX + obj.visibleDuration / 2;
                    obj.visibleDuration = obj.visibleDuration * zoomFactor;
                    obj.leftEdgeX = centerX - obj.visibleDuration / 2;
                    
                case 'ui_btnHorizZoomReset'  % Horizontal Zoom Reset
                    % Reset to initial zoom state (adjust as needed)
                    obj.visibleDuration = obj.CONST_DEF_VISIBLE_DURATION; 
                    obj.leftEdgeX = obj.CONST_DEF_LEFT_EDGE_X; 
                    
                case 'ui_btnVertZoomIn'  % Vertical Zoom In
                    centerY = mean(obj.amplitudeYLim);
                    rangeY = diff(obj.amplitudeYLim) / 2;
                    newRangeY = rangeY / vertZoomFactor;
                    obj.amplitudeYLim = [centerY - newRangeY, centerY + newRangeY];
                    
                case 'ui_btnVertZoomOut'  % Vertical Zoom Out
                    centerY = mean(obj.amplitudeYLim);
                    rangeY = diff(obj.amplitudeYLim) / 2;
                    newRangeY = rangeY * vertZoomFactor;
                    obj.amplitudeYLim = [centerY - newRangeY, centerY + newRangeY];
                    
                case 'ui_btnVertZoomReset'  % Vertical Zoom Reset
                    % Reset to initial amplitude scale (adjust as needed)
                    yl_min = min(obj.Data.trial{1}(:));
                    yl_max = max(obj.Data.trial{1}(:));
                    obj.amplitudeYLim = [yl_min, yl_max];

                case 'ui_btnMouseZoom'  
                    % set the current tool to zoom
                    obj.ChangeTool('zoom');
                    needs_redraw = false;

                case 'ui_btnMouseSelect'
                    % set the current tool to select
                    obj.ChangeTool('select');
                    needs_redraw = false;

                case 'ui_btnIgnoreSelection'
                    obj.MarkIgnored

                case 'ui_btnLightSensor2Events'
                    obj.LightSensor2Events


            end

            % Redraw the graph after updating the properties
            if needs_redraw
                obj.UpdateGraph;
                obj.Draw;
            end

        end

        function ChangeTool(obj, newTool)

            obj.uiCurrentTool = newTool;

            % set all buttons to 'off' by using their default background color
            obj.uiControls_SetButtonControlColors

            switch obj.uiCurrentTool

                case 'select'
                    obj.ui_btnMouseSelect.BackgroundColor = obj.ForegroundColor;
                    obj.ui_btnMouseSelect.ForegroundColor = obj.BackgroundColor;

                case 'zoom'
                    obj.ui_btnMouseZoom.BackgroundColor = obj.ForegroundColor;  
                    obj.ui_btnMouseZoom.ForegroundColor = obj.BackgroundColor;

            end

        end
            
        function uiControls_SetButtonControlColors(obj)

            % find all uibutton controls
            uibuttons = findobj(obj.uiControls.Children,...
                'type', 'UIControl', 'style', 'pushbutton');
            num_buttons = length(uibuttons);

            for i = 1:num_buttons   

                % all buttons get their background and text color set according
                % to the class FG and BG color properties
                uibuttons(i).BackgroundColor = obj.BackgroundColor;
                uibuttons(i).ForegroundColor = obj.ForegroundColor;

            end
            
        end

        function uiEvents_Click(obj, src, event)
            
            if obj.debug
                fprintf('[uiEvents_Click]: running, uiEvents_beingUpdated = %d\n',...
                    obj.uiEvents_beingUpdated);
            end
            
            if obj.uiEvents_beingUpdated, return, end
            
            if isequal(obj.uiEvents_selection, event.Indices(1))
                return
            end
            
            obj.uiEvents_selection = event.Indices(1);
            
            % extract selected event time from the events table
            t_sel = src.Data{event.Indices(1), 1};
            
            % set the view of the graph so that the event is centred
            obj.leftEdgeX = t_sel - (obj.visibleDuration / 2);
            
            % store the selected event
            obj.selectedEventIdx = event.Indices(1);
            
            obj.UpdateGraph;
            obj.Draw;
            
        end

        function uiGraph_MouseDown(obj, src, event)
            
            obj.ui_mouseIsDown = true;

            % react based upon current tool
            switch obj.uiCurrentTool

                case 'select'
                    % Record the start point, create a graphics object for the selected
                    % region and set mouse callbacks. The selection x and width are set
                    % by the mouse position, but the y and height are set to take up the 
                    % entire vertical extent 
                    obj.ui_selectedStartPoint = obj.uiGraph_axes.CurrentPoint(1, 1:2);
                    x = obj.ui_selectedStartPoint(1);
                    y = obj.uiGraph_axes.YLim(1);
                    w = 0;
                    h = obj.uiGraph_axes.YLim(2) - obj.uiGraph_axes.YLim(1);
                    delete(obj.ui_selectedRectHandle)
                    obj.ui_selectedRectHandle = rectangle('Position', [x, y, w, h], 'EdgeColor', 'r', 'LineStyle', '--');
                    set(obj.uiFig, 'WindowButtonMotionFcn', @obj.uiGraph_MouseMove);
                    set(obj.uiFig, 'WindowButtonUpFcn', @obj.uiGraph_MouseUp);

                case 'zoom'
                    % Record the start point, create a graphics object for the zoom region 
                    % set mouse callbacks
                    obj.ui_zoomStartPoint = obj.uiGraph_axes.CurrentPoint(1, 1:2);  
                    obj.ui_zoomRectHandle = rectangle('Position', [obj.ui_zoomStartPoint, 0, 0], 'EdgeColor', 'r', 'LineStyle', '--');
                    set(obj.uiFig, 'WindowButtonMotionFcn', @obj.uiGraph_MouseMove);
                    set(obj.uiFig, 'WindowButtonUpFcn', @obj.uiGraph_MouseUp);         

            end
            

            
        end

        function uiGraph_MouseMove(obj, src, event)

            if ~obj.ui_mouseIsDown, return, end

            % we want these values for either zoom or selection tools
            currentPoint = obj.uiGraph_axes.CurrentPoint(1, 1:2);

            % react based upon current tool
            switch obj.uiCurrentTool

                case 'select'
                    % set x and width but y and height are fixed
                    width = currentPoint(1) - obj.ui_selectedStartPoint(1);
                    if width < 0
                        obj.ui_selectedRectHandle.Position(1) = currentPoint(1);
                        obj.ui_selectedRectHandle.Position(3) = -width;
                    else
                        obj.ui_selectedRectHandle.Position(1) = obj.ui_selectedStartPoint(1);
                        obj.ui_selectedRectHandle.Position(3) = width;
                    end

                case 'zoom'
                    % set entire rect using mouse position
                    width = currentPoint(1) - obj.ui_zoomStartPoint(1);
                    height = currentPoint(2) - obj.ui_zoomStartPoint(2);
                    if width < 0
                        minX = currentPoint(1);
                        width = -width;
                    else
                        minX = obj.ui_zoomStartPoint(1);
                    end
                    if height < 0
                        minY = currentPoint(2);
                        height = -height;
                    else
                        minY = obj.ui_zoomStartPoint(1);
                    end
                    set(obj.ui_zoomRectHandle, 'Position', [minX, minY, width, height]);                    
            end
        end

        
        function uiGraph_MouseUp(obj, src, event)

            % react based upon current tool
            has_updated = false;
            switch obj.uiCurrentTool

                case 'select'

                    % get the position of the selection object
                    position = get(obj.ui_selectedRectHandle, 'Position');

                    % record the start and end time of the selected region in seconds
                    obj.ui_graphSelection = [position(1), position(1) + position(3)];
                    
                    has_updated = false;

                case 'zoom'

                    position = get(obj.ui_zoomRectHandle, 'Position');
                    delete(obj.ui_zoomRectHandle);  % Remove the rectangle from the axes

                    % Calculate new properties based on the selected area
                    newLeftEdgeX = position(1);
                    newRightEdgeX = position(1) + position(3);
                    newBottomEdgeY = position(2);
                    newTopEdgeY = position(2) + position(4);

                    % Update properties
                    obj.leftEdgeX = newLeftEdgeX;
                    obj.visibleDuration = newRightEdgeX - newLeftEdgeX;
                    obj.amplitudeYLim = [newBottomEdgeY, newTopEdgeY];
                    
                    has_updated = true;
                    
            end

            if has_updated
                % Redraw the graph after updating the properties
                obj.UpdateGraph;
                obj.Draw;

                % Reset callbacks
                set(gcf, 'WindowButtonMotionFcn', '');
                set(gcf, 'WindowButtonUpFcn', '');
            end
            
            obj.ui_mouseIsDown = false;
            
        end       
        
        % utils
        
        function s = EEGTime2Sample(obj, t)
            
            if ~obj.Valid
                s = [];
                if obj.debug, fprintf('[EEGTime2Sample]: Cannot convert time %.1f to sample due to invalid object\n', t); end
                return
            end
            
            t_eeg = obj.Data.time{1};
            s = find(t_eeg > t, 1, 'first');
            
            if obj.debug
                fprintf('[EEGTime2Sample]: Converted time %.1fs to sample %d\n', t, s);
            end
            
        end
        
        % get/set 
        
        function val = get.Valid(obj)
            
            % to be valid, the object must:
            %   1. Have valid FT data
            %   2. Have identified a valid light sensor channel
            
                val_ft_data = ~isempty(obj.Data);
                val_ls_channel = ~isempty(obj.idxLightSensorChannel);
                
                val = val_ft_data && val_ls_channel;
            
            % set up the strings containing the reason for an invalid
            % object in reverse order, with most fundamental reason at the
            % end (i.e. it's more important that FT data is entirely
            % missing than that the light sensor channel hasn't been ID'd)
            
                if ~val_ls_channel
                    obj.ValidReason = 'light sensor channel not identified';
                end
                if ~val_ft_data
                    obj.ValidReason = 'missing fieldtrip data';
                end
                
        end 
        
        function AssertValid(obj)
            if ~obj.Valid
                error('Object not valid due to:\n\n\t%s', obj.ValidReason)
            end
        end
        
        function set.Data(obj, val)
            obj.Data = val;
            obj.UpdateGraph
        end 
        
        function set.Session(obj, val)
            
            if ~isa(val, 'teSession')
                error('Session data must be a teSession object')
            end
            
            obj.Session = val;

        end
        
        function set.idxLightSensorChannel(obj, val)
            
            % can only set this channel if data has been supplied
            val_ft_data = ~isempty(obj.Data);                        
            if ~val_ft_data
                error('Cannot set the lights sensor channel because fieldtrip data hasn''t been supplied.')
            end
            
            % light sensor idx must be in bounds
            num_channels = length(obj.Data.label);
            if val > num_channels
                error('Light sensor channel index (%d) exceeds the number of channels in the fieldtrip data (%d)',...
                    val, num_channels)
            end
            
            obj.idxLightSensorChannel = val;
            
        end
        
        function set.leftEdgeX(obj, val)
            obj.leftEdgeX = val;
%             obj.UpdateGraph;
%             obj.Draw;
        end
        
        function set.visibleDuration(obj, val)
            % must be at least 1 sec
            if val < 1
                val = 1;
            end
            obj.visibleDuration = val;
%             obj.UpdateGraph;
%             obj.Draw;
        end
        
        function val = get.LightSensorChannelLabel(obj)
          
            obj.AssertValid;
            
            val = obj.Data.label{obj.idxLightSensorChannel};
            
        end
        
        function val = get.DurationEEG(obj)
            
            if ~obj.Valid
                val = [];
                return
            end
            
            val  = length(obj.Data.time{1}) / obj.Data.fsample;
            
        end
        
        function val = get.DurationSession(obj)
            
            if ~obj.Valid
                val = [];
                return
            end
            
            val = obj.Session.Log.LogArray{end}.timestamp - obj.Session.Log.LogArray{1}.timestamp;      
            
        end
        
%         function set.ui_mouseIsDown(obj, val)
%             obj.ui_mouseIsDown = val;
%             disp(val)
%         end
        
%         function set.ui_selectedRectHandle(obj, val)
%             obj.ui_selectedRectHandle = val;
%             % debug: when this property is set, print the stack to the command window
%             disp(dbstack)
% 
%         end
       
    end
    
    methods (Hidden)
        
        function pos = uiMakePositions(obj)
            
            % define constants for immovable height panels
            h_ctrl = 65;
            h_info = 200;
            
            % determine min height, below which an error would occur
            min_height = max([h_ctrl, h_info]) + 100;
        
            % size of window -- we want it to be x% from the edge all
            % around. Only define this if the figure doesn't exist,
            % otherwise (which means it hasn't been instantiated yet),
            % otherwise use its current position (as this method has been
            % triggered by a window resize rather than instantiation)
            
                figure_valid = ~isempty(obj.uiFig) &&...
                    isa(obj.uiFig, 'matlab.ui.Figure');
                if ~figure_valid
                    error('Figure does not exist or is not valid, cannot set positions')
                end
               
                if obj.uiBeingCreated
                    
                    % define gap from edge
                    gap_from_edge_prop = 0.10;

                    % get monitor size
                    pos_screen = get(0, 'MonitorPositions');
                    pos_main_screen = pos_screen(1, :);
                    w = pos_main_screen(3) - pos_main_screen(1) + 1;
                    h = pos_main_screen(4) - pos_main_screen(2) + 1;

                    % gap from edge is 25% all round
                    gap_from_edge_x = round(w * gap_from_edge_prop);
                    gap_from_edge_y = round(h * gap_from_edge_prop);
                    w_win = w - (gap_from_edge_x * 2);
                    h_win = h - (gap_from_edge_y * 2);

                    % window rect
                    pos.uiFig = [...
                        gap_from_edge_x,...
                        gap_from_edge_y,...
                        w_win,...
                        h_win,...
                        ];
                    
                else
                                        
                    % check that the min height hasn't been exceeded
                    if obj.uiFig.Position(4) < min_height
                        obj.uiFig.Position(4) = min_height;
                    end
                    
                    % read the window size from the window itself
                    pos.uiFig = obj.uiFig.Position; 
                    w_win = pos.uiFig(3);
                    h_win = pos.uiFig(4);
                    
                end
                
            % define width of visualiser panel and its controls
            
                w_vis_prop = 0.70;
                w_vis = w_win * w_vis_prop;
                
            % controls -- height is hard coded and locked to bottom of
            % window, width matches that of the visualiser panel
            
                w_ctrl = w_vis;
                
                pos.uiControls = [...
                    0,...
                    0,...
                    w_ctrl,...
                    h_ctrl,...
                    ];
                
            % session info/metadata -- height is hardcoded and width is set
            % via width of visualiser
            
                w_info = w_win - w_vis;
                
                pos.uiSessionInfo = [...
                    w_vis,...
                    h_win - h_info,...
                    w_info,...
                    h_info,...
                    ];
                
            % events list -- width is set by the width of the visualiser,
            % height is below the info panel
            
                w_events = w_win - w_vis;
                h_events = h_win - h_info;
                
                pos.uiEvents = [...
                    w_vis,...
                    0,...
                    w_events,...
                    h_events,...
                    ];
                
            % visualiser -- width is already defined and matches that of
            % controls, height is height minus controls
            
                h_vis = h_win - h_ctrl;
                
                pos.uiGraph = [...
                    0,...
                    h_ctrl,...
                    w_vis,...
                    h_vis,...
                    ];
                
        end
        
        
    end
    
end
