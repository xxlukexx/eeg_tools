function [tab_stats, fig_erp, fig_bp_lat, fig_bp_amp, fig_hist_amp, res_t] =...
    eegPlotFactorialGA2(tab, component, varargin)

    set(groot, 'defaultAxesTickLabelInterpreter','none')
    set(groot, 'defaultLegendInterpreter','none');
    set(groot, 'defaulttextInterpreter', 'none');

    parser      =   inputParser;
    checkField  =   @(x) any(strcmpi(tab.Properties.VariableNames, x)   );
    addRequired(    parser, 'tab',                              @istable        )
    addRequired(    parser, 'comp',                     @ischar         )
    addParameter(   parser, 'compare',              []                          )
    addParameter(   parser, 'rows',                 [],         checkField      )
    addParameter(   parser, 'cols',                 [],         checkField      )
    addParameter(   parser, 'filt',                 [],         checkField      )
    addParameter(   parser, 'name',                 'Average',  @ischar         )
    addParameter(   parser, 'plotSEM',              true,       @islogical      )
    addParameter(   parser, 'SEMAlpha',             .1,         @isnumeric      )
    addParameter(   parser, 'colMap',               @lines                      )
    addParameter(   parser, 'linewidth',            1.5,        @isnumeric      )
    addParameter(   parser, 'fontsize',             10,         @isnumeric      )
    addParameter(   parser, 'mawidth',              .040,       @isnumeric      )    
    addParameter(   parser, 'plotERO',              false,      @islogical      )
    addParameter(   parser, 'plotBoxplot',          false,      @islogical      )
    addParameter(   parser, 'plotBack2BackHist',    false,      @islogical      )
    addParameter(   parser, 'plotHist',             false,      @islogical      )
    addParameter(   parser, 'makeTable',            false,      @islogical      )
    addParameter(   parser, 'fig',                  [],         @ishandle       )
    addParameter(   parser, 'legend',               true,       @islogical      )
    addParameter(   parser, 'ttest',                false,      @islogical      )
    addParameter(   parser, 'detrend',              false,      @islogical      )
    addParameter(   parser, 'colOrder',             [],         @islogical      )
    addParameter(   parser, 'rowOrder',             [],         @islogical      )
    parse(          parser, tab, component, varargin{:});
    tab         =   parser.Results.tab;
    component   =   parser.Results.comp;
    compare     =   parser.Results.compare;
    rows        =   parser.Results.rows;
    rowOrder    =   parser.Results.rowOrder;
    cols        =   parser.Results.cols;
    colOrder    =   parser.Results.colOrder;
    filt        =   parser.Results.filt;
    name        =   parser.Results.name;
    plotSEM     =   parser.Results.plotSEM;
    SEMAlpha    =   parser.Results.SEMAlpha;
    colMap      =   parser.Results.colMap;
    linewidth   =   parser.Results.linewidth;
    fontsize    =   parser.Results.fontsize;
    mawidth     =   parser.Results.mawidth;
    plotERO     =   parser.Results.plotERO;
    plotBoxPlot =   parser.Results.plotBoxplot;
    plotB2BHist =   parser.Results.plotBack2BackHist;
    plotHist    =   parser.Results.plotHist;
    fig_erp     =   parser.Results.fig;
    showLegend  =   parser.Results.legend;
    doTTest     =   parser.Results.ttest;
    doDeTrend   =   parser.Results.detrend;
    doTable     =   parser.Results.makeTable;
    
    % axes line width is one thinner than line width
    axLineWidth = linewidth - 1;
    if axLineWidth < 1, axLineWidth = 1; end
    
    % get channel index
    compIdx = strcmpi(tab.comp, component);
    if ~any(compIdx), error('Component not found.'); end
    tab = tab(compIdx, :);
    
    numData = size(tab, 1);
    
    % set up values of compare var
    if isempty(compare)
        comp_u = 'NONE';
        comp_s = ones(numData, 1);
        numComp = 1;
    else
        if iscell(compare)
            numVars = length(compare);
            vComp = cell(size(tab, 1), numVars);
            for v = 1:numVars
                vComp(:, v) = tab.(compare{v});
            end
            compVals = strcat(vComp(:, 1), '|', vComp(:, 2));
        elseif ischar(compare)
            compVals = tab.(compare);
        end
        [comp_u, ~, comp_s] = unique(compVals, 'stable');
        numComp = length(comp_u);
    end
    
    % set up values of rows var
    if isempty(rows)
        row_u = {'NONE'};
        row_s = ones(numData, 1);
        numRow = 1;
    else
        [row_u, ~, row_s] = unique(tab.(rows), 'stable');
        numRow = length(row_u);    
        if isnumeric(row_u) || islogical(row_u)
            row_u = arrayfun(@num2str, row_u, 'UniformOutput', false);
        end
        idx_isnum = cellfun(@isnumeric, row_u);
        row_u(idx_isnum) = cellfun(@num2str, row_u(idx_isnum),...
            'UniformOutput', false);
    end

    
    % set up values of cols var
    if isempty(cols)
        col_u = {'NONE'};
        col_s = ones(numData, 1);
        numCol = 1;
    else
        [col_u, ~, col_s] = unique(tab.(cols), 'stable');
        numCol = length(col_u);
        if isnumeric(col_u) || islogical(col_u)
            col_u = arrayfun(@num2str, col_u, 'UniformOutput', false);
        end
        idx_isnum = cellfun(@isnumeric, col_u);
        col_u(idx_isnum) = cellfun(@num2str, col_u(idx_isnum),...
            'UniformOutput', false);  
    end
    if isnumeric(col_u), col_u = num2cell(col_u); end
        
    % cannot plots histograms if more than 2 comp
    if numComp ~= 2
        warning('Back-to-back histograms can only be plotted when there are two comparisons.')
        plotB2BHist = false;
    end
    
    % unify sample length of averages - take the shortest
    lens = cellfun(@length, tab.erp_avg);
    ml = min(lens);
    if any(lens > ml)
        tab.erp_avg = cellfun(@(x) x(1:ml), tab.erp_avg, 'UniformOutput',...
            false);
    end
    
    % take time vector from shortest average
    time = tab.erp_time{find(lens == ml, 1)};
    
    % calculate average and SEM
    avg = zeros(length(tab.erp_avg{1}), numComp, numRow, numCol);
    sem = zeros(length(tab.erp_avg{1}) * 2, numComp, numRow, numCol);
    lat = cell(numComp, numRow, numCol);
    peakamp = cell(numComp, numRow, numCol);
    meanamp = cell(numComp, numRow, numCol);
    sdamp = cell(numComp, numRow, numCol);
    
    for comp = 1:numComp
        for row = 1:numRow
            for col = 1:numCol
                % make index of entries for the current comp/row/col, then
                % calculate avg and SEM for this subset of the data
                idx = comp_s == comp & row_s == row & col_s == col;
                if ~isempty(tab.erp_avg(idx))
                    
                    % avg & sem
                    tmpAvg = nanmean(cell2mat(tab.erp_avg(idx)));
                    tmpSD = nanstd(cell2mat(tab.erp_avg(idx)));
                    avg(:, comp, row, col) = tmpAvg';
                    tmpSem = nanstd(cell2mat(tab.erp_avg(idx))) /...
                        sqrt(sum(idx));
                    sem(:, comp, row, col) = [tmpAvg - (2 * tmpSem),...
                        fliplr(tmpAvg + (2 * tmpSem))];
                    
                    % latency and peak amp
                    lat{comp, row, col} = tab.lat(idx);
                    peakamp{comp, row, col} = tab.pamp(idx);
                    
                    % mean amp and sd
                    meanamp{comp, row, col} = tab.mamp(idx);
                   
                end
            end
        end
    end
    
    %% t-test
    
    if doTTest && numComp ~= 2    
        warning('t-test not performed since num comparions ~= 2.')
    end
        
    res_t.lat_t = nan(numRow, numCol);
    res_t.lat_p = nan(numRow, numCol);
    res_t.lat_ci = nan(2, numRow, numCol);
    res_t.lat_df = nan(numRow, numCol);
    res_t.amp_t = nan(numRow, numCol);
    res_t.amp_p = nan(numRow, numCol);
    res_t.amp_ci = nan(2, numRow, numCol);
    res_t.amp_df = nan(numRow, numCol);

    for row = 1:numRow
        for col = 1:numCol

            % amp
            [~, p, ci, stats] = ttest2(...
                meanamp{1, row, col},...
                meanamp{2, row, col});
            res_t.amp_t(row, col) = stats.tstat;
            res_t.amp_p(row, col) = p;
            res_t.amp_ci(:, row, col) = ci;
            res_t.amp_df(row, col) = stats.df;

            % lat
            [~, p, ci, stats] = ttest2(...
                lat{1, row, col},...
                lat{2, row, col});
            res_t.lat_t(row, col) = stats.tstat;
            res_t.lat_p(row, col) = p;
            res_t.lat_ci(:, row, col) = ci;
            res_t.lat_df(row, col) = stats.df;

        end 
    end
            
    %% make table
    
    if doTable && numComp == 2
      
        % make col labels
        numElements = numRow * numCol;
        colLab = cell(numElements, 1);
        i = 1;
        
        tab_amp_mudiff = nan(numElements, 1);
        tab_amp_sd = nan(numElements, 1);
        tab_amp_se = nan(numElements, 1);
        tab_amp_df1 = nan(numElements, 1);
        tab_amp_t = nan(numElements, 1);
        tab_amp_p = nan(numElements, 1);
        tab_amp_d = nan(numElements, 1);
        
        tab_lat_mudiff = nan(numElements, 1);
        tab_lat_sd = nan(numElements, 1);
        tab_lat_se = nan(numElements, 1);
        tab_lat_df1 = nan(numElements, 1);
        tab_lat_t = nan(numElements, 1);
        tab_lat_p = nan(numElements, 1);
        tab_lat_d = nan(numElements, 1);
        
        for r = 1:numRow
            for c = 1:numCol
                
                % column label
                colLab{i} = sprintf('%s_%s', row_u{r}, col_u{c});
                
                % amp
                N                   = sum(cellfun(@length, meanamp(:, r, c)));
                tab_amp_mudiff(i)   = nanmean(meanamp{1, r, c}) - nanmean(meanamp{2, r, c});
                tab_amp_sd(i)       = nanstd([cell2mat(meanamp(1, r, c)); cell2mat(meanamp(2, r, c))]);
                tab_amp_se(i)       = tab_amp_sd(i) / sqrt(N);
                tab_amp_df1(i)      = res_t.amp_df(r, c);
                tab_amp_t(i)        = res_t.amp_t(r, c);  
                tab_amp_p(i)        = res_t.amp_p(r, c);
                tab_amp_d(i)        = abs(tab_amp_mudiff(i) / tab_amp_sd(i));                 
                
                % lat
                N                   = sum(cellfun(@length, lat(:, r, c)));
                tab_lat_mudiff(i)   = nanmean(lat{1, r, c}) - nanmean(lat{2, r, c});
                tab_lat_sd(i)       = nanstd([cell2mat(lat(1, r, c)); cell2mat(lat(2, r, c))]);  
                tab_lat_se(i)       = tab_lat_sd(i) / sqrt(N);
                tab_lat_df1(i)      = res_t.lat_df(r, c);
                tab_lat_t(i)        = res_t.lat_t(r, c);  
                tab_lat_p(i)        = res_t.lat_p(r, c);
                tab_lat_d(i)        = abs(tab_lat_mudiff(i) / tab_lat_sd(i)); 
                
                i = i + 1;
                        
            end
        end
        
        % make row labels
        rowLab = {'comp', 'mean_diff', 'sd_pooled', 'se_pooled',...
            'df', 't', 'p', 'd'};
        
        % make matrices of numeric data
        tabData_amp = [tab_amp_mudiff, tab_amp_sd, tab_amp_se,...
            tab_amp_df1, tab_amp_t, tab_amp_p, tab_amp_d];
        tabData_lat = [tab_lat_mudiff, tab_lat_sd, tab_lat_se,...
            tab_lat_df1, tab_lat_t, tab_lat_p, tab_lat_d];
        
        % make amp table
        tab_stats_amp = array2table(tabData_amp, 'VariableNames',...
            rowLab(2:end));
        
        % add column for comparison
        tab_stats_amp.comp = colLab;
        
        % add column for measure
        tab_stats_amp.measure = repmat({'amplitude'}, numElements, 1);
        
        % add column for component
        tab_stats_amp.component = repmat({component}, numElements, 1);
        
        % add column for analysis name
        tab_stats_amp.name = repmat({name}, numElements, 1);
        
        % reorder columns
        tab_stats_amp = tab_stats_amp(:, [11, 10, 9, 8, 1:7]);
        
        % do the same for latency
        tab_stats_lat = array2table(tabData_lat, 'VariableNames',...
            rowLab(2:end));
        tab_stats_lat.comp = colLab;
        tab_stats_lat.measure = repmat({'latency'}, numElements, 1);
        tab_stats_lat.component = repmat({component}, numElements, 1);
        tab_stats_lat.name = repmat({name}, numElements, 1);
        tab_stats_lat = tab_stats_lat(:, [11, 10, 9, 8, 1:7]);
        
        % cat tables
        tab_stats = [tab_stats_amp; tab_stats_lat];
        
    elseif doTable && numComp ~= 2
        
        warning('Cannot produce summary table when number of comparisons > 2.')
        tab_stats = table;
        
    else
        
        tab_stats = table;
        
    end    
    
    %% erps
    
    % make time vector for area plots
    time_area = [time, fliplr(time)];

    if isempty(fig_erp)
        fig_erp = figure('name', name, 'defaultaxesfontsize', fontsize);
    else
        clf
        set(fig_erp, 'defaultaxesfontsize', fontsize);
    end

    % loop through each comparison/row/col 
    spIdx = 1;
    titleStr = cell(numRow, numCol);
    for row = 1:numRow
        for col = 1:numCol
            
            subplot(numRow, numCol, spIdx);
            spIdx = spIdx + 1;
            
            arCol = feval(colMap, numComp);
            
            % legend
            if isnumeric(comp_u)
                uCompStr = num2str(comp_u);
            else
                uCompStr = comp_u;
            end
            for arComp = 1:numComp
                hold on
                dta = avg(:, arComp, row, col);
                
                if doDeTrend
                    dta = detrend(dta);
                end
                
                plot(time, dta, 'linewidth', linewidth,...
                        'color', arCol(arComp, :))
            end         
            if numComp > 1 && plotSEM && showLegend, legend(uCompStr, 'Location', 'NorthEast'), end
            if numComp > 1 && ~plotSEM && showLegend, legend(uCompStr, 'Location', 'NorthEast'), end
                
            for arComp = 1:numComp
                hold on
                if plotSEM
                    
                    dta = sem(:, arComp, row, col);
                    
                    if doDeTrend
                        dta = detrend(dta);
                    end
                
                    ar = fill(time_area, dta, arCol(arComp, :));
                    ar.FaceAlpha = SEMAlpha;
                    ar.LineStyle = 'none';
                end
            end

            plERP = gca;
            
            % title labels
            str = '';
            if numRow > 1, str = [str, ' | ', row_u{row}]; end
            if numCol > 1, str = [str, ' | ', col_u{col}]; end
            if strcmpi(str, '') || strcmpi(str, ' | ')
                str = name;
            else 
                str = str(4:end);
            end
            
            title(str)
            titleStr{row, col} = str;
            
            % axis details
            text(0.5, 0.025, 'Shaded areas +/- 2 SEM', 'units',...
                'normalized', 'horizontalalignment', 'center',...
                'verticalalignment', 'bottom', 'color', [.4, .4, .4])
            xlabel('Time (s)')
            ylabel('Amplitude (uV)')
            set(gca, 'xgrid', 'on')
            set(gca, 'xminorgrid', 'on')
            set(gca, 'ygrid', 'on')
            set(gca, 'ylim', [min(avg(:)) - 1, max(avg(:)) + 1]);
            ax = gca;
            ax.XRuler.Axle.LineWidth = axLineWidth;
            ax.YRuler.Axle.LineWidth = axLineWidth;
            
        end
    end
    
    set(gcf, 'Color', [1, 1, 1])
    
    %% boxplots
    if plotBoxPlot
        
        % mean amp
        fig_bp_amp = figure('name', [name, '_boxplot_meanamp']);
        set(fig_bp_amp, 'defaultaxesfontsize', fontsize);
        % ylim
        ymin = min(vertcat(meanamp{:}));
        ymax = max(vertcat(meanamp{:}));
        yrange = ymax - ymin;
        yl = [ymin, ymax];
        % loop through each comparison/row/col 
        spIdx = 1;
        for row = 1:numRow
            for col = 1:numCol
                % plot
                subplot(numRow, numCol, spIdx);
                hold on
                spIdx = spIdx + 1;
                for comp = 1:numComp
