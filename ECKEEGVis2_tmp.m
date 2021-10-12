% ECKEEGVis - ECK EEG Visualiser
% Version: Beta 0.2
%
% This tool will visualise segmented fieldtrip EEG data, and allow you to
% mark artefacts. 
%
% Prerequisites:
%
% It requires fieldtrip to be installed and on the matlab path. It also
% requires psychtoolbox to be installed. You can get these from:
%
% fieldtrip (developed on rev 20180314): www.fieldtriptoolbox.org/download
% psychtoolbox (developed on v3.0.12): psychtoolbox.org/download/
%
%
% Getting started:
%
% The tool is coded as a Matlab class object. To use it, you must first
% create an instance of the class. You can call it anything you like: 
%
% eegvis = ECKEEGVis;
%
% To load some data, set the Data property to a fieldtrip structure,
% containing segmented data:
%
% eegvis.Data = data;
%
% To begin interacting with the data, call the StartInteractive method:
%
% eegvis.StartInteractive
%
% You can then click on each channel to mark/unmark as an artefact.
% 
% 
% Keyboard controls:
%
% There are a number of keyboard controls, which will become active when
% you call the StartInteractive method:
%
%   Right arrow         -   Display next trial
%   Left arrow          -   Display previous trial
%   Up arrow            -   Decrease y scale (make data larger)
%   Down arrow          -   Increase y scale (make data smaller)
%   y                   -   Auto set y scale (press to toggle)
%   f                   -   Toggle fullscreen mode
%   +                   -   Zoom in
%   -                   -   Zoom out
%   c                   -   Recentre & reset zoom
%   a                   -   Mark all channels 
%   n                   -   Unmark all channels
%   CTRL                -   Hold, click and drag to pan 
%   ESCAPE              -   End interactive mode
%   <                   -   Step to previous entry in history
%   >                   -   Step to next entry in history
%
%
% Artefact structure
%
% The tool will create two extra fields on a fieldtrip data set; art and
% artType. 
%
% art -     contains a [numChans x NumTrials] logical matrix. Each
%           element represents one particulator channel x trial 
%           combination (e.g. Af7 on trial 21). A true means an artefact 
%           is present, false means clean. 
%
% arttype - contains a [numChans x numTrials] cell array matrix of strings.
%           Optionally (depending upon the function that works on the data)
%           contains a string recording the source of the artefact. This
%           tool writes 'manual' to this structure. 
%
% ! IT IS IMPORTANT TO SAVE THE DATA AFTER MARKING ARTEFACTS! You can do
% this by extracting the artefact-detected data from the tool...
%
% data_marked = eegvis.Data;
%
% ...and saving the variable. 


        
        % data
        function UpdateData(obj)
            
            if isempty(obj.prData)
                obj.prDataValid = false;
                return
            end
           
            % update number of trials, and current trial number
            obj.prNumTrials = length(obj.prData.trial);
            if obj.prTrial > obj.prNumTrials
                obj.prTrial = obj.prNumTrials;
            elseif isempty(obj.prTrial) || obj.prTrial < 1 
                obj.prTrial = 1;
            end
            
            % prepare layout for 2D plotting
            cfg = [];
            cfg.rotate = 270;
            cfg.skipscale = 'yes';
            cfg.skipcomnt = 'yes';
%             cfg.layout = '/Users/luke/Google Drive/Experiments/face erp/fieldtrip-20170314/template/electrode/GSN-HydroCel-129.sfp';
            obj.prLayout = ft_prepare_layout(cfg, obj.prData);
            obj.prLayout.pos(:, 1) = -obj.prLayout.pos(:, 1);
            
            % remove layout channels not in data
            present = cellfun(@(x) ismember(x, obj.prData.label),...
                obj.prLayout.label);
            obj.prLayout.pos = obj.prLayout.pos(present, :);
            obj.prLayout.width = obj.prLayout.width(present);
            obj.prLayout.height = obj.prLayout.height(present);
            obj.prLayout.label = obj.prLayout.label(present);
            
            % remove channels not on the layout
            cfg = [];
            cfg.channel = obj.prLayout.label;
            obj.prData = ft_selectdata(cfg, obj.prData);
            obj.prNumChannels = length(obj.prData.label);
            
            % make empty art structure if one doesn't exist
            createLayer = false;
            if ~isfield(obj.prData, 'art')
                % create empty vars
                obj.prData.art = [];
                obj.prData.art_type = {};
                createLayer = true;
            else
                % look for manual layer
                idx = find(strcmpi(obj.prData.art_type, 'manual'), 1);
                createLayer = createLayer || isempty(idx);
            end
            if createLayer
                if isempty(obj.prData.art)
                    idx = 1;
                else
                    idx = size(obj.prData.art, 3) + 1;
                end
                obj.prData.art(:, :, idx) =...
                    false(length(obj.prData.label),...
                    obj.prNumTrials);
                obj.prData.art_type{idx} = 'manual';
            end
%             obj.prArt = obj.prData.art;
%             obj.prArtType = obj.prData.art_type;
            obj.prArtLayer = idx;
            obj.prArtValid = true;
            
%             % make empty art structure if one doesn't exist
%             if ~isfield(obj.prData, 'art')
%                 obj.prArt = [];
%             else 
%                 obj.prArt = obj.prData.art;
%             end
            
            % check for interp struct
            if isfield(obj.prData, 'interp')
                obj.prInterp = obj.prData.interp;
            else
                obj.prInterp = [];
            end
            
            % check for can't-interp struct
            if isfield(obj.prData, 'cantInterp')
                obj.prCantInterp = obj.prData.cantInterp;
            else
                obj.prCantInterp = false(obj.prNumChannels,...
                    obj.prNumTrials);
            end
            
