% ECKEEGVis - ECK EEG Visualiser
% Version: Alpha 0.1
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

classdef ECKEEGVis < handle
    
    properties
        temp
        Conditions
        DrawZeroLine            = true
        DrawChannelBackground   = true
        DrawChannelLabels       = false
        DrawInfoPane            = true;
        DrawTrialLine           = true;
        ChannelLabelFontSize    = 10
        InfoPaneSize            = [200, 150]
        InfoPaneFontSize        = 13;
        DrawXAxis               = true
        AutoSetTrialYLim        = true
        AutoSetTrialYlimMode    = 'max'
        Col_Series              =   round(lines(100) * 255)
        Col_BG                  =   [000, 000, 000]
        Col_FG                  =   [240, 240, 240]
        Col_ChanBG              =   [020, 020, 020]
        Col_Axis                =   [100, 100, 100]
        Col_LabelBG             =   [040, 020, 100]
        Col_Label               =   [250, 210, 040]
        Col_Hover               =   [250, 210, 040]
        Col_ArtefactLine        =   [230, 040, 040]
        Col_ArtefactBG          =   [040, 020, 020]
        Col_InterpLine          =   [000, 189, 114]
        Col_InterpBG            =   [080, 060, 020]  
        Col_CantInterpBG        =   [100, 000, 100]
        Col_FlagBad             =   [185, 010, 010]
        Col_FlagGood            =   [010, 185, 010]
        DrawPlaneMaxSize        =   40000
    end
    
    properties (SetAccess = private)
    end
    
    properties (Access = private)
        privState
        privWinPtr
        privScreenOpen 
        privScreenNumber
        privWindowSize
        privLastWindowSize
        privZoom
        privDrawSize
        privDrawOffset = [0, 0]
        privDrawFocus
        privFullscreen
        privDrawingPrepared = false
        privData
        privNumData
        privDataType
        privDataValid = false
        privDataOverlay
        privDataHasOverlay = false
        privArtLayer
        privArtValid = false
        privArtHistory = cell({10000, 1})
        privArtHistoryIdx = 1
        privInterp
        privInterpNeigh
        privCantInterp
        privNumTrials
        privNumChannels
        privLayout
        privChanX
        privChanY
        privChanW
        privChanH
        privYLim
        privCoordsEEG
        privCoordsZeroLine
        privCoordsXAxis
        privIsPanning = false
        privChanHover = []
        privChanHoverCursorVisible = false
        privChanHoverCursorX = 0
        privChanHoverCursorY = 0
        privTrial
        privWidth
        privHeight
        privPTBOldSyncTests
        privPTBOldWarningFlag
        privStat
    end
    
    properties (Dependent)
        Data
        Trial
%         Art
%         ArtType
        ScreenNumber
        WindowSize 
        Fullscreen
        YLim
        Zoom
    end
    
    properties (Dependent, SetAccess = private)
        State
        Error
    end
    
    methods 
        
        % constructor
        function obj = ECKEEGVis(data_in)
            
            % status
            obj.privStat = ECKStatus('ECK EEG Visualiser starting up...\n');
            
            % check PTB
            AssertOpenGL
            
            % check fieldtrip
            if ~exist('ft_defaults', 'file')
                ftERR = true;
            else
                try
                    ft_defaults
                    ftERR = false;
                catch 
                    ftERR = true;
                end
            end
            if ftERR
                error('Fieldtrip problem - make sure it is in the Matlab path.')
            end
            
            % disable sync tests and set PTB verbosity to minimum
            obj.privPTBOldSyncTests =...
                Screen('Preference', 'SkipSyncTests', 2);
            obj.privPTBOldWarningFlag =...
                Screen('Preference', 'SuppressAllWarnings', 1);
            
            % screen defaults
            obj.privScreenOpen = false;
            obj.privScreenNumber = max(Screen('screens'));
            if obj.privScreenNumber == 0
                % small window as only one screen
                obj.privWindowSize = round(...
                    Screen('Rect', obj.privScreenNumber) .* .25);
                obj.privFullscreen = false;
            else
                % fullscreen
                obj.privWindowSize = Screen('Rect', obj.privScreenNumber);
                obj.privFullscreen = true;
            end
                       
            % open screen
            obj.OpenScreen
            
            % default zoom to 100%
            obj.privDrawSize = obj.privWindowSize;
            obj.privDrawFocus = obj.privDrawSize(3:4) / 2;
            obj.Zoom = 1;
            
            obj.privStat.Status = '';
            
            if exist('data_in', 'var') && ~isempty(data_in)
                obj.Data = data_in;
                obj.StartInteractive
            end
        
        end
        
        % destructor
        function delete(obj)            
            
            % close open screen
            if obj.privScreenOpen
                obj.CloseScreen
            end
            
           % reset PTB prefs
            Screen('Preference', 'SkipSyncTests', obj.privPTBOldSyncTests);
            Screen('Preference', 'SuppressAllWarnings',...
                obj.privPTBOldWarningFlag);
            
        end
        
        % screen
        function OpenScreen(obj)
            if obj.privScreenOpen
                error('Screen already open.')
            end
            if obj.privFullscreen
                fullscreenFlag = [];
%                 rect = Screen('Rect', obj.ScreenNumber);
                rect = [];
            else
                rect = obj.privWindowSize;