%                     meanamp_bp = cell2mat(meanamp(:, row, col));
%                     boxplot(meanamp_bp, comp_s, 'parent', fig_bp_amp);
                    notBoxPlot(cell2mat(meanamp(comp, row, col)), comp, 'jitter', .5)
                end
                
                % append ttest results to title (if requested)
                if doTTest && ~isempty(res_t)
                    str = sprintf('%s\nt(%d)=%.3f, p=%.3f',...
                        titleStr{row, col},...
                        res_t.amp_df(row, col),...
                        res_t.amp_t(row, col),...
                        res_t.amp_p(row, col));
                else
                    str = titleStr{row, col};
                end
                
                % settings
                set(gca, 'xtick', 1:numComp)
                set(gca, 'xticklabel', comp_u)
                xlabel(compare, 'Interpreter', 'none')
                ylabel('Mean Amplitude (uV)')
                title(str)
                set(gca, 'ylim', yl);
                ax = gca;
                ax.XRuler.Axle.LineWidth = axLineWidth;
                ax.YRuler.Axle.LineWidth = axLineWidth;                
                
            end
        end
        set(fig_bp_amp, 'Color', [1, 1, 1])
        
        % latency
        fig_bp_lat = figure('name', [name, '_boxplot_latency']);
        set(fig_bp_lat, 'defaultaxesfontsize', fontsize);
        % loop through each comparison/row/col 
        spIdx = 1;
        for row = 1:numRow
            for col = 1:numCol
                % plot
                sp = subplot(numRow, numCol, spIdx);
                hold on
                spIdx = spIdx + 1;
                for comp = 1:numComp