%             % check for interp neighbours struct
%             if ~isfield(obj.prData, 'interpNeigh') 
%                 obj.prInterpNeigh = obj.prData.interpNeigh;
%             end
            
            % auto set ylim
            yMin = min(cellfun(@(x) min(x(:)), obj.prData.trial));
            yMax = max(cellfun(@(x) max(x(:)), obj.prData.trial));
            obj.prYLim = [yMin, yMax];

            obj.prDataValid = true;
            obj.PrepareForDrawing
            
        end
        
        function UpdateDrawSize(obj)
            
            % check for mouse position - if it is over the window, then use
            % that as the focus (around which to scale the drawing plane) -
            % otherwise use the centre of the window
            [mx, my] = GetMouse(obj.prWinPtr);
            if...
                    mx >= obj.prWindowSize(1) &&...
                    mx <= obj.prWindowSize(3) &&...
                    my >= obj.prWindowSize(2) &&...
                    my <= obj.prWindowSize(4)
                obj.prDrawFocus = [mx, my];
            else
                obj.prDrawFocus = obj.prWindowSize(3:4) / 2;
            end

            % centre window  
            wcx = obj.prDrawFocus(1);
            wcy = obj.prDrawFocus(2);
            rect = obj.prDrawSize - [wcx, wcy, wcx, wcy];
            
            % apply zoom
            rect = rect * obj.prZoom;
            obj.prDrawOffset = obj.prDrawOffset * obj.prZoom;
            
            % de-centre window
            obj.prDrawSize = rect + [wcx, wcy, wcx, wcy];
           
            % reset zoom
            obj.prZoom = 1;
            
        end
        
        function Overlay(obj, olData)
            
            % if a single piece of data has been passed as a struct, put it
            % in a cell array
            if isstruct(olData)
                olData = {olData};
            end
            numOl = length(olData);
            
            % check main data type - can only overlay timelock (erp) data
            if ~strcmpi(obj.prDataType, 'timelock')
                error('Only timelock data can be overlaid')
            end
            
            % check that datatypes, time and electrodes match
            typeOl = cell(numOl, 1);
            timeOl = cell(numOl, 1);
            elecOl = cell(numOl, 1);
            for ol = 1:numOl
                typeOl{ol} = ft_datatype(olData{ol});
                timeOl{ol} = olData{ol}.time;
                elecOl{ol} = olData{ol}.label;
                olData{ol}.trial = {olData{ol}.avg};
            end
            
            typeOl{end + 1} = obj.prDataType;
            if ~isequal(typeOl{:})
                error('Overlaid data must all be of the same type, and must match main data type.')
            end
            
            timeOl{end + 1} = obj.prData.time{1};
            if ~isequal(timeOl{:})
                error('Time vectors in main data and overlaid data must match.')
            end
            
            elecOl{end + 1} = obj.prData.label;
            if ~isequal(elecOl{:})
                error('Channels numbers/names in main data and overlaid data must match.')
            end
            
            obj.prDataOverlay = olData;
            obj.prDataHasOverlay = true;
            obj.PrepareForDrawing;
            obj.Draw
            
        end
        
        % drawing
        function PrepareForDrawing(obj)
            
            if ~obj.prDataValid,
                obj.prDrawingPrepared = false;
                return
            end
            
            % width/height of drawing plane
            drW = obj.prDrawSize(3) - obj.prDrawSize(1);
            
            % check that the drawing plane is not out of bounds
            if obj.prDrawSize(1) > obj.prWindowSize(3)
                % left hand edge
                obj.prDrawSize(1) = obj.prWindowSize(3);
                obj.prDrawSize(3) = obj.prDrawSize(1) + drW;
            end
            
            % width/height of drawing plane
            drW = obj.prDrawSize(3) - obj.prDrawSize(1);
            drH = obj.prDrawSize(4) - obj.prDrawSize(2);            
            
            % take electrode positions in layout file, normalise, convert
            % to pixels, make vectors for x, y, w and h coords
            eegX = round((obj.prLayout.pos(:, 1) + .5) * drW) +...
                obj.prDrawSize(1);
            eegY = round((obj.prLayout.pos(:, 2) + .5) * drH) +...
                obj.prDrawSize(2);
            eegW = round(obj.prLayout.width(1) * drW);
            eegH = round(obj.prLayout.height(1) * drH);
            
            % find top-left of each channel, store x, y, w, h
            obj.prChanX = round(eegX - (eegW / 2));
            obj.prChanY = round(eegY - (eegH / 2));
            obj.prChanW = eegW;
            obj.prChanH = eegH;
            
            if obj.prDataHasOverlay
                numOl = 1 + length(obj.prDataOverlay);
                olDat = [{obj.prData}, obj.prDataOverlay];  
            else
                numOl = 1;
                olDat = {obj.prData};
            end
            obj.prCoordsEEG = cell(numOl, 1);

            for ol = 1:numOl
                
                dat = olDat{ol}.trial{obj.prTrial};
                
                % decimate data (to prevent drawing pixels more than once when
                % length of data is greater than pixel width of axes)
                t = obj.prData.time{obj.prTrial};
                numSamps = size(dat, 2);
                downSampIdx = round(1:numSamps / obj.prChanW:numSamps);
                if length(downSampIdx) < obj.prChanW
                    missing = obj.prChanW - length(downSampIdx);
                    downSampIdx =...
                        [downSampIdx, repmat(downSampIdx(end), 1, missing)];
                end
                dat = dat(:, downSampIdx);
                t = t(downSampIdx);

                % optionally auto-set y axis limits
                if obj.AutoSetTrialYLim
                    switch obj.AutoSetTrialYlimMode
                        case 'max'
                            obj.prYLim = [min(dat(:)), max(dat(:))];
                        case 'quartile'
                            obj.prYLim =...
                                [prctile(dat(:), 10), prctile(dat(:), 90)];
                    end
                end

                % find x coords for each sample of time series data, across all
                % channels
                x = repmat(1:obj.prChanW, obj.prNumChannels, 1) +...
                    repmat(obj.prChanX, 1, size(dat, 2));

                % rescale y (amplitude) values to pixels, find y values for
                % each sample of time series data
                ylr = obj.prYLim(1) - obj.prYLim(2);
                yls = obj.prChanH / ylr;
                y = round(dat * yls) - (yls * obj.prYLim(2)) +...
                    repmat(obj.prChanY, 1, size(dat, 2));

                % remove any channels that are offscreen
                offScreen = all(...
                    x < obj.prWindowSize(1) &...
                    x > obj.prWindowSize(3) & ...
                    y < obj.prWindowSize(2) &...
                    y > obj.prWindowSize(4), 2);
                x(offScreen, :) = [];
                y(offScreen, :) = [];

                % convert x, y, positions to coords for drawing to screen. Need
                % to do this separately for each channel
                coords_ts = zeros(size(x, 1) * 2, size(x, 2));
                row = 1;
                for ch = 1:2:size(coords_ts, 1)
                    coords_ts(ch:ch + 1, :) = [x(row, :); y(row, :)];
                    row = row + 1;
                end

                % double each sample so that lines connect between samples
                coordsIdx =...
                    [1, sort(repmat(2:size(coords_ts, 2) - 1, 1, 2)),...
                    size(coords_ts, 2)];
                coords_ts = coords_ts(:, coordsIdx);
                obj.prCoordsEEG{ol} = coords_ts;
                
            end
            
            % find zero crossing on x axis, store for drawing
            zeroCross = find(t > 0, 1, 'first');
            zeroX = obj.prChanX' + zeroCross;
            zeroY = obj.prChanY';
            zeroIdx = sort(repmat(1:length(zeroX), 1, 2));
            zeroX = zeroX(zeroIdx);
            zeroY = zeroY(zeroIdx);
            zeroIdx = 1:2:length(zeroY);
            zeroY(zeroIdx) = zeroY(zeroIdx) + obj.prChanH;
            obj.prCoordsZeroLine = [zeroX; zeroY];
            
            % prepare lines for x axes
            yCross = round(abs(obj.prYLim(1)) / sum(abs(obj.prYLim))...
                * obj.prChanH);
            xAxisX = obj.prChanX';
            xAxisY = obj.prChanY' + yCross;
            xAxisIdx = sort(repmat(1:length(xAxisX), 1, 2));
            xAxisX = xAxisX(xAxisIdx);
            xAxisY = xAxisY(xAxisIdx);
            xAxisIdx = 1:2:length(xAxisY);
            xAxisX(xAxisIdx) = xAxisX(xAxisIdx) + obj.prChanW;
            obj.prCoordsXAxis = [xAxisX; xAxisY];
            
            obj.prDrawingPrepared = true;
            
        end
        
        function Draw(obj)
            
            if obj.prDrawingPrepared
                
                % draw background colour (red if any artefacts)