%                 fullscreenFlag = kPsychGUIWindow;
                fullscreenFlag = [];
            end
            obj.privWinPtr = Screen('OpenWindow', obj.privScreenNumber,...
                obj.Col_BG, rect, [], [], [], 1, [], fullscreenFlag);
            Screen('BlendFunction', obj.privWinPtr, GL_SRC_ALPHA,...
                GL_ONE_MINUS_SRC_ALPHA);
            Screen('Preference', 'TextAlphaBlending', 1)
            Screen('TextFont', obj.privWinPtr, 'Consolas');
            obj.privScreenOpen = true;
        end
        
        function CloseScreen(obj)
            if ~obj.privScreenOpen
                error('Screen is not open.')
            end
            Screen('Close', obj.privWinPtr);
            obj.privScreenOpen = false;
        end
        
        function ReopenScreen(obj)
            if obj.privScreenOpen
                obj.CloseScreen
                obj.OpenScreen
                obj.PrepareForDrawing
                obj.Draw
            end
        end   
        
        % data
        function UpdateData(obj)
            
            if isempty(obj.privData)
                obj.privDataValid = false;
                return
            end
           
            % update number of trials, and current trial number
            obj.privNumTrials = length(obj.privData.trial);
            if obj.privTrial > obj.privNumTrials
                obj.privTrial = obj.privNumTrials;
            elseif isempty(obj.privTrial) || obj.privTrial < 1 
                obj.privTrial = 1;
            end
            
            % prepare layout for 2D plotting
            cfg = [];
            cfg.rotate = 270;
            cfg.skipscale = 'yes';
            cfg.skipcomnt = 'yes';
%             cfg.layout = '/Users/luke/Google Drive/Experiments/face erp/fieldtrip-20170314/template/electrode/GSN-HydroCel-129.sfp';
            obj.privLayout = ft_prepare_layout(cfg, obj.privData);
            obj.privLayout.pos(:, 1) = -obj.privLayout.pos(:, 1);
            
            % remove layout channels not in data
            present = cellfun(@(x) ismember(x, obj.privData.label),...
                obj.privLayout.label);
            obj.privLayout.pos = obj.privLayout.pos(present, :);
            obj.privLayout.width = obj.privLayout.width(present);
            obj.privLayout.height = obj.privLayout.height(present);
            obj.privLayout.label = obj.privLayout.label(present);
            
            % remove channels not on the layout
            cfg = [];
            cfg.channel = obj.privLayout.label;
            obj.privData = ft_selectdata(cfg, obj.privData);
            obj.privNumChannels = length(obj.privData.label);
            
            % make empty art structure if one doesn't exist
            createLayer = false;
            if ~isfield(obj.privData, 'art')
                % create empty vars
                obj.privData.art = [];
                obj.privData.art_type = {};
                createLayer = true;
            else
                % look for manual layer
                idx = find(strcmpi(obj.privData.art_type, 'manual'), 1);
                createLayer = createLayer || isempty(idx);
            end
            if createLayer
                if isempty(obj.privData.art)
                    idx = 1;
                else
                    idx = size(obj.privData.art, 3) + 1;
                end
                obj.privData.art(:, :, idx) =...
                    false(length(obj.privData.label),...
                    obj.privNumTrials);
                obj.privData.art_type{idx} = 'manual';
            end
%             obj.privArt = obj.privData.art;
%             obj.privArtType = obj.privData.art_type;
            obj.privArtLayer = idx;
            obj.privArtValid = true;
            
%             % make empty art structure if one doesn't exist
%             if ~isfield(obj.privData, 'art')
%                 obj.privArt = [];
%             else 
%                 obj.privArt = obj.privData.art;
%             end
            
            % check for interp struct
            if isfield(obj.privData, 'interp')
                obj.privInterp = obj.privData.interp;
            else
                obj.privInterp = [];
            end
            
            % check for can't-interp struct
            if isfield(obj.privData, 'cantInterp')
                obj.privCantInterp = obj.privData.cantInterp;
            else
                obj.privCantInterp = false(obj.privNumChannels,...
                    obj.privNumTrials);
            end
            