%                     lat_bp = cell2mat(lat(:, row, col));
%                     boxplot(lat_bp, comp_s, 'parent', sp);
                    notBoxPlot(cell2mat(lat(comp, row, col)), comp, 'jitter', .5)
                end
                
                % append ttest results to title (if requested)
                if doTTest && ~isempty(res_t)
                    str = sprintf('%s\nt(%d)=%.3f, p=%.3f',...
                        titleStr{row, col},...
                        res_t.lat_df(row, col),...
                        res_t.lat_t(row, col),...
                        res_t.lat_p(row, col));
                else
                    str = titleStr{row, col};
                end
                
                % settings
                set(gca, 'xtick', 1:numComp)
                set(gca, 'xticklabel', comp_u)
                xlabel(compare, 'Interpreter', 'none')
                ylabel('Latency (s)')
                title(str)
                set(gca, 'ylim', [min(vertcat(lat{:})), max(vertcat(lat{:}))]);
                ax = gca;
                ax.XRuler.Axle.LineWidth = axLineWidth;
                ax.YRuler.Axle.LineWidth = axLineWidth;                
                
            end
        end
        set(fig_bp_lat, 'Color', [1, 1, 1])
        
    end
    
    %% histograms
    if plotHist
        
        hist_smooth = 50;
        
     % mean amp
        fig_hist_amp = figure('name', [name, '_boxplot_meanamp']);
        set(fig_hist_amp, 'defaultaxesfontsize', fontsize);
        % loop through each comparison/row/col 
        spIdx = 1;
        for row = 1:numRow
            for col = 1:numCol
                
                % plot bar
                subplot(numRow, numCol * 2, spIdx);
                
                bar_mu = cellfun(@(x) nanmean(x), meanamp(:, row, col));
                bar_sem = cellfun(@(x) nanstd(x) / sqrt(length(x)),...
                    meanamp(:, row, col));
                
                [h_bar, h_errbar] = barwitherr(bar_sem, bar_mu);
                h_bar.FaceColor = 'flat';
                cols = lines(numComp);
                for cmp = 1:numComp
                    h_bar.CData(cmp, :) = cols(cmp, :);
                end
                h_bar.LineWidth = linewidth;
                set(h_errbar, 'LineWidth', linewidth);
                
                % settings
                xlabel(compare)
                ylabel('Amplitude (µV)')
                set(gca, 'XTickLabel', comp_u)
                if numCol > 1 || numRow > 1
                    title(sprintf('Amplitude: %s', titleStr{row, col}))
                end                
                ax = gca;
                ax.XRuler.Axle.LineWidth = axLineWidth;
                ax.YRuler.Axle.LineWidth = axLineWidth; 
                if all(bar_mu < 1)
                    set(gca, 'ydir', 'reverse')
                end
                yl = [min(bar_mu - bar_sem), max(bar_mu + bar_sem)];
                ylim([yl(1) - abs(yl(1) * .2), yl(2) + abs(yl(2) * .2)])
                
                spIdx = spIdx + 1;
 
                % plot hist
                subplot(numRow, numCol * 2, spIdx);
                hold on
                
                binSize = round(size(vertcat(meanamp{:, row, col}), 1) / 8);
                for comp = 1:numComp
                    
                    % get data, make histogram
                    m = cell2mat(meanamp(comp, row, col));
                    
                    [vals, edges, ~] =...
                        histcounts(m, binSize, 'Normalization', 'probability');                     
                    bar(edges(2:end), vals, 1, 'EdgeColor', 'none', 'FaceAlpha', .4);
                    hold on
                    
                    [vals, edges, ~] =...
                        histcounts(m, hist_smooth, 'Normalization', 'probability');                    
                    edges = edges(2:end) - (edges(2)-edges(1))/2;
                    
                    % fit gaussian 
                    [f, ~] = fit(edges', vals', 'gauss1');
                    
                    % plot
                    set(gca, 'colororderindex', comp)
                    plot(edges, f(edges), 'LineWidth', linewidth)
                    
                end
                