%                 if any(obj.prArt(:, obj.Trial, obj.prArtLayer))
                if any(any(obj.prData.art(:, obj.Trial, :)))
                    Screen('FillRect', obj.prWinPtr, obj.Col_ArtefactBG);
                else
                    Screen('FillRect', obj.prWinPtr, obj.Col_BG);
                end
                
                Screen('TextSize', obj.prWinPtr, obj.ChannelLabelFontSize);
                
                % channel background panes
                if obj.DrawChannelBackground
                    
                    % arrange coords of backgrounds into a PTB-friendly
                    % format
                    coords = [...
                        obj.prChanX' + obj.prDrawOffset(1);...
                        obj.prChanY' + obj.prDrawOffset(2);...
                        obj.prChanX' + obj.prChanW' + obj.prDrawOffset(1);...
                        obj.prChanY' + obj.prChanH' + obj.prDrawOffset(2)];
                    
                    % select colours for bad channels
                    bad = any(obj.prData.art(:, obj.prTrial, :), 3);
                    chanBGCols =...
                        repmat(obj.Col_ChanBG', 1, obj.prNumChannels);
                    chanBGCols(:, bad) =...
                        repmat(obj.Col_ArtefactBG', 1, sum(bad));
                    
%                     % select colours for interpolated channels
%                     if ~isempty(obj.prInterp)
%                         interp = obj.prInterp(:, obj.prTrial) & ~bad;
%                         chanBGCols(:, interp) =...
%                             repmat(obj.Col_InterpBG', 1, sum(interp));
%                     end
                    
                    % draw
                    Screen('FillRect', obj.prWinPtr, chanBGCols,...
                        coords);
                    
                end
                        
                % draw channels
                eegRow = 1;
                for ch = 1:obj.prNumChannels
                    
                    % interp
                    if ~isempty(obj.prInterp) &&...
                            obj.prInterp(ch, obj.prTrial)
                        interpRect = [...
                            obj.prChanX(ch) + obj.prDrawOffset(1),...
                            obj.prChanY(ch) + obj.prDrawOffset(2),...
                            obj.prChanX(ch) + obj.prChanW + obj.prDrawOffset(1),...
                            obj.prChanY(ch) + obj.prChanH + obj.prDrawOffset(2)];
                        Screen('FrameRect', obj.prWinPtr,...
                            obj.Col_InterpBG, interpRect, 4); 
                    end
                    
                    % can't-interp 
                    if obj.prCantInterp(ch, obj.prTrial)
                        cantInterpRect = [...
                            obj.prChanX(ch) + obj.prDrawOffset(1),...
                            obj.prChanY(ch) + obj.prDrawOffset(2),...
                            obj.prChanX(ch) + obj.prChanW + obj.prDrawOffset(1),...
                            obj.prChanY(ch) + obj.prChanH + obj.prDrawOffset(2)];
                        Screen('FrameRect', obj.prWinPtr,...
                            obj.Col_CantInterpBG, cantInterpRect, 4);                        
                        
%                         ciX = obj.prChanX(ch) + obj.prChanW +...
%                             obj.prDrawOffset(1) - tb_ci(3);
%                         ciY = obj.prChanY(ch) + obj.prDrawOffset(2);
%                         Screen('DrawText', obj.prWinPtr, 'X', ciX, ciY,...
%                             obj.Col_ArtefactLine, obj.Col_ArtefactBG);
                    end
                    
                    % x axis
                    if obj.DrawXAxis
                        coords = obj.prCoordsXAxis(:, eegRow:eegRow + 1);
                        coords(1, :) = coords(1, :) + obj.prDrawOffset(1);
                        coords(2, :) = coords(2, :) + obj.prDrawOffset(2);
                        Screen('DrawLines', obj.prWinPtr,...
                            coords, 1, obj.Col_Axis, [0, 0], 2);
                    end
                    
                    % zero line
                    if obj.DrawZeroLine
                        coords = obj.prCoordsZeroLine(:, eegRow:eegRow + 1);
                        coords(1, :) = coords(1, :) + obj.prDrawOffset(1);
                        coords(2, :) = coords(2, :) + obj.prDrawOffset(2);                        
                        Screen('DrawLines', obj.prWinPtr,...
                            coords, 1, obj.Col_Axis, [0, 0], 2); 
                    end
                        
                    % time series
                    if obj.prDataHasOverlay
                        numOl = 1 + length(obj.prDataOverlay);
                    else
                        numOl = 1;
                    end
                    for ol = 1:numOl
                        if ch == obj.prChanHover, lineW = 2; else...
                                lineW = 1; end
%                         if obj.prArt(ch, obj.prTrial, obj.prArtLayer) &&...
                        if any(obj.prData.art(ch, obj.prTrial, :), 3) &&...
                                ~obj.prDataHasOverlay
                            lineCol = obj.Col_ArtefactLine;
%                             lineCol = obj.Col_Series(ol, :);
    %                     elseif obj.prInterp(ch, obj.prTrial)
    %                         lineCol = obj.Col_InterpLine;
                        else
                            lineCol = obj.Col_Series(ol, :);
                        end
                        coords = obj.prCoordsEEG{ol}(eegRow:eegRow + 1, :);
                            coords(1, :) = coords(1, :) + obj.prDrawOffset(1);
                            coords(2, :) = coords(2, :) + obj.prDrawOffset(2);                      
                        Screen('DrawLines', obj.prWinPtr, coords,...
                            lineW, lineCol, [0, 0], 2);
                    end
                    
                    % channel labels
                    if obj.DrawChannelLabels
                        tb = Screen('TextBounds', obj.prWinPtr,...
                            obj.prData.label{ch});
                        labX = obj.prChanX(ch) +...
                            obj.prDrawOffset(1);
                        labY = obj.prChanY(ch) + obj.prChanH -...
                            tb(4) + obj.prDrawOffset(2);
                        
                        Screen('DrawText', obj.prWinPtr,...
                            obj.prData.label{ch}, labX, labY,...
                            obj.Col_Label, obj.Col_LabelBG);
                    end
                        
                    eegRow = eegRow + 2;
                    
                end
                
                % channel hover highlight
                if ~isempty(obj.prChanHover)
                    hrX1 = obj.prChanX(obj.prChanHover) +...
                        obj.prDrawOffset(1);
                    hrY1 = obj.prChanY(obj.prChanHover) +...
                        obj.prDrawOffset(2);
                    hrX2 = obj.prChanX(obj.prChanHover) +...
                        obj.prChanW + obj.prDrawOffset(1);
                    hrY2 = obj.prChanY(obj.prChanHover) +...
                        obj.prChanH + obj.prDrawOffset(2);
                    hovRect = [hrX1, hrY1, hrX2, hrY2];
                    Screen('FrameRect', obj.prWinPtr, obj.Col_Hover,...
                        hovRect, 1);
                    
                    % channel hover cursor
                    if obj.prChanHoverCursorVisible
                        
                        % look up x location (hcX) and y index value based
                        % upon x mouse position
                        hcX = obj.prChanHoverCursorX;
                        idx = ceil((obj.prChanHoverCursorX -...
                            obj.prChanX(obj.prChanHover)) * 2);
                        
                        % look up y location (hcY), check bounds and draw
                        if idx > 0 && idx < size(obj.prCoordsEEG{ol}, 2)
                            hcY = obj.prCoordsEEG{ol}(obj.prChanHover * 2, idx)...
                                + obj.prDrawOffset(2);
                            if hrY1 > hcY, hrY1 = hcY; end
                            if hcY > hrY2, hrY2 = hcY; end
                            Screen('DrawDots', obj.prWinPtr,...
                                [hcX, hcY],...
                                5, obj.Col_Hover, [], 3);
                            
                        end
                        
                        % draw y cursor line
                        Screen('DrawLine', obj.prWinPtr,...
                            [obj.Col_Hover, 200], hcX, hrY1, hcX, hrY2, 1);
                        
                        % draw time and voltage values
                        htX = hcX;
                        htY = obj.prChanY(obj.prChanHover) - 12;
                        
                        htProp = (htX - hrX1) / (hrX2 - hrX1);
                        htDataIdx = ceil(htProp *...
                            size(obj.prData.trial{obj.prTrial}, 2));
                        htXVal = round(obj.prData.time{obj.prTrial}(...
                            htDataIdx) * 1000);
                        htYVal = obj.prData.trial{obj.prTrial}(...
                            obj.prChanHover, htDataIdx);

                        % draw time and amplitude at cursor
                        htStr = sprintf('%s | %.1fuV @ %dms',...
                            obj.prData.label{obj.prChanHover},...
                            htYVal, htXVal);
                        Screen('DrawText', obj.prWinPtr, htStr, htX, htY,...
                            obj.Col_Label, obj.Col_LabelBG);
                        
                        % draw artefact details (if present)
                        curArt = obj.prData.art(obj.prChanHover, obj.Trial, :);
                        if any(curArt)
                            artType = cell2char(obj.prData.art_type(curArt));
                            Screen('DrawText', obj.prWinPtr, artType, hrX1, hrY2,...
                                obj.Col_Label, obj.Col_LabelBG);
                        end
                            
                    end

                end

                % draw messages
                msg = [];
                if obj.AutoSetTrialYLim
                    msg = [msg, sprintf(...
                        '\nAuto amplitude scale - y to toggle')]; 
                end
                if ~isempty(msg)
                    Screen('TextSize', obj.prWinPtr, 16);
                    tb = Screen('TextBounds', obj.prWinPtr, msg);
                    msgX = ((obj.prWindowSize(3) -...
                        obj.prWindowSize(1)) / 2) - (tb(3) / 2);
                    msgY = obj.prWindowSize(1) + tb(4) + 5;
                    Screen('DrawText', obj.prWinPtr, msg, msgX, msgY,...
                        obj.Col_Label, obj.Col_LabelBG);
                end
                
                % information pane
                if obj.DrawInfoPane
                    
                    % place info pane 10px from bottom left
                    ix1 = 1;
                    ix2 = ix1 + obj.InfoPaneSize(1);
                    iy2 = obj.prWindowSize(4);
                    iy1 = iy2 - obj.InfoPaneSize(2);
                    
                    % draw info pane BG
                    Screen('FillRect', obj.prWinPtr, [obj.Col_LabelBG, 200],...
                        [ix1, iy1, ix2, iy2]);
                    Screen('FrameRect', obj.prWinPtr, obj.Col_Label,...
                        [ix1, iy1, ix2, iy2]);  
                    
                    % draw trial info
                    strTrial = sprintf('Trial %d/%d', obj.prTrial,...
                        obj.prNumTrials);
                    Screen('TextSize', obj.prWinPtr, obj.InfoPaneFontSize);
                    tb = Screen('TextBounds', obj.prWinPtr, strTrial);
                    strX = ix1 + ((ix2 - ix1) / 2) - (tb(3) / 2);
                    strY = iy1 + 3;
                    Screen('DrawText', obj.prWinPtr, strTrial, strX, strY,...
                        obj.Col_Label);
                    
                    % draw art info
                    artGood = sum(~obj.prData.art(:, obj.prTrial));
                    artBad = sum(obj.prData.art(:, obj.prTrial));
                    artTotal = obj.prNumChannels;
                    percGood = (artGood / artTotal) * 100;
                    percBad = (artBad / artTotal) * 100;
                    strGood = sprintf('Good: %d (%.0f%%)', artGood,...
                        percGood);
                    strBad = sprintf('Bad: %d (%.0f%%)', artBad,...
                        percBad);                    
                    strY = strY + tb(4);
                    tb = Screen('TextBounds', obj.prWinPtr, strGood);
                    strX = ix1 + ((ix2 - ix1) / 2) - (tb(3) / 2);
                    Screen('DrawText', obj.prWinPtr, strGood, strX, strY,...
                        obj.Col_Label);  
                    strY = strY + tb(4);
                    tb = Screen('TextBounds', obj.prWinPtr, strBad);
                    strX = ix1 + ((ix2 - ix1) / 2) - (tb(3) / 2);
                    Screen('DrawText', obj.prWinPtr, strBad, strX, strY,...
                        obj.Col_Label); 
                    
                    % draw info axis
                    strYMin = sprintf('%.0f', obj.prYLim(1));
                    strYMax = sprintf('%.0f', obj.prYLim(2));
                    tMin = round(obj.prData.time{obj.prTrial}(1), 2) * 1000;
                    tMax = round(obj.prData.time{obj.prTrial}(end), 2) * 1000;
                    strTMin = sprintf('%dms', tMin);
                    strTMax = sprintf('%dms', tMax);
                    
                    tbYMin = Screen('TextBounds', obj.prWinPtr, strYMin);
                    tbYMax = Screen('TextBounds', obj.prWinPtr, strYMax);
                    tbTMin = Screen('TextBounds', obj.prWinPtr, strTMin);
                    tbTMax = Screen('TextBounds', obj.prWinPtr, strTMax);
                    
                    wY = max([tbYMin(3), tbYMax(3)]);
                    hT = max([tbTMin(4), tbTMax(4)]);
                    
                    ampX = ix1 + wY + 3;
                    ampY1 = strY + tb(4) + 3;
                    ampY2 = iy2 - hT - 3;
                    Screen('DrawLine', obj.prWinPtr, obj.Col_Label,...
                        ampX, ampY1, ampX, ampY2);
                    Screen('DrawText', obj.prWinPtr, strYMax,...
                        ampX - tbYMax(3) - 2, ampY1, obj.Col_Label);
                    Screen('DrawText', obj.prWinPtr, strYMin,...
                        ampX - tbYMin(3) - 2, ampY2 - tbYMin(4),...
                        obj.Col_Label);
                    
                    timeY = iy2 - hT - 3;
                    timeX1 = ampX;
                    timeX2 = ix2 - 7;
                    Screen('DrawLine', obj.prWinPtr, obj.Col_Label,...
                        timeX1, timeY, timeX2, timeY);
                    Screen('DrawText', obj.prWinPtr, strTMin,...
                        timeX1, timeY + 1, obj.Col_Label);
                    Screen('DrawText', obj.prWinPtr, strTMax,...
                        timeX2 - tbTMax(3) - 2, timeY + 1,...
                        obj.Col_Label);
                    
                end
                
                % trial line
                if obj.DrawTrialLine 
                    if obj.DrawInfoPane
                        % if drawing info pane, place trial line so that it
                        % doesn't overlap
                        tlx1 = ix2 + 10;
                        tlx2 = obj.prWindowSize(3) - tlx1;
                    else
                        % otherwise, use full width of screen
                        tlx1 = 10;
                        tlx2 = obj.prWindowSize(3) - tlx1;
                    end
                    tlh = 40;                           % height
                    tly2 = obj.prWindowSize(4);       % bottom edge
                    tly1 = tly2 - tlh;                  % top edge
                    tlw = tlx2 - tlx1;                  % width
                
                    % calculate steps for tick marks
                    tlxStep = tlw / obj.prNumTrials;
                    tlx = tlx1 + sort(repmat(tlxStep:tlxStep:tlw, 1, 2));
                    tly = repmat([tly1, tly2], 1, obj.prNumTrials);
                    
                    % calculate pos of box representing current trial
                    tltx1 = tlx1 + (tlxStep * (obj.prTrial - 1));
                    tltx2 = tltx1 + tlxStep;
                    
                    % prepare colours flagging trials with/without
                    % artefacts
                    tlCol = repmat([obj.Col_FlagGood, 150],...
                        obj.prNumTrials, 1);
                    anyArt = any(obj.prData.art, 3);
                    bad = any(anyArt, 1);
                    tlCol(bad, 1:3) = repmat(obj.Col_FlagBad, sum(bad), 1);
                    propArt = sum(anyArt, 1) / max(sum(anyArt, 1));
%                     tlfh = tlh * .75;
                    tlfh = zeros(1, obj.prNumTrials);
                    tlfh(bad) = tlh * (1 - propArt);
                    tlfh(~bad) = tlh * 1;
                    tlfx1 = tlx1 + (0:tlxStep:tlw - tlxStep);
                    tlfx2 = tlfx1 + tlxStep;
                    tlfy1 = tly1 + tlfh;
%                     tlfy1 = repmat(tly1 + tlfh, 1, obj.prNumTrials);
                    tlfy2 = repmat(tly2, 1, obj.prNumTrials);
                    
                    Screen('FillRect', obj.prWinPtr, [obj.Col_LabelBG, 150],...
                        [tlx1, tly1, tlx2, tly2]);
                    Screen('FillRect', obj.prWinPtr, obj.Col_Label,...
                        [tltx1, tly1, tltx2, tly2]);
                    Screen('FillRect', obj.prWinPtr, tlCol',...
                        [tlfx1; tlfy1; tlfx2; tlfy2]);
                    Screen('FrameRect', obj.prWinPtr, [obj.Col_Label, 100],...
                        [tlx1, tly1, tlx2, tly2]);
%                     Screen('DrawLines', obj.prWinPtr, [tlx; tly],...
%                         1, [obj.Col_Label, 100]);           


                end
                
                obj.temp(end + 1) = Screen('Flip', obj.prWinPtr);
                    
            end
            
        end
        
        % doing stuff
        function StartInteractive(obj)
            
            obj.Draw
            
            % capture keyboard
            ListenChar(2)
            keyDown = false;
            mx = 0;
            my = 0;
            mButtons = [];
            
            stop = false;
            while ~stop
                
                reDrawNeeded = false;
                
                % poll keyboard
                lastKeyDown = keyDown;
                [keyDown, ~, keyCode] = KbCheck(-1);
                
                % check for multiple keys - not supported right now
                if sum(keyCode) > 1
                    pos = find(keyCode, 1, 'first');
                    keyCode = false(size(keyCode));
                    keyCode(pos) = true;
                end
                
                % poll mouse
                lmx = mx;
                lmy = my;
                lmButtons = mButtons;
                [mx, my, mButtons] = GetMouse(obj.prWinPtr);
                
                % process mouse movement
                if mx ~= lmx && my ~= lmy
                    
                    % find highlighted channel
                    lChanHover = obj.prChanHover;
                    obj.prChanHover = find(...
                        mx >= obj.prChanX + obj.prDrawOffset(1) &...
                        mx <= obj.prChanX + obj.prChanW + obj.prDrawOffset(1) &...
                        my >= obj.prChanY + obj.prDrawOffset(2) &...
                        my <= obj.prChanY + obj.prChanH + obj.prDrawOffset(2),...
                        1, 'first');
                    % check for multiple channels selected - for now, fix
                    % this by taking the first. In future this should take
                    % the NEAREST
                    if length(obj.prChanHover) > 1
                        obj.prChanHover = obj.prChanHover(1);
                    end
                    if ~isequal(obj.prChanHover, lChanHover)
                        reDrawNeeded = true;
                    end
                    
                    % find cursor pos on time series within channel
                    if ~isempty(obj.prChanHover)
                        obj.prChanHoverCursorX = mx;
%                         obj.prChanHoverCursorY =...
%                             obj.prChanY(obj.prChanHover);
                        obj.prChanHoverCursorVisible = true;
                        reDrawNeeded = true;
                    else
                        obj.prChanHoverCursorVisible = true;
                    end
                        
                end
                
                % process mouse clicks
                if ~isequal(lmButtons, mButtons) && ~keyDown
                    
                    % toggle artefact flag on single channel on current trial
                    if mButtons(1) && ~isempty(obj.prChanHover)
                        % get current artefact status
                        curArt = obj.prData.art(obj.prChanHover, obj.prTrial, obj.prArtLayer);
                        switch curArt
                            case false  % not current art, mark as art
%                                 obj.prData.artType{obj.prChanHover, obj.prTrial} = 'Manual';
                                obj.prData.art(obj.prChanHover, obj.prTrial, obj.prArtLayer) = true;
                            case true   % is currently art, mark as not art
%                                 obj.prData.artType{obj.prChanHover, obj.prTrial} = [];                              
                                obj.prData.art(obj.prChanHover, obj.prTrial, obj.prArtLayer) = false;
                        end
%                         obj.Art(obj.prChanHover, obj.prTrial) =...
%                             ~obj.Art(obj.prChanHover, obj.prTrial);
                        reDrawNeeded = true;
                    end
                    
%                     % if cmd key is held down, toggle artefact flag for
%                     % current channel for all trials
%                     if lastKeyDown && keyDown &&...
%                             strmpi(KbName(keyCode), 'LeftGUI') &&...
%                             mButtons(1) && ~isempty(obj.prChanHover)
%                         obj.Art(obj.prChanHover, :) =...      
%                             ~obj.Art(obj.prChanHover, :);
%                     end
                    
                end
                    
                % process keys
                if ~lastKeyDown && keyDown
                    % a single keypress (as opposed to holding a key down)
                    % has been made    
                    switch KbName(keyCode)
                        case 'RightArrow'   % next trial
                            obj.prTrial = obj.prTrial + 1;
                            if obj.prTrial > obj.prNumTrials
                                obj.prTrial = obj.prNumTrials;
                            end
                            obj.PrepareForDrawing
                            reDrawNeeded = true;
                        case 'LeftArrow'    % prev trial
                            obj.prTrial = obj.prTrial - 1;
                            if obj.prTrial < 1
                                obj.prTrial = 1;
                            end
                            obj.PrepareForDrawing
                            reDrawNeeded = true;
                        case 'UpArrow'      % increase amplitude scale
                            obj.AutoSetTrialYLim = false;                              
                            obj.YLim = obj.YLim * .75;
                        case 'DownArrow'    % increase amplitude scale
                            obj.AutoSetTrialYLim = false;
                            obj.YLim = obj.YLim * (1 / .75);
                        case 'y'            % auto amplitude scale
                            obj.AutoSetTrialYLim = ~obj.AutoSetTrialYLim;
                        case 'f'            % toggle fullscreen
                            obj.Fullscreen = ~obj.Fullscreen;
                        case '=+'           % zoom in
                            obj.Zoom = 1.25;
                        case '-_'           % zoom out
                            obj.Zoom = .8;
                        case 'a'            % mark all art
                            if ~all(obj.prData.art(:, obj.prTrial, obj.prArtLayer))
%                                 obj.prData.artType(:, obj.prTrial) =...
%                                     repmat({'Manual'}, obj.prNumChannels, 1);
                                obj.prData.art(:, obj.prTrial, obj.prArtLayer) = true;
                            else
                                obj.prData.art(:, obj.prTrial, obj.prArtLayer) = false;
                            end
                            reDrawNeeded = true;
                        case 'n'            % mark none art
                            obj.prData.art(:, obj.prTrial, obj.prArtLayer) = false;
                        case 'c'            % centre display
                            obj.prDrawSize = obj.prWindowSize;
                            obj.prZoom = 1;
                            obj.prChanHover = [];
                            obj.prChanHoverCursorVisible = false;
                            obj.PrepareForDrawing;
                            reDrawNeeded = true;
                        case ',<'           % prev history
                            hIdx = obj.prArtHistoryIdx - 1;
                            if hIdx > 1 
                                obj.prArtHistoryIdx = hIdx;
                                obj.prData.art =...
                                    obj.prArtHistory{hIdx};
                                reDrawNeeded = true;
                            end
                        case '.>'           % next history
                            hIdx = obj.prArtHistoryIdx + 1;
                            if hIdx <= length(obj.prArtHistory) &&...
                                    ~isempty(obj.prArtHistory(hIdx))
                                obj.prArtHistoryIdx = hIdx;
                                obj.prData.art =...
                                    obj.prArtHistory{hIdx};
                                reDrawNeeded = true;
                            end
                        case 'ESCAPE'       % stop
                            obj.prChanHover = [];
                            obj.prChanHoverCursorVisible = false;
                            if obj.Fullscreen &&...
                                    all(Screen('Screens') == 0) 
                                obj.Fullscreen = false;
                            end
                            reDrawNeeded = true;
                            stop = true;
                    end
                elseif lastKeyDown && keyDown
                    % a key has been held down
                    switch KbName(keyCode)
                        case 'LeftControl'      % pan
                            if mButtons(1)
                                obj.prIsPanning = true;
                                % calculate delta
                                if ~isempty(lmx)
                                    mdx = lmx - mx;
                                    mdy = lmy - my;
                                    obj.prDrawSize = obj.prDrawSize -...
                                        [mdx, mdy, mdx, mdy];
                                    obj.UpdateDrawSize
                                    obj.PrepareForDrawing;
                                    reDrawNeeded = true;
                                end
                            end
                        case 'LeftGUI'          % mark/unmark all
                            if ~lmButtons(1) && mButtons(1) &&...
                                    ~isempty(obj.prChanHover)
                                if ~all(obj.prData.art(obj.prChanHover, :, obj.prArtLayer))
                                    obj.prData.art(obj.prChanHover, :, obj.prArtLayer) = true;  
                                else
                                    obj.prData.art(obj.prChanHover, :, obj.prArtLayer) = false;  
                                end
                            end
                    end
                elseif lastKeyDown && ~keyDown
                    % key has been released
                    if obj.prIsPanning, obj.prIsPanning = false; end
                end
                
                if reDrawNeeded, obj.Draw, end
                
            end
            
            % release keyboard
            ListenChar
            
        end
        
        % property get/set            
        function val = get.ScreenNumber(obj)
            val = obj.prScreenNumber;
        end
        
        function set.ScreenNumber(obj, val)
            % check bounds
            screens = Screen('screens');
            if val > max(screens) || val < min(screens)
                error('ScreenNumber must be between %d and %d.',...
                    min(screens), max(screens))
            end
            obj.prScreenNumber = val;
            obj.ReopenScreen
        end
        
        function val = get.WindowSize(obj)
            val = obj.prWindowSize;
        end
        
        function set.WindowSize(obj, val)
            if obj.Fullscreen
                warning('Window size not set when running in fullscreen mode.')
            else
                obj.prLastWindowSize = obj.WindowSize;
                obj.prWindowSize = val;
                obj.UpdateDrawSize
                obj.ReopenScreen
            end
        end
                
        function val = get.Zoom(obj)
            val = obj.prZoom;
        end
        
        function set.Zoom(obj, val)
            if val < .5, val = .5; end
            obj.prZoom = val;
            obj.UpdateDrawSize
            obj.PrepareForDrawing
            obj.Draw
        end
        
        function val = get.Fullscreen(obj)
            val = obj.prFullscreen;
        end
        
        function set.Fullscreen(obj, val)
            obj.prFullscreen = val;
            
            % determine whether we are going in or out of fullscreen;
            % record new and old window size
            if val
                oldSize = obj.prWindowSize;
                newSize = Screen('Rect', obj.prScreenNumber);
                obj.prLastWindowSize = oldSize;
            else
                oldSize = obj.prWindowSize;
                newSize = obj.prLastWindowSize;
            end
            
            % set focus to screen centre, and zoom to required value given
            % the ratio of new to old size 
            obj.prDrawFocus = oldSize(3:4) / 2;
            obj.prZoom = newSize / oldSize;

            % centre window  
            wcx = obj.prDrawFocus(1);
            wcy = obj.prDrawFocus(2);
            rect = oldSize - [wcx, wcy, wcx, wcy];

            % apply zoom
            rect = rect * obj.prZoom;
            obj.prDrawOffset = obj.prDrawOffset * obj.prZoom;

            % de-centre window
            wcx = wcx * obj.prZoom;
            wcy = wcy * obj.prZoom;
            obj.prDrawSize = rect + [wcx, wcy, wcx, wcy];

            % reset zoom
            obj.prZoom = 1;

            % store new (fullscreen) window size
            obj.prWindowSize = newSize;
            obj.ReopenScreen
        end
        
        function val = get.YLim(obj)
            val = obj.prYLim;
        end
        
        function set.YLim(obj, val)
            if size(val, 1) == 1 && size(val, 2) == 2
                if val(1) < -500, val(1) = -500; end
                if val(2) > 500, val(2) = 500; end
                if val(2) - val(1) < 1, val(2) = val(1) + 1; end
                obj.prYLim = val;
                obj.AutoSetTrialYLim = false;
                obj.PrepareForDrawing
                obj.Draw
            else
                error('YLim must be in the form of [min, max].')
            end
        end
        
        function set.AutoSetTrialYLim(obj, val)
            obj.AutoSetTrialYLim = val;
            obj.PrepareForDrawing
            obj.Draw        
        end
        
        function set.DrawZeroLine(obj, val)
            obj.DrawZeroLine = val;
            obj.Draw;
        end
        
        function set.DrawChannelBackground(obj, val)
            obj.DrawChannelBackground = val;
            obj.Draw;
        end
        
        function set.DrawChannelLabels(obj, val)
            obj.DrawChannelLabels = val;
            obj.Draw
        end
        
        function val = get.Data(obj)
            switch obj.prDataType
                case 'timelock'
                    % rename 'trial' to 'avg', so as to return data in a
                    % valid ft format
                    val = obj.prData;
                    tmp = val.trial{1};
                    val = rmfield(val, 'trial');
                    val.avg = tmp;
                    val.time = val.time{1};
                otherwise
                    val = obj.prData;
            end
        end
        
        function set.Data(obj, val)
            obj.prDrawingPrepared = false;
            obj.prDataType = ft_datatype(val);
            switch obj.prDataType
                case 'raw'
                    obj.prData = val;
                    obj.UpdateData
                    obj.PrepareForDrawing
                    obj.Draw
                case 'timelock'
                    % rename 'avg' to 'trial' and put in cell array, so
                    % that timelock and raw data can be drawn by the same
                    % routines
                    tmp = val.avg;
                    val = rmfield(val, 'avg');
                    val.trial{1} = tmp;
                    val.time = {val.time};
                    obj.prData = val;
                    obj.UpdateData
                    obj.PrepareForDrawing       
                    obj.Draw
                otherwise
                    error('Unrecognised or unsupported data format.')
            end
        end     
        
        % get/set methods for colours/sizes etc.
        function set.Col_BG(obj, val)
            if obj.prScreenOpen
                Screen('FillRect', obj.prWinPtr, val);
                obj.Draw
            end
        end
        
        function set.Col_FG(obj, val)
            obj.Col_FG = val;
            obj.Draw
        end
        
        function set.Col_ChanBG(obj, val)
            obj.Col_ChanBG = val;
            obj.Draw
        end
        
        function set.Col_LabelBG(obj, val)
            obj.Col_LabelBG = val;
            obj.Draw
        end
        
        function set.Col_Label(obj, val)
            obj.Col_Label = val;
            obj.Draw
        end
        
        function set.Col_Hover(obj, val)
            obj.Col_Hover = val;
            obj.Draw
        end        
        
        function set.Col_ArtefactLine(obj, val)
            obj.Col_ArtefactLine = val;
            obj.Draw
        end        
        
        function set.Col_ArtefactBG(obj, val)
            obj.Col_ArtefactBG = val;
            obj.Draw
        end        
        
        function set.Col_InterpLine(obj, val)
            obj.Col_InterpLine = val;
            obj.Draw
        end        
        
        function set.Col_InterpBG(obj, val)
            obj.Col_InterpBG = val;
            obj.Draw
        end              
        
        function set.Col_CantInterpBG(obj, val)
            obj.Col_CantInterpBG = val;
            obj.Draw
        end      
        
        function set.Col_FlagBad(obj, val)
            obj.Col_FlagBad = val;
            obj.Draw
        end              
        
        function set.Col_FlagGood(obj, val)
            obj.Col_FlagGood = val;
            obj.Draw
        end              

        function val = get.Trial(obj)
            % if not valid (implying possibly not data to enumerate trial
            % numbers against), throw an error
            if ~obj.prDataValid
                error('Cannot set Trial when State is not valid: \n%s',...
                    obj.Error);
            end
            val = obj.prTrial;
        end
        
        function set.Trial(obj, val)
            % if not valid (implying possibly not data to enumerate trial
            % numbers against), throw an error
            if ~obj.prDataValid
                error('Cannot set Trial when State is not valid: \n%s',...
                    obj.Error);
            end
            if val > length(obj.prData.trial)
                error('Trial out of bounds.')
            end
            obj.prTrial = val;
            obj.PrepareForDrawing
            obj.Draw
        end       

    end
 
end