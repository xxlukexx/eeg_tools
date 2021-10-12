function ECKEEGPeakFinder(path_avg, path_clean, res)

    %% data
    
    if ~exist('path_avg', 'var') || ~exist(path_avg, 'file')
        error('Invalid path.')
    end
    
    % load results if not passed as an argument
    if ~exist('res', 'var') || isempty(res) 
        path_res = fullfile(path_avg, '_results.mat');
        if ~exist(path_res, 'file')
            error('Cannot find _results.mat.')
        else
            tmp = load(path_res);
            res = tmp.res;        
        end
    end
    
    % populate peak valid vector (or create new if necessary)
    if ~strcmpi(res.Properties.VariableNames, 'PeakValid')
        valid = ones(size(res, 1), 1);    
        res = [res, table(valid, 'variablenames', {'PeakValid'})];
    else
        valid = res.PeakValid;
    end
    
    cond = {};
    sel = 1;
    selPlot = [];
    sp = [];
    data = [];
    canDraw = false;
    wb = [];
    windowP1 = [];
    windowN1 = [];
%     ord = [randperm(4), 4 + randperm(4)];
    
    %% UI
    
    % if a parent handle (to e.g. figure, panel etc.) has not been
    % supplied, make a figure
    if ~exist('hParent', 'var') || isempty(hParent)
        figPos = [0.00, 0.50, 1.00, 0.50];
        fig = figure(...
                'NumberTitle',          'off',...
                'Units',                'normalized',...
                'Position',             figPos,...
                'Menubar',              'none',...
                'Toolbar',              'none',...
                'Name',                 'EEG Peak Finder',...
                'DeleteFcn',            @figDelete,...
                'renderer',             'opengl');
    else
        fig = hParent;
    end
    
    % main panel positions
    posLstDatasets =                    [0.00, 0.10, 0.15, 0.90];
    posERP =                            [0.15, 0.10, 0.85, 0.90];
    posControls =                       [0.00, 0.00, 1.00, 0.10];
    
    % control positions
    btnW =                              0.10;
    posBtnValid =                       [0.00, 0.00, btnW, 1.00]; 
    posBtnFindPeaks =                   [btnW, 0.00, btnW, 1.00];
    posBtnSetAllP1 =                    [btnW * 2, 0.00, btnW, 1.00];
    posBtnSetAllN1 =                    [btnW * 3, 0.00, btnW, 1.00];
    posBtnSetEachN1 =                   [btnW * 4, 0.00, btnW, 1.00];
    posBtnSetEachP1 =                   [btnW * 5, 0.00, btnW, 1.00];
    posBtnVisualiser =                  [btnW * 6, 0.00, btnW, 1.00];
    posBtnReAvg =                       [btnW * 7, 0.00, btnW, 1.00];

    lstDatasets = uicontrol(...
                'Style',                'listbox',...
                'String',               res.avg_FileOut,...
                'units',                'normalized',...
                'Position',             posLstDatasets,...
                'Callback',             @lstDatasets_Select);
            
    pnlERP = uipanel(...
                'parent',               fig,...
                'units',                'normalized',...
                'position',             posERP,...
                'buttondownfcn',        @erp_click);
            
    pnlControls = uipanel(...
                'parent',               fig,...
                'units',                'normalized',...
                'position',             posControls);
            
    btnValid = uicontrol(...
                'parent',               pnlControls,...
                'units',                'normalized',...
                'position',             posBtnValid,...
                'style',                'pushbutton',...
                'string',               'Unchecked',...
                'callback',             @btnValid_Click);
            
    btnFindPeaks = uicontrol(...
                'parent',               pnlControls,...
                'units',                'normalized',...
                'position',             posBtnFindPeaks,...
                'style',                'pushbutton',...
                'string',               'Find Peaks',...
                'callback',             @btnFindPeaks_Click);
            
    btnSetAllP1 = uicontrol(...
                'parent',               pnlControls,...
                'units',                'normalized',...
                'position',             posBtnSetAllP1,...
                'style',                'pushbutton',...
                'string',               'Set All P1 Windows',...
                'callback',             @btnSetAllP1_Click);
            
    btnSetAllN1 = uicontrol(...
                'parent',               pnlControls,...
                'units',                'normalized',...
                'position',             posBtnSetAllN1,...
                'style',                'pushbutton',...
                'string',               'Set All N1 Windows',...
                'callback',             @btnSetAllN1_Click);
            
    btnSetEachN1 = uicontrol(...
                'parent',               pnlControls,...
                'units',                'normalized',...
                'position',             posBtnSetEachN1,...
                'style',                'pushbutton',...
                'string',               'Set Each N1 Window',...
                'callback',             @btnSetEachN1_Click);
            
    btnSetEachP1 = uicontrol(...
                'parent',               pnlControls,...
                'units',                'normalized',...
                'position',             posBtnSetEachP1,...
                'style',                'pushbutton',...
                'string',               'Set Each P1 Window',...
                'callback',             @btnSetEachP1_Click);
            
    btnVisualiser = uicontrol(...
                'parent',               pnlControls,...
                'units',                'normalized',...
                'position',             posBtnVisualiser,...
                'style',                'pushbutton',...
                'string',               'Start Visualiser',...
                'callback',             @btnVisualiser_Click);
            
    btnReAvg = uicontrol(...
                'parent',               pnlControls,...
                'units',                'normalized',...
                'position',             posBtnReAvg,...
                'style',                'pushbutton',...
                'string',               'Re-Average',...
                'callback',             @btnReAvg_Click);
            
    %% data
            
    function loadData
        
        if isempty(sel), return, end
        
        % load
        dataPath = res(sel, :).avg_PathOut{:};
        dataFile = res(sel, :).avg_FileOut{:};
        tmp = load([path_avg, filesep, dataFile]);
        cond = fieldnames(tmp.erps);
        unwantedIdx = strcmpi(cond, 'summary');
        cond(unwantedIdx) = [];
        data = tmp.erps;
        btnValid_UpdateState
        canDraw = true;
        