%                 legend(comp_u)
                
                % settings
                xlabel('Mean Amplitude (uV)')
                ylabel('Probability')
                set(gca, 'YTick', [])
                if numCol > 1 || numRow > 1
                    title(sprintf('Amplitude: %s', titleStr{row, col}))
                end
                ax = gca;
                ax.XRuler.Axle.LineWidth = axLineWidth;
                ax.YRuler.Axle.LineWidth = axLineWidth;  
                
                spIdx = spIdx + 1;
                
            end
        end
        set(fig_hist_amp, 'Color', [1, 1, 1])
        
        % latency
        fig_hist_lat = figure('name', [name, '_boxplot_latency']);
        set(fig_hist_lat, 'defaultaxesfontsize', fontsize);
        % loop through each comparison/row/col 
        spIdx = 1;
        for row = 1:numRow
            for col = 1:numCol
                
                % plot bar
                subplot(numRow, numCol * 2, spIdx);
                
                bar_mu = cellfun(@(x) nanmean(x), lat(:, row, col));
                bar_sem = cellfun(@(x) nanstd(x) / sqrt(length(x)),...
                    lat(:, row, col));
                
                [h_bar, h_errbar] = barwitherr(bar_sem, bar_mu);
                h_bar.FaceColor = 'flat';
                cols = lines(numComp);
                for cmp = 1:numComp
                    h_bar.CData(cmp, :) = cols(cmp, :);
                end
                h_bar.LineWidth = linewidth;
                set(h_errbar, 'LineWidth', linewidth);
                
                % settings
                xlabel(compare)
                ylabel('Latency (s)')
                set(gca, 'XTickLabel', comp_u)
                if numCol > 1 || numRow > 1
                    title(sprintf('Latency: %s', titleStr{row, col}))
                end                
                ax = gca;
                ax.XRuler.Axle.LineWidth = axLineWidth;
                ax.YRuler.Axle.LineWidth = axLineWidth; 
                yl = [min(bar_mu - bar_sem), max(bar_mu + bar_sem)];
                ylim([yl(1) - abs(yl(1) * .2), yl(2) + abs(yl(2) * .2)])
                spIdx = spIdx + 1;
                
                % plot hist
                sp = subplot(numRow, numCol * 2, spIdx);
                hold on
                
                binSize = round(size(vertcat(meanamp{:, row, col}), 1) / 8);
                for comp = 1:numComp
                    
                    % get data, make histogram
                    m = cell2mat(lat(comp, row, col));
                    
                    [vals, edges, ~] =...
                        histcounts(m, binSize, 'Normalization', 'probability');                     
                    bar(edges(2:end), vals, 1, 'EdgeColor', 'none', 'FaceAlpha', .4);
                    hold on
                    
                    [vals, edges, ~] =...
                        histcounts(m, hist_smooth, 'Normalization', 'probability');                    
                    edges = edges(2:end) - (edges(2)-edges(1))/2;
                    
                    % fit gaussian 
                    [f, ~] = fit(edges', vals', 'gauss1');
                    
                    % plot
                    set(gca, 'colororderindex', comp)
                    plot(edges, f(edges), 'LineWidth', linewidth)
                    
                end
                
