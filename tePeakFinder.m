classdef tePeakFinder < handle
    
    properties
    end
    
    properties (SetAccess = private)
        PeakDefinition
        ERPVariableName
        DatabaseClient
        SelectedMetadata
        SelectedGUID
        SelectedData
        Path_Temp
    end
    
    properties (Dependent, SetAccess = private)
        NumComponents
        NumSubPlots
    end
    
    properties (Access = private)
        pos_figure
        pos_channels
        pos_table
        pos_inspector
        h_figure
        h_channels
        h_channels_subplots
        h_controls
        h_table
        h_inspector
        h_channelRating
        h_cmbRateAll
        h_cmbRateValues
        h_cmbRatings
        h_btnSetRating
        h_btnAutoFindPeaks
        h_btnSave
        wb
        prRatingAggregateLabels
        prRatingAggregateSubs
        prRatingAggregateValues
        prMetadataDirty = false
    end 
    
    properties (Constant)
        CONST_ratingOptions = {...
            'OK',...
            'Double peak',...
            'Peaks not clear',...
            'Other (needs checking)',...
            }
    end
    
    methods
        
        % constructor
        function obj = tePeakFinder(def, erpVarName, client, path_temp)
        % pass this method a peak definition to initiate the peak finder
        
        % check that the format of the peak def is valid
        
            % has been passed?
            if ~exist('def' , 'var') || isempty(def)
                error('Must pass a peak definition table as an input argument.')
            end
        
            % check peak def is valid
            [valid, reason] = obj.validatePeakDefinition(def);
            if ~valid
                error('Invalid peak definition: %s', reason)
            else
                obj.PeakDefinition = def;
            end
            
        % check the format of the ERP variable name
        
            % has it been passed?
            if ~exist('erpVarName', 'var') || isempty(erpVarName)
                error('Must pass an ERP variable name as the second input argument.')
            end
            
            % format
            if ~ischar(erpVarName)
                error('ERP variable name must be char.')
            end
            
            obj.ERPVariableName = erpVarName;
            
        % check that the database client is valid
        
            % has it been passed?
            if ~exist('client', 'var') 
                error('Must pass a teAnalysisClient instance as the third input argument.')
            end
            
            % is it connected
            if ~strcmpi(client.Status, 'connected')
                error('teAnalysisClient must be connected to a server.')
            end
            
            % if it empty
            if client.NumDatasets == 0
                error('teAnalysisClient must have some data (NumDatasets > 0).')
            end
            
            obj.DatabaseClient = client;
            
        % check that the temp folder is valid
        
            if ~exist('path_temp', 'var') || isempty(path_temp)
                error('Must pass a path to a temp folder as the fourth input argument.')
            end
            
            if ~exist(path_temp, 'dir')
                error('path_temp not found: %s', path_temp)
            end
            
            obj.Path_Temp = path_temp;
            
        % add amplitude and latency columns to peak def
        
            if ~ismember('amplitude',...
                    obj.PeakDefinition.Properties.VariableNames)
                obj.PeakDefinition.amplitude =...
                    nan(size(obj.PeakDefinition, 1), 1);
            end
            
            if ~ismember('latency',...
                    obj.PeakDefinition.Properties.VariableNames)
                obj.PeakDefinition.latency =...
                    nan(size(obj.PeakDefinition, 1), 1);
            end
            
        % draw UI
        
            obj.drawUI
            
        end
        
        % destructor
        function delete(obj)
            if ~isempty(obj.h_figure)
                delete(obj.h_figure)
            end
            
        end
        
        function AutoFindPeaks(obj, varargin)
            
            obj.busy('Finding peaks...');
            
            if isempty(obj.SelectedData)
                errordlg('No data selected')
                return
            end
            
            % loop through peak def and find all peaks for each row
            pd = table2struct(obj.PeakDefinition);
            for p = 1:size(pd, 1)
                
                % get ERP
                erp = obj.SelectedData.(pd(p).condition);

                % find peak
                [amp, lat] = eegFindPeak(erp, pd(p).window,...
                    pd(p).electrode, [], pd(p).polarity);
                
                % store in md
                md_lat = obj.buildLabel(p, 'lat');
                md_amp = obj.buildLabel(p, 'amp');
                obj.SelectedMetadata.erp_peaks.(md_lat) = lat;
                obj.SelectedMetadata.erp_peaks.(md_amp) = amp;
                
                % store windows in md
                win_width = pd(p).window(2) - pd(p).window(1);
                win_centre = pd(p).window(1) + (.5 * pd(p).window(2));
                obj.SelectedMetadata.erp_window_centre.(md_lat) =...
                    win_centre;
                obj.SelectedMetadata.erp_window_width.(md_lat) =...
                    win_width;
                
            end
            
            obj.drawChannels('position', obj.pos_channels);
            
            obj.notBusy
            
        end
        
        function ManualFindPeak(obj, src, ~)
            
            if ~isa(src, 'Axis')
                src = src.Parent;
            end
            
            % find index of button that was pressed
            idx = str2double(src.Tag);
            
            % get peak def
            pd = table2struct(obj.PeakDefinition(idx, :));
            
            % get x, y of click
            pt = get(src, 'CurrentPoint');
            x = pt(1, 1);
            y = pt(2, 1);
            