%         ord = [randperm(4), 4 + randperm(4)];
        
    end

    function saveData
        
        if isempty(data), return, end
        
        dataFile = res(sel, :).avg_FileOut{:};
        erps = data;
        save([path_avg, filesep, dataFile], 'erps');
        
    end

    function saveValidTemp
        
        tmp = valid;
%         res.PeakValid = valid;
        filename = [tempdir, 'ECKEEGAverageReview_tempValid.mat'];
        save(filename, 'valid')
        
    end

    %% display

    function drawPlots(plotIdx)
        if ~canDraw, return; end
                
        chans = {'P7', 'P7', 'P8', 'P8', 'O1', 'O1', 'O2', 'O2'};
        conds = repmat(cond, 1, 4);
        
        if ~exist('plotIdx', 'var') || isempty(plotIdx)
            
            delete(get(pnlERP, 'children'))
            for p = 1:8
                sp(p) = subplot(2, 4, p, 'parent', pnlERP);
                drawERP(chans{p}, conds{p})
            end
            
        else
            
            sp(plotIdx) = subplot(2, 4, plotIdx, 'parent', pnlERP);
            drawERP(chans{plotIdx}, conds{plotIdx})
            
        end    
            
        notBusy
                
    end

    function drawERP(chan, cond, ampMin, ampMax)
        
        ch = find(strcmpi(data.(cond).label, chan));
        
        plot(data.(cond).time, data.(cond).avg(ch, :), 'k',...
            'linewidth', 1, 'ButtonDownFcn', @erp_click);
        hold on
        set(gca, 'xgrid', 'on')
        set(gca, 'xminorgrid', 'on')
        title(sprintf('%s | %s', chan, cond))
                
        % peaks P7
        if isfield(data.(cond), 'peaklabel')
            % P1
            x = data.(cond).peakloc(ch, 1);
            y = data.(cond).peakamp(ch, 1);
            sc = scatter(x, y, 75, 'dk', 'ButtonDownFcn', @erp_click);
            sc.LineWidth = 2;
            sc.MarkerFaceColor = 'y';
            % N1
            x = data.(cond).peakloc(ch, 2);
            y = data.(cond).peakamp(ch, 2);
            sc = scatter(x, y, 75, 'dk', 'ButtonDownFcn', @erp_click);
            sc.LineWidth = 2;
            sc.MarkerFaceColor = 'r';      
        end
                
    end

    function busy(msg)
        set(gcf, 'pointer', 'watch');
        if exist('msg', 'var'), wb = waitbar(0, msg); end
        drawnow
    end

    function notBusy
        set(gcf, 'pointer', 'arrow')
        if ishandle(wb), close(wb), end
        drawnow
    end 

    function btnValid_UpdateState
        switch valid(sel)
            case 0
                % invalid
                set(btnValid, 'BackgroundColor', [1.00, 0.60, 0.60]);
                set(btnValid, 'String', 'Bad');
            case 1
                % unchecked
                set(btnValid, 'BackgroundColor', [0.94, 0.94, 0.94]);
                set(btnValid, 'String', 'Unchecked');
            case 2
                % good
                set(btnValid, 'BackgroundColor', [0.60, 1.00, 0.60]);
                set(btnValid, 'String', 'Good');
        end
    end

    %% callbacks
    
    function figDelete(~, ~)