%                 legend(comp_u)
                
                % settings
                xlabel('Latency (s)')
                ylabel('Probability')
                set(gca, 'YTick', [])
                if numCol > 1 || numRow > 1
                    title(sprintf('Latency: %s', titleStr{row, col}))
                end
                ax = gca;
                ax.XRuler.Axle.LineWidth = axLineWidth;
                ax.YRuler.Axle.LineWidth = axLineWidth;  
                
                spIdx = spIdx + 1;
                
            end
        end
        set(fig_hist_lat, 'Color', [1, 1, 1])        
        
    end        
   
    %% back to back histograms
    if plotB2BHist
        
     % mean amp
        fig_b2bhist = figure('name', [name, '_boxplot_meanamp']);
        set(fig_b2bhist, 'defaultaxesfontsize', fontsize);
        % loop through each comparison/row/col 
        spIdx = 1;
        for row = 1:numRow
            for col = 1:numCol
                % plot
                subplot(numRow, numCol, spIdx);
                hold on
                spIdx = spIdx + 1;
                b2bhist(cell2mat(meanamp(1, row, col)'), cell2mat(meanamp(2, row, col)'));
                % settings
                xlabel('Mean Amplitude (uV)')
            end
        end
        set(fig_b2bhist, 'Color', [1, 1, 1])
        
        % latency
        fig_hist2 = figure('name', [name, '_boxplot_latency']);
        set(fig_hist2, 'defaultaxesfontsize', fontsize);
        % loop through each comparison/row/col 
        spIdx = 1;
        for row = 1:numRow
            for col = 1:numCol
                % plot
                subplot(numRow, numCol, spIdx);
                hold on
                spIdx = spIdx + 1;
                b2bhist(cell2mat(lat(1, row, col)'), cell2mat(lat(2, row, col)'));
                % settings
                xlabel('Latency (s)')
            end
        end
        set(fig_hist2, 'Color', [1, 1, 1])        
        
    end
    
    %% TF
    if plotERO  
        figure('name', [name, '_ERSP'])

        if numComp > 2
            text(.5, .5, 'Cannot display >2 ERSP comparisons')
        else

            % loop through each comparison/row/col 
            spIdx = 1;
            for row = 1:numRow
                for col = 1:numCol

                    subplot(numRow, numCol, spIdx);
                    spIdx = spIdx + 1;

                    % plot ga ERSP
                    if numComp == 1
                        tmp = freq(:, :, 1, row, col);
                    elseif numComp == 2
                        tmp = freq(:, :, 1, row, col) - freq(:, :, 2, row, col);
                    end
                    imagesc(flipud(tmp))
                    set(gca, 'xtick', get(plERP, 'xtick'))
                    set(gca, 'xticklabel', get(plERP, 'xticklabel'))

                    % title labels
                    if numComp == 2
                        leg = sprintf('%s - %s', comp_u{1:2});
                        legend(leg, 'Location', 'NorthEast')
                    end
                    str = '';
                    if numRow > 1, str = [str, ' | ', row_u{row}]; end
                    if numCol > 1, str = [str, ' | ', col_u{col}]; end
                    if strcmpi(str, '') || strcmpi(str, ' | ')
                        str = name;
                    else 
                        str = str(4:end);
                    end
                    title(str)

                end
            end

        end
    end

    set(gcf, 'Color', [1, 1, 1])
    hold off
    
    tightfig(fig_erp)
    tilefigs
    
%     tightfig(fig_hist_amp)
%     tightfig(fig_hist_lat)
        
    fig_bp_amp.Position(3) = 400;
    fig_bp_lat.Position(3) = 400;
    fig_b2bhist.Position(3) = 461;
    fig_b2bhist.Position(4) = 600;
    fig_hist2.Position(3) = 461;
    fig_hist2.Position(4) = 600;
    fig_erp.Position(3) = 600;
    fig_erp.Position(4) = 450;
        
    fig_erp.Position(3) = 1500;
    fig_erp.Position(4) = 535;
    
    if plotHist
        fig_hist_amp.Position(3) = 730;
        fig_hist_amp.Position(4) = 370 * numRow;
        fig_hist_lat.Position(3) = 730;
        fig_hist_lat.Position(4) = 370 * numRow;        
    end
    
end