%             % colour selected subplot
%             set(obj.h_channels_subplots(idx), 'color', [1.0, 1.0, 0.9]);
            
%             % get x, y location of mouse
%             [x, ~] = ginput(1);
            
            obj.busy
            
            % get ERP
            erp = obj.SelectedData.(pd.condition);

            % get window width
            win_width = pd.window(2) - pd.window(1);

            % define new window 
            win_edges = [x - (win_width / 2), x + (win_width / 2)];

            % find peak
            [amp, lat] = eegFindPeak(erp, win_edges,...
                pd.electrode, [], pd.polarity);

            % store in md
            md_lat = obj.buildLabel(idx, 'lat');
            md_amp = obj.buildLabel(idx, 'amp');
            obj.SelectedMetadata.erp_peaks.(md_lat) = lat;
            obj.SelectedMetadata.erp_peaks.(md_amp) = amp;

            % store windows in md
            win_width = pd.window(2) - pd.window(1);
            win_centre = pd.window(1) + (.5 * pd.window(2));
            obj.SelectedMetadata.erp_window_centre.(md_lat) =...
                win_centre;
            obj.SelectedMetadata.erp_window_width.(md_lat) =...
                win_width;     
                        
            % restore colour
            set(obj.h_channels_subplots(idx), 'color', [1.0, 1.0, 1.0]);
            
            obj.drawChannels('position', obj.pos_channels);
            
            obj.notBusy           
            
        end
        
        % get / set
        function val = get.NumComponents(obj)
            val = size(obj.PeakDefinition, 1);
        end
        
        function val = get.NumSubPlots(obj)
            val = numSubplots(obj.NumComponents);
        end
        
        function set.SelectedMetadata(obj, val)
            obj.prMetadataDirty = true;
            obj.SelectedMetadata = val;
        end
        
        function set.SelectedData(obj, val)
            obj.prMetadataDirty = true;
            obj.SelectedData = val;
        end
        
    end
    
    methods %(Access = private)
        
        function [valid, reason] = validatePeakDefinition(~, def)

            valid = true;
            reason = '';
            
            % must be table
            valid = valid && istable(def);
            if ~valid
                reason = 'Peak definition must be a table.';
                return
            end
            
            % define expected table vars
            expectedTableVars = {'component', 'electrode', 'hemi',...
                'window', 'condition', 'polarity'};
            valid = valid && isequal(def.Properties.VariableNames,...
                expectedTableVars);
            if ~valid
                reason = 'Invalid table format: variables must be:';
                reason = [reason, sprintf(' %s', expectedTableVars{:})];
                return
            end
            
            % column data formats
            expectedColFormats = {@iscellstr, @iscellstr, @iscellstr,...
                @isnumeric, @iscellstr, @iscellstr};
            validColFormats = false(size(expectedColFormats));
            for c = 1:length(def.Properties.VariableNames)
                validColFormats(c) = feval(expectedColFormats{c}, def{:, c});
            end
            valid = valid && all(validColFormats);
            if ~valid
                % convert function handles to string
                expectedColFormatsStr =...
                    cellfun(@func2str, expectedColFormats, 'uniform', false);
                reason = 'Invalid table format';
                return
            end        
            
        end
        
        function drawUI(obj)
            
            obj.busy('Setting up...')
            
            % make figure window if doesn't already exist
            if isempty(obj.h_figure)
                obj.h_figure = figure(...
                    'MenuBar', 'none',...
                    'ToolBar', 'none',...
                    'Name', 'Peak Finder',...
                    'Units', 'normalized',...
                    'Visible', 'off');
            end
            
            obj.pos_channels    = [0.0, 0.3, 1.0, 0.7];
            obj.pos_table       = [0.0, 0.0, 0.6, 0.3];
            obj.pos_inspector   = [0.6, 0.0, 0.4, 0.3];
            