%         if ~any(strcmpi(res.Properties.VariableNames, 'PeakValid'))
%             res = [res, table(valid, 'variablenames', {'PeakValid'})];
%         else
%             res.PeakValid = valid;
%         end
        filename = fullfile(pwd, ['_peaks_', datetimeStr, '.mat']);
        save(filename, 'res');
        fprintf('<strong>Saved updated results to:</strong> \n\t%s\n',...
            filename)
    end

    function lstDatasets_Select(h, dat)
        busy
        sel = h.Value;
        if ~res.avgValid(sel)
            errordlg('Average was not valid for this dataset')
            notBusy
            return
        end
        loadData
        drawPlots
    end

    function btnValid_Click(~, ~)
        state = valid(sel);
        state = state + 1;
        if state > 2, state = 0; end
        valid(sel) = state;
        res.PeakValid(sel) = state;
        btnValid_UpdateState
        saveValidTemp
    end

    function btnFindPeaks_Click(~, ~)
        busy
        data = LEAP_EEG_faces_findPeaks(data);
        saveData
        drawPlots
        notBusy
    end

    function erp_click(h, dat)
       disp('')
    end

    function btnSetAllP1_Click(~, ~)
        [windowP1, ~] = ginput(1);        
        busy
        data = LEAP_EEG_faces_findPeaks(data, windowN1, windowP1, 0.025);
        saveData
        drawPlots
        notBusy
    end

    function btnSetAllN1_Click(~, ~)        
        [windowN1, ~] = ginput(1);        
        busy
        data = LEAP_EEG_faces_findPeaks(data, windowN1, windowP1, 0.025);
        saveData
        drawPlots
        notBusy
    end

    function btnSetEachN1_Click(~, ~)
        
        for p = 1:4
            oCol = get(sp(p), 'color');
            set(sp(p), 'Color', [1, 1, 0]);
            [loc, ~] = ginput(1);  
%             tmpData = LEAP_EEG_faces_findPeaks(...
%                 data, tmpN1, windowP1, 0.025);
            
            label = 'N170';
            switch p
                case 1  % P7 FU
                    chan = 'P7';
                    erp = 'face_up';
                case 2  % P7 FI
                    chan = 'P7';
                    erp = 'face_inv';
                case 3  % P8 FU
                    chan = 'P8';
                    erp = 'face_up';
                case 4  % P8 FI
                    chan = 'P8';
                    erp = 'face_inv';
            end
%             [amp, loc] = eegRetrievePeak(tmpData.(erp), label, chan);
            chIdx = find(strcmpi(data.(erp).label, chan));
            locIdx = find(data.(erp).time >= loc, 1, 'first');
            amp = data.(erp).avg(chIdx, locIdx);
            data.(erp) = eegStorePeak(data.(erp), label, chan, amp, loc);
            
            drawPlots(p)
            set(sp(p), 'Color', oCol);
        end
        
        saveData
        drawPlots
        
    end

    function btnSetEachP1_Click(~, ~)
        
        for p = 1:8
            oCol = get(sp(p), 'color');
            set(sp(p), 'Color', [1, 1, 0]);
            [tmpP1, ~] = ginput(1);  
            tmpData = LEAP_EEG_faces_findPeaks(...
                data, windowN1, tmpP1, 0.025);
            
            label = 'P1';
            switch p
                case 1  % P7 FU
                    chan = 'P7';
                    erp = 'face_up';
                case 2  % P7 FI
                    chan = 'P7';
                    erp = 'face_inv';
                case 3  % P8 FU
                    chan = 'P8';
                    erp = 'face_up';
                case 4  % P8 FI
                    chan = 'P8';
                    erp = 'face_inv';
                case 5  % O1 FU
                    chan = 'O1';
                    erp = 'face_up';
                case 6  % O1 FI
                    chan = 'O1';
                    erp = 'face_inv';
                case 7  % O2 FU
                    chan = 'O2';
                    erp = 'face_up';
                case 8  % O2 FI
                    chan = 'O2';
                    erp = 'face_inv';
            end
            [amp, loc] = eegRetrievePeak(tmpData.(erp), label, chan);
            data.(erp) = eegStorePeak(data.(erp), label, chan, amp, loc);
            
            drawPlots(p)
            set(sp(p), 'Color', oCol);
        end
        
        saveData
        drawPlots
        
    end

    function btnVisualiser_Click(~, ~)
        clear eegv
        eegv = ECKEEGVis;
        filename = fullfile(path_clean, res.clean_FileOut{sel});
        tmpClean = load(filename);
        art = tmpClean.data.art;
        eegv.Data = tmpClean.data;
        eegv.AutoSetTrialYLim = false;
        eegv.WindowSize = [0, 0, 1600, 900];
        eegv.YLim = [-90, 90];
        eegv.StartInteractive;
        if ~isequal(art, eegv.Data.art)
            eegv.Data = LEAP_EEG_faces_interpManualArtefacts(eegv.Data);
            parsave(filename, eegv.Data)
        end
    end

    function btnReAvg_Click(~, ~)
        busy
        LEAP_EEG_faces_avgOne(res.clean_FileOut{sel})
        loadData
        drawPlots
        notBusy
    end

end