%             % check for interp neighbours struct
%             if ~isfield(obj.privData, 'interpNeigh') 
%                 obj.privInterpNeigh = obj.privData.interpNeigh;
%             end
            
            % auto set ylim
            yMin = min(cellfun(@(x) min(x(:)), obj.privData.trial));
            yMax = max(cellfun(@(x) max(x(:)), obj.privData.trial));
            obj.privYLim = [yMin, yMax];

            obj.privDataValid = true;
            obj.PrepareForDrawing
            
        end
        
        function UpdateDrawSize(obj)
            
            % check for mouse position - if it is over the window, then use
            % that as the focus (around which to scale the drawing plane) -
            % otherwise use the centre of the window
            [mx, my] = GetMouse(obj.privWinPtr);
            if...
                    mx >= obj.privWindowSize(1) &&...
                    mx <= obj.privWindowSize(3) &&...
                    my >= obj.privWindowSize(2) &&...
                    my <= obj.privWindowSize(4)
                obj.privDrawFocus = [mx, my];
            else
                obj.privDrawFocus = obj.privWindowSize(3:4) / 2;
            end

            % centre window  
            wcx = obj.privDrawFocus(1);
            wcy = obj.privDrawFocus(2);
            rect = obj.privDrawSize - [wcx, wcy, wcx, wcy];
            
            % apply zoom
            rect = rect * obj.privZoom;
            obj.privDrawOffset = obj.privDrawOffset * obj.privZoom;
            
            % de-centre window
            obj.privDrawSize = rect + [wcx, wcy, wcx, wcy];
           
            % reset zoom
            obj.privZoom = 1;
            
        end
        
        function Overlay(obj, olData)
            
            % if a single piece of data has been passed as a struct, put it
            % in a cell array
            if isstruct(olData)
                olData = {olData};
            end
            numOl = length(olData);
            
            % check main data type - can only overlay timelock (erp) data
            if ~strcmpi(obj.privDataType, 'timelock')
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
            
            typeOl{end + 1} = obj.privDataType;
            if ~isequal(typeOl{:})
                error('Overlaid data must all be of the same type, and must match main data type.')
            end
            
            timeOl{end + 1} = obj.privData.time{1};
            if ~isequal(timeOl{:})
                error('Time vectors in main data and overlaid data must match.')
            end
            
            elecOl{end + 1} = obj.privData.label;
            if ~isequal(elecOl{:})
                error('Channels numbers/names in main data and overlaid data must match.')
            end
            
            obj.privDataOverlay = olData;
            obj.privDataHasOverlay = true;
            obj.PrepareForDrawing;
            obj.Draw
            
        end
        
        % drawing
        function PrepareForDrawing(obj)
            
            if ~obj.privDataValid,
                obj.privDrawingPrepared = false;
                return
            end
            
            % width/height of drawing plane
            drW = obj.privDrawSize(3) - obj.privDrawSize(1);
            
            % check that the drawing plane is not out of bounds
            if obj.privDrawSize(1) > obj.privWindowSize(3)
                % left hand edge
                obj.privDrawSize(1) = obj.privWindowSize(3);
                obj.privDrawSize(3) = obj.privDrawSize(1) + drW;
            end
            
            % width/height of drawing plane
            drW = obj.privDrawSize(3) - obj.privDrawSize(1);
            drH = obj.privDrawSize(4) - obj.privDrawSize(2);            
            
            % take electrode positions in layout file, normalise, convert
            % to pixels, make vectors for x, y, w and h coords
            eegX = round((obj.privLayout.pos(:, 1) + .5) * drW) +...
                obj.privDrawSize(1);
            eegY = round((obj.privLayout.pos(:, 2) + .5) * drH) +...
                obj.privDrawSize(2);
            eegW = round(obj.privLayout.width(1) * drW);
            eegH = round(obj.privLayout.height(1) * drH);
            
            % find top-left of each channel, store x, y, w, h
            obj.privChanX = round(eegX - (eegW / 2));
            obj.privChanY = round(eegY - (eegH / 2));
            obj.privChanW = eegW;
            obj.privChanH = eegH;
            
            if obj.privDataHasOverlay
                numOl = 1 + length(obj.privDataOverlay);
                olDat = [{obj.privData}, obj.privDataOverlay];  
            else
                numOl = 1;
                olDat = {obj.privData};
            end
            obj.privCoordsEEG = cell(numOl, 1);

            for ol = 1:numOl
                
                dat = olDat{ol}.trial{obj.privTrial};
                
                % decimate data (to prevent drawing pixels more than once when
                % length of data is greater than pixel width of axes)
                t = obj.privData.time{obj.privTrial};
                numSamps = size(dat, 2);
                downSampIdx = round(1:numSamps / obj.privChanW:numSamps);
                if length(downSampIdx) < obj.privChanW
                    missing = obj.privChanW - length(downSampIdx);
                    downSampIdx =...
                        [downSampIdx, repmat(downSampIdx(end), 1, missing)];
                end
                dat = dat(:, downSampIdx);
                t = t(downSampIdx);

                % optionally auto-set y axis limits
                if obj.AutoSetTrialYLim
                    switch obj.AutoSetTrialYlimMode
                        case 'max'
                            obj.privYLim = [min(dat(:)), max(dat(:))];
                        case 'quartile'
                            obj.privYLim =...
                                [prctile(dat(:), 10), prctile(dat(:), 90)];
                    end
                end

                % find x coords for each sample of time series data, across all
                % channels
                x = repmat(1:obj.privChanW, obj.privNumChannels, 1) +...
                    repmat(obj.privChanX, 1, size(dat, 2));

                % rescale y (amplitude) values to pixels, find y values for
                % each sample of time series data
                ylr = obj.privYLim(1) - obj.privYLim(2);
                yls = obj.privChanH / ylr;
                y = round(dat * yls) - (yls * obj.privYLim(2)) +...
                    repmat(obj.privChanY, 1, size(dat, 2));

                % remove any channels that are offscreen
                offScreen = all(...
                    x < obj.privWindowSize(1) &...
                    x > obj.privWindowSize(3) & ...
                    y < obj.privWindowSize(2) &...
                    y > obj.privWindowSize(4), 2);
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
                obj.privCoordsEEG{ol} = coords_ts;
                
            end
            
            % find zero crossing on x axis, store for drawing
            zeroCross = find(t > 0, 1, 'first');
            zeroX = obj.privChanX' + zeroCross;
            zeroY = obj.privChanY';
            zeroIdx = sort(repmat(1:length(zeroX), 1, 2));
            zeroX = zeroX(zeroIdx);
            zeroY = zeroY(zeroIdx);
            zeroIdx = 1:2:length(zeroY);
            zeroY(zeroIdx) = zeroY(zeroIdx) + obj.privChanH;
            obj.privCoordsZeroLine = [zeroX; zeroY];
            
            % prepare lines for x axes
            yCross = round(abs(obj.privYLim(1)) / sum(abs(obj.privYLim))...
                * obj.privChanH);
            xAxisX = obj.privChanX';
            xAxisY = obj.privChanY' + yCross;
            xAxisIdx = sort(repmat(1:length(xAxisX), 1, 2));
            xAxisX = xAxisX(xAxisIdx);
            xAxisY = xAxisY(xAxisIdx);
            xAxisIdx = 1:2:length(xAxisY);
            xAxisX(xAxisIdx) = xAxisX(xAxisIdx) + obj.privChanW;
            obj.privCoordsXAxis = [xAxisX; xAxisY];
            
            obj.privDrawingPrepared = true;
            
        end
        
        function Draw(obj)
            
            if obj.privDrawingPrepared
                
                % draw background colour (red if any artefacts)