%             obj.drawControls;
            obj.drawChannels('position', obj.pos_channels);
            obj.drawTable('position', obj.pos_table,...
                'CellSelectionCallback', @obj.selectionChanged);
            obj.drawInspector('position', obj.pos_inspector);
            
            obj.h_figure.Visible = 'on';
            obj.notBusy
            
        end
        
        function drawChannels(obj, varargin)
            
            % delete old panel (if exists)
            obj.deleteUIChildren(obj.h_channels);
            
            % create panel
            obj.h_channels = uipanel(...
                'BorderType', 'line',...
                'Units', 'normalized',...
                'Parent', obj.h_figure,...
                'visible', 'on',...
                varargin{:});
            
            if obj.NumComponents == 0 || isempty(obj.SelectedData)
                uicontrol('Style', 'text',...
                    'parent', obj.h_channels,...
                    'Units', 'normalized',...
                    'Position', [0, 0, 1, 1],...
                    'String', 'No data selected');
                return
            end

            % get metdata
            md = obj.SelectedMetadata;
            mds = md.Struct;
            
            % get titles
            str = cell(size(obj.PeakDefinition, 1), 1);
            pd = table2struct(obj.PeakDefinition);
            for r = 1:size(obj.PeakDefinition, 1)
                str{r} = sprintf('%s_%s_%s_%s',...
                    pd(r).component,...
                    pd(r).electrode,...
                    pd(r).hemi,...
                    pd(r).condition...
                    );
            end
            cols = colourHeaders(str);
            
            % draw subplots
            nsp = obj.NumSubPlots;
            for c = 1:obj.NumComponents
                
            % subplot
            
                h_sp =...
                    subplot(nsp(1), nsp(2), c,...
                        'parent', obj.h_channels,...
                        'ButtonDownFcn', @obj.ManualFindPeak,...
                        'tag', num2str(c),...
                        'units', 'normalized');
                
                % reduce height of subplot to make room for review dropdown
                h_red = h_sp.Position(4) * .2;
                h_sp.Position(4) = h_sp.Position(4) - h_red;
                obj.h_channels_subplots(c) = h_sp;
                
            % get data
                
                % find appropriate time series
                pd = table2struct(obj.PeakDefinition(c, :));
                erp = obj.SelectedData.(pd.condition);
                
                % find channel index
                idx_ch = find(strcmpi(erp.label, pd.electrode), 1);
                if isempty(idx_ch)
                    errordlg(sprintf('Channel %s not found in ERP data.',...
                        pd.electrode));
                    return
                end
                
                % get time series
                dat = erp.avg(idx_ch, :);
                
            % plot
            
                pl = plot(erp.time, dat,...
                    'ButtonDownFcn', @obj.ManualFindPeak,...
                    'tag', num2str(c),...
                    'parent', obj.h_channels_subplots(c));
                
                % tag axis
                h_ax = get(pl, 'parent');
                set(h_ax, 'tag', num2str(c))
                
                % title
                title(str{c},...
                    'interpreter', 'none',...
                    'parent', obj.h_channels_subplots(c)...
                );
                
            % draw peak
                
                md_lat = sprintf('erp_peaks_%s_%s_lat_%s',...
                    pd.condition, pd.component, pd.electrode);
                md_amp = sprintf('erp_peaks_%s_%s_amp_%s',...
                    pd.condition, pd.component, pd.electrode);
                
                hold(obj.h_channels_subplots(c), 'on')
                if isfield(mds, md_lat) && isfield(mds, md_amp)
                    scatter(mds.(md_lat), mds.(md_amp), 60, 'd',...
                        'parent', obj.h_channels_subplots(c),...
                        'MarkerFaceColor', 'r')
                end 
                
            % make review dropdown
            
                % poll metadata for existing value
                lab = obj.buildLabel(c);
                if isprop(md, 'peakrating') && isfield(md.peakrating, lab)
                    % get rating from metadata
                    rating = md.peakrating.(lab);
                    % check rating is one of the allowable options
                    if ~ismember(rating, obj.CONST_ratingOptions)
                        warning('Could not set rating to %s from metadata because it is not a valid rating.',...
                            rating)
                        rating = obj.CONST_ratingOptions{1};
                    end
                else
                    % no existing rating in the metadata. Default rating is
                    % 'OK' so we will set this on the control, and will
                    % update the metadata with this value
                    rating = obj.CONST_ratingOptions{1};
                    md.peakrating.(lab) = rating;
                end
                
                % convert string rating to idx
                idx_rating = find(strcmpi(obj.CONST_ratingOptions, rating));
                    
                pos_sp = get(obj.h_channels_subplots(c), 'position');
                
                pos_rev = [...
                    pos_sp(1),...
                    pos_sp(2) - h_red - .01,...
                    pos_sp(3),...
                    h_red];
                obj.h_channelRating(c) = uicontrol('Style', 'popupmenu',...
                    'parent', obj.h_channels,...
                    'string', obj.CONST_ratingOptions,...
                    'Value', idx_rating,...
                    'Units', 'normalized',...
                    'Position', pos_rev,...
                    'tag', num2str(c),...
                    'Callback', @obj.changePeakRating);    
                
                set(h_ax, 'XTick', min(xlim(h_ax)):.1:max(xlim(h_ax)))
                set(h_ax, 'xgrid', 'on')
                set(h_ax, 'XTickLabel', [])          
                line([0, 0], [min(ylim(h_ax)), max(ylim(h_ax))],...
                    'parent', obj.h_channels_subplots(c),...
                    'color', 'k')

            end 
            
        % make rating controls
                
            % get handle to top-left (first) subplot
            h_sp = obj.h_channels_subplots(1);

            % these controls go at the top of the subplot matrix, above the
            % first subplot. Find the top
            pos_sp = get(h_sp, 'position');
            
            % set width of both combos and button
            w_combo = 1 / 8;
            w_btn = w_combo;
            
            % set height
            h_control = pos_sp(4) / 4;
            
            y_top = 1 - h_control;
            x_left = pos_sp(1);    
            
            pos_cmbRateAll = [...
                x_left + (0 * w_combo),...
                y_top,...
                w_combo,...
                h_control];
            
            pos_cmbRateValues = [...
                x_left + (1 * w_combo),...
                y_top,...
                w_combo,...
                h_control];            
            
            pos_cmbRatings = [...
                x_left + (2 * w_combo),...
                y_top,...
                w_combo,...
                h_control];     
            
            pos_btnSetRating = [...
                x_left + (3 * w_combo),...
                y_top,...
                w_btn,...
                h_control];   
            
            pos_btnAutoFindPeaks = [...
                x_left + (4 * w_combo),...
                y_top,...
                w_btn,...
                h_control];   
            
            pos_btnSave = [...
                x_left + (5 * w_combo),...
                y_top,...
                w_btn,...
                h_control];               
            
            obj.h_cmbRateValues = uicontrol('style', 'popupmenu',...
                'parent', obj.h_channels,...
                'units', 'normalized',...
                'position', pos_cmbRateValues,...
                'Callback', @obj.cmbRateAll_Select,...
                'String', 'Loading...');
            
            obj.h_cmbRateAll = uicontrol('Style', 'popupmenu',...
                'parent', obj.h_channels,...
                'units', 'normalized',...
                'position', pos_cmbRateAll,...
                'Callback', @obj.cmbRateAll_Select,...
                'String', obj.prRatingAggregateLabels);
            
            obj.h_cmbRatings = uicontrol('style', 'popupmenu',...
                'parent', obj.h_channels,...
                'units', 'normalized',...
                'position', pos_cmbRatings,...
                'String', obj.CONST_ratingOptions);
            
            obj.h_btnSetRating = uicontrol('Style', 'pushbutton',...
                'parent', obj.h_channels,...
                'units', 'normalized',...
                'position', pos_btnSetRating,...
                'Callback', @obj.btnSetRating,...
                'String', 'Set Rating');
            
            obj.h_btnAutoFindPeaks = uicontrol('Style', 'pushbutton',...
                'parent', obj.h_channels,...
                'units', 'normalized',...
                'position', pos_btnAutoFindPeaks,...
                'Callback', @obj.AutoFindPeaks,...
                'String', 'Auto Find Peaks');            
            
            obj.h_btnSave = uicontrol('Style', 'pushbutton',...
                'parent', obj.h_channels,...
                'units', 'normalized',...
                'position', pos_btnSave,...
                'Callback', @obj.saveMetadata,...
                'String', 'Save');            
            
        end
        
        function drawTable(obj, varargin)
            
            obj.h_table = uitable(...
                obj.DatabaseClient,...
                'Units', 'normalized',...
                'parent', obj.h_figure,...
                varargin{:});
            
        end
        
        function drawInspector(obj, varargin)
            
            % delete old panel (if exists)
            obj.deleteUIChildren(obj.h_inspector);
            
            if ~isempty(obj.SelectedMetadata)
                
                delete(obj.h_inspector);
                obj.h_inspector = uitable(obj.SelectedMetadata,...
                    'units', 'normalized',...
                    'parent', obj.h_figure,...
                    varargin{:});
                
            else
                
                uicontrol('Style', 'text',...
                    'parent', obj.h_figure,...
                    'Units', 'normalized',...
                    'String', 'No data selected',...
                    varargin{:});
                
            end
            
        end
        
        function deleteUIChildren(~, h)
            if ~isempty(h) && isvalid(h)
                h_child = get(h, 'children');
                delete(h_child);
                delete(h)
            end
        end
        
        function selectionChanged(obj, ~, h)
            
            % check for dirty data
            if obj.prMetadataDirty
                resp = questdlg('Metadata has changed. Save to database before continuing?',...
                    'Metadata has changed', 'Save', 'Don''t Save', 'Save');
                if isequal(resp, 'Save')
                    obj.saveMetadata
                end
            end
            
            obj.busy('Querying database...')
            
            % get GUID from table
            if ~isempty(h.Indices)
                idx = h.Indices(1);
            else
                return
            end
            
            obj.SelectedGUID = obj.h_table.Data{idx, 1};
            obj.SelectedMetadata = obj.DatabaseClient.GetMetadata(...
                'GUID', obj.SelectedGUID);
            
            % get data
            if obj.getData
            
                % if successful, draw channels
                obj.buildRatingAggregateLabels
                obj.drawChannels('position', obj.pos_channels);
                
            end
            
            obj.drawInspector('position', obj.pos_inspector);
            
            obj.notBusy
            
        end
        
        function cmbRateAll_Select(obj, src, ~)
            
            idx = src.Value;
           
            % set the values combo
            set(obj.h_cmbRateValues, 'value', 1);
            set(obj.h_cmbRateValues, 'string',...
                obj.prRatingAggregateValues{idx});
            
        end    
        
        function btnSetRating(obj, ~, ~)
            
            % get idx of selected elements
            idx_element = get(obj.h_cmbRateAll, 'value');
            
            % get subscripts of peaks to apply this to
            subs = obj.prRatingAggregateSubs{idx_element};
            
            % form index for selected value
            idx = find(subs == get(obj.h_cmbRateValues, 'value'));
            
            % get selected rating to apply
            rating_idx = get(obj.h_cmbRatings, 'value');
            ratings = get(obj.h_cmbRatings, 'string');
            rating = ratings{rating_idx};
            
            % apply 
            for i = 1:length(idx)
                obj.changeOnePeakRating(idx(i), rating)
                set(obj.h_channelRating(idx(i)), 'Value', rating_idx)
            end
   
        end
        
        function suc = getData(obj)
            
            suc = false;
            
            % get data
            if ~isempty(obj.SelectedGUID)
                
                obj.wb = waitbar(0, obj.wb, 'Loading ERP data...');
                obj.SelectedData = obj.DatabaseClient.GetVariable(...
                    obj.ERPVariableName, 'GUID', obj.SelectedGUID);
                
                % check data was returned
                if isempty(obj.SelectedData)
                   errordlg(sprintf(...
                       'No data returned from database for GUID: %s',...
                       obj.SelectedGUID))
                   return
                end
                
                % check that ERP fields are present
                if ~isstruct(obj.SelectedData)
                   errordlg('Incorrect ERP data format - not a struct')
                   return
                end               
                
                % remove summary field (if present)
                obj.SelectedData = rmfield(obj.SelectedData, 'summary');
                
                % check that all conditions in the peak def are present as
                % fields in the ERP struct
                expectedFields = unique(obj.PeakDefinition.condition);
                if ~all(ismember(fieldnames(obj.SelectedData), expectedFields))
                    errordlg('Not all conditions present in ERP data.');
                    return
                end
                
                % todo - should prob check that all data types are ERP here
                
                
                % data is currently clean
                obj.prMetadataDirty = false;
                
                suc = true;
                
            else
                
                % no data selected, return
                return
                
            end
            
        end
        
        function suc = saveMetadata(obj)
            
            obj.busy('Saving metadata to database...')
            
            if isempty(obj.SelectedMetadata)
                suc = false;
                return
            end
            
            % save to temp folder
            md = obj.SelectedMetadata;
            file_temp = sprintf('%s.mat', md.GUID);
            path_temp = fullfile(obj.Path_Temp, file_temp);
            save(path_temp, 'md');
            
            % update database
            [suc, err] =...
                obj.DatabaseClient.ServerUpdate(md);
            if ~suc
                errordlg(sprintf('Error updating metadata: %s', err));
                return
            end
            
            obj.notBusy
            
        end
        
        function buildRatingAggregateLabels(obj)
            
            if isempty(obj.SelectedData)
                obj.prRatingAggregateLabels = {};
                obj.prRatingAggregateValues = {};
                obj.prRatingAggregateSubs = {};
                return
            end
            
            pd = obj.PeakDefinition;
            
            % all
            obj.prRatingAggregateLabels{1} = 'all peaks';
            obj.prRatingAggregateValues{1} = 'no values';
            obj.prRatingAggregateSubs{1} = ones(size(pd, 1), 1);
            
            % by electrode
            obj.prRatingAggregateLabels{2} = 'by electrode';
            [elec_u, ~, elec_s] = unique(pd.electrode);
            obj.prRatingAggregateValues{2} = elec_u;
            obj.prRatingAggregateSubs{2} = elec_s;
            
            % by component
            obj.prRatingAggregateLabels{3} = 'by component';
            [comp_u, ~, comp_s] = unique(pd.component);
            obj.prRatingAggregateValues{3} = comp_u;
            obj.prRatingAggregateSubs{3} = comp_s;
            
            % by hemi
            obj.prRatingAggregateLabels{4} = 'by hemi';
            [hemi_u, ~, hemi_s] = unique(pd.hemi);
            obj.prRatingAggregateValues{4} = hemi_u;
            obj.prRatingAggregateSubs{4} = hemi_s;
            
            % by condition
            obj.prRatingAggregateLabels{5} = 'by condition';
            [cond_u, ~, cond_s] = unique(pd.condition);
            obj.prRatingAggregateValues{5} = cond_u;
            obj.prRatingAggregateSubs{5} = cond_s;
            
        end 
        
        function val = buildLabel(obj, idx, label)
            
            pd = table2struct(obj.PeakDefinition(idx, :));
            if ~exist('label', 'var') || isempty(label)
                val = sprintf('%s_%s_%s',...
                    pd.condition, pd.component, pd.electrode);
            else
                val = sprintf('%s_%s_%s_%s',...
                    pd.condition, pd.component, label, pd.electrode);
            end
            
        end
        
        function changePeakRating(obj, src, ~)
            
            if isempty(obj.SelectedMetadata)
                return
            else
                idx = str2double(src.Tag);
                obj.changeOnePeakRating(idx, src.String{src.Value})
            end
            
        end
        
        function changeOnePeakRating(obj, idx, val)
            lab = obj.buildLabel(idx, '');
            obj.SelectedMetadata.peakrating.(lab) = val;
        end
        
        function busy(obj, msg)
            set(obj.h_figure, 'pointer', 'watch');
            set(obj.h_table, 'enable', 'off')
            if ~isempty(obj.h_inspector) && isvalid(obj.h_inspector)
                set(obj.h_inspector, 'enable', 'off')
            end
            if exist('msg', 'var'), obj.wb = waitbar(0, msg); end
            drawnow
        end

        function notBusy(obj)
            set(obj.h_figure, 'pointer', 'arrow')
            set(obj.h_table, 'enable', 'on')
            if ~isempty(obj.h_inspector) && isvalid(obj.h_inspector)
                set(obj.h_inspector, 'enable', 'on')
            end
            if ishandle(obj.wb), delete(obj.wb), end
            drawnow
        end 
    
    end
    
end
        