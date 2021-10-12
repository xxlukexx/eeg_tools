classdef teEEGVis < handle
    
    properties
%         temp
%         Conditions
%         DrawZeroLine            = true
%         DrawChannelBackground   = true
%         DrawChannelLabels       = false
%         DrawInfoPane            = true;
%         DrawTrialLine           = true;
%         ChannelLabelFontSize    = 10
%         InfoPaneSize            = [200, 150]
%         InfoPaneFontSize        = 13;
%         DrawXAxis               = true
%         AutoSetTrialYLim        = true
%         AutoSetTrialYlimMode    = 'max'
%         Col_Series              =   round(lines(100) * 255)
%         Col_BG                  =   [000, 000, 000]
%         Col_FG                  =   [240, 240, 240]
%         Col_ChanBG              =   [020, 020, 020]
%         Col_Axis                =   [100, 100, 100]
%         Col_LabelBG             =   [040, 020, 100]
%         Col_Label               =   [250, 210, 040]
%         Col_Hover               =   [250, 210, 040]
%         Col_ArtefactLine        =   [230, 040, 040]
%         Col_ArtefactBG          =   [040, 020, 020]
%         Col_InterpLine          =   [000, 189, 114]
%         Col_InterpBG            =   [080, 060, 020]  
%         Col_CantInterpBG        =   [100, 000, 100]
%         Col_FlagBad             =   [185, 010, 010]
%         Col_FlagGood            =   [010, 185, 010]
%         DrawPlaneMaxSize        =   40000
    end
    
    properties (SetAccess = private)
    end
    
    properties (Access = private)
        prState
        prWinPtr
        prScreenOpen 
        prScreenNumber
%         prWindowSize
%         prLastWindowSize
%         prZoom
%         prDrawSize
%         prDrawOffset = [0, 0]
%         prDrawFocus
%         prFullscreen
%         prDrawingPrepared = false
%         prData
%         prNumData
%         prDataType
%         prDataValid = false
%         prDataOverlay
%         prDataHasOverlay = false
%         prArtLayer
%         prArtValid = false
%         prArtHistory = cell({10000, 1})
%         prArtHistoryIdx = 1
%         prInterp
%         prInterpNeigh
%         prCantInterp
%         prNumTrials
%         prNumChannels
%         prLayout
%         prChanX
%         prChanY
%         prChanW
%         prChanH
%         prYLim
%         prCoordsEEG
%         prCoordsZeroLine
%         prCoordsXAxis
%         prIsPanning = false
%         prChanHover = []
%         prChanHoverCursorVisible = false
%         prChanHoverCursorX = 0
%         prChanHoverCursorY = 0
%         prTrial
%         prWidth
%         prHeight
%         prPTBOldSyncTests
%         prPTBOldWarningFlag
%         prStat
    end
    
    properties (Dependent)
%         Data
%         Trial
% %         Art
% %         ArtType
%         ScreenNumber
%         WindowSize 
%         Fullscreen
%         YLim
%         Zoom
    end
    
    properties (Dependent, SetAccess = private)
%         State
%         Error
    end
    
    methods 
        
        % constructor
        function obj = ECKEEGVis(data_in)
            
            % status
            teEcho('Task Engine EEG Visualiser starting up...\n');
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
            obj.prPTBOldSyncTests =...
                Screen('Preference', 'SkipSyncTests', 2);
            obj.prPTBOldWarningFlag =...
                Screen('Preference', 'SuppressAllWarnings', 1);
            % screen defaults
            obj.prScreenOpen = false;
            obj.prScreenNumber = max(Screen('screens'));
            if obj.prScreenNumber == 0
                % small window as only one screen
                obj.prWindowSize = round(...
                    Screen('Rect', obj.prScreenNumber) .* .25);
                obj.prFullscreen = false;
            else
                % fullscreen
                obj.prWindowSize = Screen('Rect', obj.prScreenNumber);
                obj.prFullscreen = true;
            end
                       
            % open screen
            obj.OpenScreen
            
            % default zoom to 100%
            obj.prDrawSize = obj.prWindowSize;
            obj.prDrawFocus = obj.prDrawSize(3:4) / 2;
            obj.Zoom = 1;
            
            obj.prStat.Status = '';
            
            if exist('data_in', 'var') && ~isempty(data_in)
                obj.Data = data_in;
                obj.StartInteractive
            end
        
        end
        
        % destructor
        function delete(obj)            
            
            % close open screen
            if obj.prScreenOpen
                obj.CloseScreen
            end
            
           % reset PTB prefs
            Screen('Preference', 'SkipSyncTests', obj.prPTBOldSyncTests);
            Screen('Preference', 'SuppressAllWarnings',...
                obj.prPTBOldWarningFlag);
            
        end
        
        % screen
        function OpenScreen(obj)
            if obj.prScreenOpen
                error('Screen already open.')
            end
            if obj.prFullscreen
                fullscreenFlag = [];
%                 rect = Screen('Rect', obj.ScreenNumber);
                rect = [];
            else
                rect = obj.prWindowSize;
%                 fullscreenFlag = kPsychGUIWindow;
                fullscreenFlag = [];
            end
            obj.prWinPtr = Screen('OpenWindow', obj.prScreenNumber,...
                obj.Col_BG, rect, [], [], [], 1, [], fullscreenFlag);
            Screen('BlendFunction', obj.prWinPtr, GL_SRC_ALPHA,...
                GL_ONE_MINUS_SRC_ALPHA);
            Screen('Preference', 'TextAlphaBlending', 1)
            Screen('TextFont', obj.prWinPtr, 'Consolas');
            obj.prScreenOpen = true;
        end
        
        function CloseScreen(obj)
            if ~obj.prScreenOpen
                error('Screen is not open.')
            end
            Screen('Close', obj.prWinPtr);
            obj.prScreenOpen = false;
        end
        
        function ReopenScreen(obj)
            if obj.prScreenOpen
                obj.CloseScreen
                obj.OpenScreen
                obj.PrepareForDrawing
                obj.Draw
            end
        end   
        
    end
    
end