%                 if any(obj.privArt(:, obj.Trial, obj.privArtLayer))
                if any(any(obj.privData.art(:, obj.Trial, :)))
                    Screen('FillRect', obj.privWinPtr, obj.Col_ArtefactBG);
                else
                    Screen('FillRect', obj.privWinPtr, obj.Col_BG);
                end
                
                Screen('TextSize', obj.privWinPtr, obj.ChannelLabelFontSize);
                
                % channel background panes
                if obj.DrawChannelBackground
                    
                    % arrange coords of backgrounds into a PTB-friendly
                    % format
                    coords = [...
                        obj.privChanX' + obj.privDrawOffset(1);...
                        obj.privChanY' + obj.privDrawOffset(2);...
                        obj.privChanX' + obj.privChanW' + obj.privDrawOffset(1);...
                        obj.privChanY' + obj.privChanH' + obj.privDrawOffset(2)];
                    
                    % select colours for bad channels
                    bad = any(obj.privData.art(:, obj.privTrial, :), 3);
                    chanBGCols =...
                        repmat(obj.Col_ChanBG', 1, obj.privNumChannels);
                    chanBGCols(:, bad) =...
                        repmat(obj.Col_ArtefactBG', 1, sum(bad));
                    
%                     % select colours for interpolated channels
%                     if ~isempty(obj.privInterp)
%                         interp = obj.privInterp(:, obj.privTrial) & ~bad;
%                         chanBGCols(:, interp) =...
%                             repmat(obj.Col_InterpBG', 1, sum(interp));
%                     end
                    
                    % draw
                    Screen('FillRect', obj.privWinPtr, chanBGCols,...
                        coords);
                    
                end
                        
                % draw channels
                eegRow = 1;
                for ch = 1:obj.privNumChannels
                    
                    % interp
                    if ~isempty(obj.privInterp) &&...
                            obj.privInterp(ch, obj.privTrial)
                        interpRect = [...
                            obj.privChanX(ch) + obj.privDrawOffset(1),...
                            obj.privChanY(ch) + obj.privDrawOffset(2),...
                            obj.privChanX(ch) + obj.privChanW + obj.privDrawOffset(1),...
                            obj.privChanY(ch) + obj.privChanH + obj.privDrawOffset(2)];
                        Screen('FrameRect', obj.privWinPtr,...
                            obj.Col_InterpBG, interpRect, 4); 
                    end
                    
                    % can't-interp 
                    if obj.privCantInterp(ch, obj.privTrial)
                        cantInterpRect = [...
                            obj.privChanX(ch) + obj.privDrawOffset(1),...
                            obj.privChanY(ch) + obj.privDrawOffset(2),...
                            obj.privChanX(ch) + obj.privChanW + obj.privDrawOffset(1),...
                            obj.privChanY(ch) + obj.privChanH + obj.privDrawOffset(2)];
                        Screen('FrameRect', obj.privWinPtr,...
                            obj.Col_CantInterpBG, cantInterpRect, 4);                        
                        
%                         ciX = obj.privChanX(ch) + obj.privChanW +...
%                             obj.privDrawOffset(1) - tb_ci(3);
%                         ciY = obj.privChanY(ch) + obj.privDrawOffset(2);
%                         Screen('DrawText', obj.privWinPtr, 'X', ciX, ciY,...
%                             obj.Col_ArtefactLine, obj.Col_ArtefactBG);
                    end
                    
                    % x axis
                    if obj.DrawXAxis
                        coords = obj.privCoordsXAxis(:, eegRow:eegRow + 1);
                        coords(1, :) = coords(1, :) + obj.privDrawOffset(1);
                        coords(2, :) = coords(2, :) + obj.privDrawOffset(2);
                        Screen('DrawLines', obj.privWinPtr,...
                            coords, 1, obj.Col_Axis, [0, 0], 2);
                    end
                    
                    % zero line
                    if obj.DrawZeroLine
                        coords = obj.privCoordsZeroLine(:, eegRow:eegRow + 1);
                        coords(1, :) = coords(1, :) + obj.privDrawOffset(1);
                        coords(2, :) = coords(2, :) + obj.privDrawOffset(2);                        
                        Screen('DrawLines', obj.privWinPtr,...
                            coords, 1, obj.Col_Axis, [0, 0], 2); 
                    end
                        
                    % time series
                    if obj.privDataHasOverlay
                        numOl = 1 + length(obj.privDataOverlay);
                    else
                        numOl = 1;
                    end
                    for ol = 1:numOl
                        if ch == obj.privChanHover, lineW = 2; else...
                                lineW = 1; end
%                         if obj.privArt(ch, obj.privTrial, obj.privArtLayer) &&...
                        if any(obj.privData.art(ch, obj.privTrial, :), 3) &&...
                                ~obj.privDataHasOverlay
                            lineCol = obj.Col_ArtefactLine;
%                             lineCol = obj.Col_Series(ol, :);
    %                     elseif obj.privInterp(ch, obj.privTrial)
    %                         lineCol = obj.Col_InterpLine;
                        else
                            lineCol = obj.Col_Series(ol, :);
                        end
                        coords = obj.privCoordsEEG{ol}(eegRow:eegRow + 1, :);
                            coords(1, :) = coords(1, :) + obj.privDrawOffset(1);
                            coords(2, :) = coords(2, :) + obj.privDrawOffset(2);                      
                        Screen('DrawLines', obj.privWinPtr, coords,...
                            lineW, lineCol, [0, 0], 2);
                    end
                    
                    % channel labels
                    if obj.DrawChannelLabels
                        tb = Screen('TextBounds', obj.privWinPtr,...
                            obj.privData.label{ch});
                        labX = obj.privChanX(ch) +...
                            obj.privDrawOffset(1);
                        labY = obj.privChanY(ch) + obj.privChanH -...
                            tb(4) + obj.privDrawOffset(2);
                        
                        Screen('DrawText', obj.privWinPtr,...
                            obj.privData.label{ch}, labX, labY,...
                            obj.Col_Label, obj.Col_LabelBG);
                    end
                        
                    eegRow = eegRow + 2;
                    
                end
                
                % channel hover highlight
                if ~isempty(obj.privChanHover)
                    hrX1 = obj.privChanX(obj.privChanHover) +...
                        obj.privDrawOffset(1);
                    hrY1 = obj.privChanY(obj.privChanHover) +...
                        obj.privDrawOffset(2);
                    hrX2 = obj.privChanX(obj.privChanHover) +...
                        obj.privChanW + obj.privDrawOffset(1);
                    hrY2 = obj.privChanY(obj.privChanHover) +...
                        obj.privChanH + obj.privDrawOffset(2);
                    hovRect = [hrX1, hrY1, hrX2, hrY2];
                    Screen('FrameRect', obj.privWinPtr, obj.Col_Hover,...
                        hovRect, 1);
                    
                    % channel hover cursor
                    if obj.privChanHoverCursorVisible
                        
                        % look up x location (hcX) and y index value based
                        % upon x mouse position
                        hcX = obj.privChanHoverCursorX;
                        idx = ceil((obj.privChanHoverCursorX -...
                            obj.privChanX(obj.privChanHover)) * 2);
                        
                        % look up y location (hcY), check bounds and draw
                        if idx > 0 && idx < size(obj.privCoordsEEG{ol}, 2)
                            hcY = obj.privCoordsEEG{ol}(obj.privChanHover * 2, idx)...
                                + obj.privDrawOffset(2);
                            if hrY1 > hcY, hrY1 = hcY; end
                            if hcY > hrY2, hrY2 = hcY; end
                            Screen('DrawDots', obj.privWinPtr,...
                                [hcX, hcY],...
                                5, obj.Col_Hover, [], 3);
                            
                        end
                        
                        % draw y cursor line
                        Screen('DrawLine', obj.privWinPtr,...
                            [obj.Col_Hover, 200], hcX, hrY1, hcX, hrY2, 1);
                        
                        % draw time and voltage values
                        htX = hcX;
                        htY = obj.privChanY(obj.privChanHover) - 12;
                        
                        htProp = (htX - hrX1) / (hrX2 - hrX1);
                        htDataIdx = ceil(htProp *...
                            size(obj.privData.trial{obj.privTrial}, 2));
                        htXVal = round(obj.privData.time{obj.privTrial}(...
                            htDataIdx) * 1000);
                        htYVal = obj.privData.trial{obj.privTrial}(...
                            obj.privChanHover, htDataIdx);

                        % draw time and amplitude at cursor
                        htStr = sprintf('%s | %.1fuV @ %dms',...
                            obj.privData.label{obj.privChanHover},...
                            htYVal, htXVal);
                        Screen('DrawText', obj.privWinPtr, htStr, htX, htY,...
                            obj.Col_Label, obj.Col_LabelBG);
                        
                        % draw artefact details (if present)
                        curArt = obj.privData.art(obj.privChanHover, obj.Trial, :);
                        if any(curArt)
                            artType = cell2char(obj.privData.art_type(curArt));
                            Screen('DrawText', obj.privWinPtr, artType, hrX1, hrY2,...
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
                    Screen('TextSize', obj.privWinPtr, 16);
                    tb = Screen('TextBounds', obj.privWinPtr, msg);
                    msgX = ((obj.privWindowSize(3) -...
                        obj.privWindowSize(1)) / 2) - (tb(3) / 2);
                    msgY = obj.privWindowSize(1) + tb(4) + 5;
                    Screen('DrawText', obj.privWinPtr, msg, msgX, msgY,...
                        obj.Col_Label, obj.Col_LabelBG);
                end
                
                % information pane
                if obj.DrawInfoPane
                    
                    % place info pane 10px from bottom left
                    ix1 = 1;
                    ix2 = ix1 + obj.InfoPaneSize(1);
                    iy2 = obj.privWindowSize(4);
                    iy1 = iy2 - obj.InfoPaneSize(2);
                    
                    % draw info pane BG
                    Screen('FillRect', obj.privWinPtr, [obj.Col_LabelBG, 200],...
                        [ix1, iy1, ix2, iy2]);
                    Screen('FrameRect', obj.privWinPtr, obj.Col_Label,...
                        [ix1, iy1, ix2, iy2]);  
                    
                    % draw trial info
                    strTrial = sprintf('Trial %d/%d', obj.privTrial,...
                        obj.privNumTrials);
                    Screen('TextSize', obj.privWinPtr, obj.InfoPaneFontSize);
                    tb = Screen('TextBounds', obj.privWinPtr, strTrial);
                    strX = ix1 + ((ix2 - ix1) / 2) - (tb(3) / 2);
                    strY = iy1 + 3;
                    Screen('DrawText', obj.privWinPtr, strTrial, strX, strY,...
                        obj.Col_Label);
                    
                    % draw art info
                    artGood = sum(~obj.privData.art(:, obj.privTrial));
                    artBad = sum(obj.privData.art(:, obj.privTrial));
                    artTotal = obj.privNumChannels;
                    percGood = (artGood / artTotal) * 100;
                    percBad = (artBad / artTotal) * 100;
                    strGood = sprintf('Good: %d (%.0f%%)', artGood,...
                        percGood);
                    strBad = sprintf('Bad: %d (%.0f%%)', artBad,...
                        percBad);                    
                    strY = strY + tb(4);
                    tb = Screen('TextBounds', obj.privWinPtr, strGood);
                    strX = ix1 + ((ix2 - ix1) / 2) - (tb(3) / 2);
                    Screen('DrawText', obj.privWinPtr, strGood, strX, strY,...
                        obj.Col_Label);  
                    strY = strY + tb(4);
                    tb = Screen('TextBounds', obj.privWinPtr, strBad);
                    strX = ix1 + ((ix2 - ix1) / 2) - (tb(3) / 2);
                    Screen('DrawText', obj.privWinPtr, strBad, strX, strY,...
                        obj.Col_Label); 
                    
                    % draw info axis
                    strYMin = sprintf('%.0f', obj.privYLim(1));
                    strYMax = sprintf('%.0f', obj.privYLim(2));
                    tMin = round(obj.privData.time{obj.privTrial}(1), 2) * 1000;
                    tMax = round(obj.privData.time{obj.privTrial}(end), 2) * 1000;
                    strTMin = sprintf('%dms', tMin);
                    strTMax = sprintf('%dms', tMax);
                    
                    tbYMin = Screen('TextBounds', obj.privWinPtr, strYMin);
                    tbYMax = Screen('TextBounds', obj.privWinPtr, strYMax);
                    tbTMin = Screen('TextBounds', obj.privWinPtr, strTMin);
                    tbTMax = Screen('TextBounds', obj.privWinPtr, strTMax);
                    
                    wY = max([tbYMin(3), tbYMax(3)]);
                    hT = max([tbTMin(4), tbTMax(4)]);
                    
                    ampX = ix1 + wY + 3;
                    ampY1 = strY + tb(4) + 3;
                    ampY2 = iy2 - hT - 3;
                    Screen('DrawLine', obj.privWinPtr, obj.Col_Label,...
                        ampX, ampY1, ampX, ampY2);
                    Screen('DrawText', obj.privWinPtr, strYMax,...
                        ampX - tbYMax(3) - 2, ampY1, obj.Col_Label);
                    Screen('DrawText', obj.privWinPtr, strYMin,...
                        ampX - tbYMin(3) - 2, ampY2 - tbYMin(4),...
                        obj.Col_Label);
                    
                    timeY = iy2 - hT - 3;
                    timeX1 = ampX;
                    timeX2 = ix2 - 7;
                    Screen('DrawLine', obj.privWinPtr, obj.Col_Label,...
                        timeX1, timeY, timeX2, timeY);
                    Screen('DrawText', obj.privWinPtr, strTMin,...
                        timeX1, timeY + 1, obj.Col_Label);
                    Screen('DrawText', obj.privWinPtr, strTMax,...
                        timeX2 - tbTMax(3) - 2, timeY + 1,...
                        obj.Col_Label);
                    
                end
                
                % trial line
                if obj.DrawTrialLine 
                    if obj.DrawInfoPane
                        % if drawing info pane, place trial line so that it
                        % doesn't overlap
                        tlx1 = ix2 + 10;
                        tlx2 = obj.privWindowSize(3) - tlx1;
                    else
                        % otherwise, use full width of screen
                        tlx1 = 10;
                        tlx2 = obj.privWindowSize(3) - tlx1;
                    end
                    tlh = 40;                           % height
                    tly2 = obj.privWindowSize(4);       % bottom edge
                    tly1 = tly2 - tlh;                  % top edge
                    tlw = tlx2 - tlx1;                  % width
                
                    % calculate steps for tick marks
                    tlxStep = tlw / obj.privNumTrials;
                    tlx = tlx1 + sort(repmat(tlxStep:tlxStep:tlw, 1, 2));
                    tly = repmat([tly1, tly2], 1, obj.privNumTrials);
                    
                    % calculate pos of box representing current trial
                    tltx1 = tlx1 + (tlxStep * (obj.privTrial - 1));
                    tltx2 = tltx1 + tlxStep;
                    
                    % prepare colours flagging trials with/without
                    % artefacts
                    tlCol = repmat([obj.Col_FlagGood, 150],...
                        obj.privNumTrials, 1);
                    anyArt = any(obj.privData.art, 3);
                    bad = any(anyArt, 1);
                    tlCol(bad, 1:3) = repmat(obj.Col_FlagBad, sum(bad), 1);
                    propArt = sum(anyArt, 1) / max(sum(anyArt, 1));
%                     tlfh = tlh * .75;
                    tlfh = zeros(1, obj.privNumTrials);
                    tlfh(bad) = tlh * (1 - propArt);
                    tlfh(~bad) = tlh * 1;
                    tlfx1 = tlx1 + (0:tlxStep:tlw - tlxStep);
                    tlfx2 = tlfx1 + tlxStep;
                    tlfy1 = tly1 + tlfh;
%                     tlfy1 = repmat(tly1 + tlfh, 1, obj.privNumTrials);
                    tlfy2 = repmat(tly2, 1, obj.privNumTrials);
                    
                    Screen('FillRect', obj.privWinPtr, [obj.Col_LabelBG, 150],...
                        [tlx1, tly1, tlx2, tly2]);
                    Screen('FillRect', obj.privWinPtr, obj.Col_Label,...
                        [tltx1, tly1, tltx2, tly2]);
                    Screen('FillRect', obj.privWinPtr, tlCol',...
                        [tlfx1; tlfy1; tlfx2; tlfy2]);
                    Screen('FrameRect', obj.privWinPtr, [obj.Col_Label, 100],...
                        [tlx1, tly1, tlx2, tly2]);
%                     Screen('DrawLines', obj.privWinPtr, [tlx; tly],...
%                         1, [obj.Col_Label, 100]);           


                end
                
                obj.temp(end + 1) = Screen('Flip', obj.privWinPtr);
                    
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
                [mx, my, mButtons] = GetMouse(obj.privWinPtr);
                
                % process mouse movement
                if mx ~= lmx && my ~= lmy
                    
                    % find highlighted channel
                    lChanHover = obj.privChanHover;
                    obj.privChanHover = find(...
                        mx >= obj.privChanX + obj.privDrawOffset(1) &...
                        mx <= obj.privChanX + obj.privChanW + obj.privDrawOffset(1) &...
                        my >= obj.privChanY + obj.privDrawOffset(2) &...
                        my <= obj.privChanY + obj.privChanH + obj.privDrawOffset(2),...
                        1, 'first');
                    % check for multiple channels selected - for now, fix
                    % this by taking the first. In future this should take
                    % the NEAREST
                    if length(obj.privChanHover) > 1
                        obj.privChanHover = obj.privChanHover(1);
                    end
                    if ~isequal(obj.privChanHover, lChanHover)
                        reDrawNeeded = true;
                    end
                    
                    % find cursor pos on time series within channel
                    if ~isempty(obj.privChanHover)
                        obj.privChanHoverCursorX = mx;
%                         obj.privChanHoverCursorY =...
%                             obj.privChanY(obj.privChanHover);
                        obj.privChanHoverCursorVisible = true;
                        reDrawNeeded = true;
                    else
                        obj.privChanHoverCursorVisible = true;
                    end
                        
                end
                
                % process mouse clicks
                if ~isequal(lmButtons, mButtons) && ~keyDown
                    
                    % toggle artefact flag on single channel on current trial
                    if mButtons(1) && ~isempty(obj.privChanHover)
                        % get current artefact status
                        curArt = obj.privData.art(obj.privChanHover, obj.privTrial, obj.privArtLayer);
                        switch curArt
                            case false  % not current art, mark as art
%                                 obj.privData.artType{obj.privChanHover, obj.privTrial} = 'Manual';
                                obj.privData.art(obj.privChanHover, obj.privTrial, obj.privArtLayer) = true;
                            case true   % is currently art, mark as not art
%                                 obj.privData.artType{obj.privChanHover, obj.privTrial} = [];                              
                                obj.privData.art(obj.privChanHover, obj.privTrial, obj.privArtLayer) = false;
                        end
%                         obj.Art(obj.privChanHover, obj.privTrial) =...
%                             ~obj.Art(obj.privChanHover, obj.privTrial);
                        reDrawNeeded = true;
                    end
                    
%                     % if cmd key is held down, toggle artefact flag for
%                     % current channel for all trials
%                     if lastKeyDown && keyDown &&...
%                             strmpi(KbName(keyCode), 'LeftGUI') &&...
%                             mButtons(1) && ~isempty(obj.privChanHover)
%                         obj.Art(obj.privChanHover, :) =...      
%                             ~obj.Art(obj.privChanHover, :);
%                     end
                    
                end
                    
                % process keys
                if ~lastKeyDown && keyDown
                    % a single keypress (as opposed to holding a key down)
                    % has been made    
                    switch KbName(keyCode)
                        case 'RightArrow'   % next trial
                            obj.privTrial = obj.privTrial + 1;
                            if obj.privTrial > obj.privNumTrials
                                obj.privTrial = obj.privNumTrials;
                            end
                            obj.PrepareForDrawing
                            reDrawNeeded = true;
                        case 'LeftArrow'    % prev trial
                            obj.privTrial = obj.privTrial - 1;
                            if obj.privTrial < 1
                                obj.privTrial = 1;
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
                            if ~all(obj.privData.art(:, obj.privTrial, obj.privArtLayer))
%                                 obj.privData.artType(:, obj.privTrial) =...
%                                     repmat({'Manual'}, obj.privNumChannels, 1);
                                obj.privData.art(:, obj.privTrial, obj.privArtLayer) = true;
                            else
                                obj.privData.art(:, obj.privTrial, obj.privArtLayer) = false;
                            end
                            reDrawNeeded = true;
                        case 'n'            % mark none art
                            obj.privData.art(:, obj.privTrial, obj.privArtLayer) = false;
                        case 'c'            % centre display
                            obj.privDrawSize = obj.privWindowSize;
                            obj.privZoom = 1;
                            obj.privChanHover = [];
                            obj.privChanHoverCursorVisible = false;
                            obj.PrepareForDrawing;
                            reDrawNeeded = true;
                        case ',<'           % prev history
                            hIdx = obj.privArtHistoryIdx - 1;
                            if hIdx > 1 
                                obj.privArtHistoryIdx = hIdx;
                                obj.privData.art =...
                                    obj.privArtHistory{hIdx};
                                reDrawNeeded = true;
                            end
                        case '.>'           % next history
                            hIdx = obj.privArtHistoryIdx + 1;
                            if hIdx <= length(obj.privArtHistory) &&...
                                    ~isempty(obj.privArtHistory(hIdx))
                                obj.privArtHistoryIdx = hIdx;
                                obj.privData.art =...
                                    obj.privArtHistory{hIdx};
                                reDrawNeeded = true;
                            end
                        case 'ESCAPE'       % stop
                            obj.privChanHover = [];
                            obj.privChanHoverCursorVisible = false;
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
                                obj.privIsPanning = true;
                                % calculate delta
                                if ~isempty(lmx)
                                    mdx = lmx - mx;
                                    mdy = lmy - my;
                                    obj.privDrawSize = obj.privDrawSize -...
                                        [mdx, mdy, mdx, mdy];
                                    obj.UpdateDrawSize
                                    obj.PrepareForDrawing;
                                    reDrawNeeded = true;
                                end
                            end
                        case 'LeftGUI'          % mark/unmark all
                            if ~lmButtons(1) && mButtons(1) &&...
                                    ~isempty(obj.privChanHover)
                                if ~all(obj.privData.art(obj.privChanHover, :, obj.privArtLayer))
                                    obj.privData.art(obj.privChanHover, :, obj.privArtLayer) = true;  
                                else
                                    obj.privData.art(obj.privChanHover, :, obj.privArtLayer) = false;  
                                end
                            end
                    end
                elseif lastKeyDown && ~keyDown
                    % key has been released
                    if obj.privIsPanning, obj.privIsPanning = false; end
                end
                
                if reDrawNeeded, obj.Draw, end
                
            end
            
            % release keyboard
            ListenChar
            
        end
        
        % property get/set            
        function val = get.ScreenNumber(obj)
            val = obj.privScreenNumber;
        end
        
        function set.ScreenNumber(obj, val)
            % check bounds
            screens = Screen('screens');
            if val > max(screens) || val < min(screens)
                error('ScreenNumber must be between %d and %d.',...
                    min(screens), max(screens))
            end
            obj.privScreenNumber = val;
            obj.ReopenScreen
        end
        
        function val = get.WindowSize(obj)
            val = obj.privWindowSize;
        end
        
        function set.WindowSize(obj, val)
            if obj.Fullscreen
                warning('Window size not set when running in fullscreen mode.')
            else
                obj.privLastWindowSize = obj.WindowSize;
                obj.privWindowSize = val;
                obj.UpdateDrawSize
                obj.ReopenScreen
            end
        end
                
        function val = get.Zoom(obj)
            val = obj.privZoom;
        end
        
        function set.Zoom(obj, val)
            if val < .5, val = .5; end
            obj.privZoom = val;
            obj.UpdateDrawSize
            obj.PrepareForDrawing
            obj.Draw
        end
        
        function val = get.Fullscreen(obj)
            val = obj.privFullscreen;
        end
        
        function set.Fullscreen(obj, val)
            obj.privFullscreen = val;
            
            % determine whether we are going in or out of fullscreen;
            % record new and old window size
            if val
                oldSize = obj.privWindowSize;
                newSize = Screen('Rect', obj.privScreenNumber);
                obj.privLastWindowSize = oldSize;
            else
                oldSize = obj.privWindowSize;
                newSize = obj.privLastWindowSize;
            end
            
            % set focus to screen centre, and zoom to required value given
            % the ratio of new to old size 
            obj.privDrawFocus = oldSize(3:4) / 2;
            obj.privZoom = newSize / oldSize;

            % centre window  
            wcx = obj.privDrawFocus(1);
            wcy = obj.privDrawFocus(2);
            rect = oldSize - [wcx, wcy, wcx, wcy];

            % apply zoom
            rect = rect * obj.privZoom;
            obj.privDrawOffset = obj.privDrawOffset * obj.privZoom;

            % de-centre window
            wcx = wcx * obj.privZoom;
            wcy = wcy * obj.privZoom;
            obj.privDrawSize = rect + [wcx, wcy, wcx, wcy];

            % reset zoom
            obj.privZoom = 1;

            % store new (fullscreen) window size
            obj.privWindowSize = newSize;
            obj.ReopenScreen
        end
        
        function val = get.YLim(obj)
            val = obj.privYLim;
        end
        
        function set.YLim(obj, val)
            if size(val, 1) == 1 && size(val, 2) == 2
                if val(1) < -500, val(1) = -500; end
                if val(2) > 500, val(2) = 500; end
                if val(2) - val(1) < 1, val(2) = val(1) + 1; end
                obj.privYLim = val;
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
            switch obj.privDataType
                case 'timelock'
                    % rename 'trial' to 'avg', so as to return data in a
                    % valid ft format
                    val = obj.privData;
                    tmp = val.trial{1};
                    val = rmfield(val, 'trial');
                    val.avg = tmp;
                    val.time = val.time{1};
                otherwise
                    val = obj.privData;
            end
        end
        
        function set.Data(obj, val)
            obj.privDrawingPrepared = false;
            obj.privDataType = ft_datatype(val);
            switch obj.privDataType
                case 'raw'
                    obj.privData = val;
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
                    obj.privData = val;
                    obj.UpdateData
                    obj.PrepareForDrawing       
                    obj.Draw
                otherwise
                    error('Unrecognised or unsupported data format.')
            end
        end     
        
        % get/set methods for colours/sizes etc.
        function set.Col_BG(obj, val)
            if obj.privScreenOpen
                Screen('FillRect', obj.privWinPtr, val);
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
            if ~obj.privDataValid
                error('Cannot set Trial when State is not valid: \n%s',...
                    obj.Error);
            end
            val = obj.privTrial;
        end
        
        function set.Trial(obj, val)
            % if not valid (implying possibly not data to enumerate trial
            % numbers against), throw an error
            if ~obj.privDataValid
                error('Cannot set Trial when State is not valid: \n%s',...
                    obj.Error);
            end
            if val > length(obj.privData.trial)
                error('Trial out of bounds.')
            end
            obj.privTrial = val;
            obj.PrepareForDrawing
            obj.Draw
        end       

    end
 
end