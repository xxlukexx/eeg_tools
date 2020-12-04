% function eegPlotFactorialGA(...
%     tab, comp, time, compare, rows, cols, filt, name, plotSEM, colMap)
function fig = eegPlotFactorialGA(tab, time, comp, varargin)

    parser      =   inputParser;
    checkField  =   @(x) any(strcmpi(tab.Properties.VariableNames, x)   );
    addRequired(    parser, 'tab',                      @istable        )
    addRequired(    parser, 'time',                     @isvector       )
    addRequired(    parser, 'comp',                     @ischar         )
    addParameter(   parser, 'compare',      []                          )
    addParameter(   parser, 'rows',         [],         checkField      )
    addParameter(   parser, 'cols',         [],         checkField      )
    addParameter(   parser, 'filt',         [],         checkField      )
    addParameter(   parser, 'name',         'Average',  @ischar         )
    addParameter(   parser, 'plotSEM',      true,       @islogical      )
    addParameter(   parser, 'SEMAlpha',     .2,         @isnumeric      )
    addParameter(   parser, 'colMap',       @parula                     )
    addParameter(   parser, 'linewidth',    1.5,        @isnumeric      )
    addParameter(   parser, 'fontsize',     10,         @isnumeric      )
    addParameter(   parser, 'mawidth',      .040,       @isnumeric      )    
    addParameter(   parser, 'plotERO',      false,      @islogical      )
    addParameter(   parser, 'plotBoxplot',  false,      @islogical      )
    addParameter(   parser, 'plotHist',     false,      @islogical      )
    addParameter(   parser, 'fig',          [],         @ishandle       )
    addParameter(   parser, 'legend',       true,       @islogical      )
    parse(          parser, tab, time, comp, varargin{:});
    tab         =   parser.Results.tab;
    time        =   parser.Results.time;
    comp        =   parser.Results.comp;
    compare     =   parser.Results.compare;
    rows        =   parser.Results.rows;
    cols        =   parser.Results.cols;
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
    plotHist    =   parser.Results.plotHist;
    fig         =   parser.Results.fig;
    showLegend  =   parser.Results.legend;
    
    % get channel index
    compIdx = strcmpi(tab.comp, comp);
    if ~any(compIdx), error('Component not found.'); end
    tab = tab(compIdx, :);
    
    numData = size(tab, 1);
    
    % set up values of compare var
    if isempty(compare)
        uComp = 'NONE';
        sComp = ones(numData, 1);
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
        [uComp, ~, sComp] = unique(compVals);
        numComp = length(uComp);
    end
    
    % set up values of rows var
    if isempty(rows)
        uRow = 'NONE';
        sRow = ones(numData, 1);
        numRow = 1;
    else
        [uRow, ~, sRow] = unique(tab.(rows));
        numRow = length(uRow);
    end
    if isnumeric(uRow), uRow = num2cell(uRow); end
    
    % set up values of cols var
    if isempty(cols)
        uCol = 'NONE';
        sCol = ones(numData, 1);
        numCol = 1;
    else
        [uCol, ~, sCol] = unique(tab.(cols));
        numCol = length(uCol);
    end
    if isnumeric(uCol), uCol = num2cell(uCol); end
    
    % cannot plots histograms if more than 2 comp
    if numComp ~= 2
        warning('Back-to-back histograms can only be plotted when there are two comparisons.')
        plotHist = false;
    end

    % calculate average and SEM
    avg = zeros(length(tab.avg{1}), numComp, numRow, numCol);
    sem = zeros(length(tab.avg{1}) * 2, numComp, numRow, numCol);
    lat = cell(numComp, numRow, numCol);
    peakamp = cell(numComp, numRow, numCol);
    meanamp = cell(numComp, numRow, numCol);
    sdamp = cell(numComp, numRow, numCol);
    if plotERO
        freq = zeros(size(tab.freq{1}, 1), size(tab.freq{1}, 2), numComp,...
            numRow, numCol);
    end
    
    for comp = 1:numComp
        for row = 1:numRow
            for col = 1:numCol
                % make index of entries for the current comp/row/col, then
                % calculate avg and SEM for this subset of the data
                idx = sComp == comp & sRow == row & sCol == col;
                if ~isempty(tab.avg(idx))
                    
                    % avg & sem
                    tmpAvg = mean(cell2mat(tab.avg(idx)));
                    tmpSD = std(cell2mat(tab.avg(idx)));
                    avg(:, comp, row, col) = tmpAvg;
                    tmpSem = std(cell2mat(tab.avg(idx))) /...
                        sqrt(sum(idx));
                    sem(:, comp, row, col) = [tmpAvg - (2 * tmpSem),...
                        fliplr(tmpAvg + (2 * tmpSem))];
                    
                    % latency and peak amp
                    lat{comp, row, col} = tab.latency(idx);
                    peakamp{comp, row, col} = tab.peakamp(idx);
                    
                    % mean amp and sd
                    meanamp{comp, row, col} = tab.meanamp(idx);
%                     s1 = lat{comp, row, col} - (mawidth / 2);
%                     s2 = lat{comp, row, col} + (mawidth / 2);                    
%                     s1_samp = arrayfun(@(x) find(time >= x, 1, 'first'), s1);
%                     s2_samp = arrayfun(@(x) find(time >= x, 1, 'first'), s2);
%                     
%                     
%                     s1 = mean(lat{comp, row, col}) - (mawidth / 2);
%                     s2 = mean(lat{comp, row, col}) + (mawidth / 2);
%                     s1_samp = find(time >= s1, 1, 'first');
%                     s2_samp = find(time >= s2, 1, 'first');
%                     meanamp{comp, row, col} = ...
%                         avg(s1_samp:s2_samp, comp, row, col);
%                     sdamp{comp, row, col} = ...
%                         tmpSD(s1_samp:s2_samp);
                    
                    % ERSP
                    if plotERO
                        tmpFreq = zeros(size(tab.freq{1}));
                        found = find(idx);
                        for a = 1:length(found)
                            tmpFreq = tmpFreq + tab.freq{found(a)};
                        end
                        freq(:, :, comp, row, col) = tmpFreq / sum(idx);
                    end
                end
            end
        end
    end
    
    %% erps
    
    % make time vector for area plots
    time_area = [time, fliplr(time)];

    if isempty(fig)
        fig = figure('name', name, 'defaultaxesfontsize', fontsize);
    else
        clf
        set(fig, 'defaultaxesfontsize', fontsize);
    end

    % loop through each comparison/row/col 
    spIdx = 1;
    titleStr = cell(numRow, numCol);
    for row = 1:numRow
        for col = 1:numCol
            
            subplot(numRow, numCol, spIdx);
            spIdx = spIdx + 1;
                
            arCol = feval(colMap, numComp);
            for arComp = 1:numComp
                hold on
                if plotSEM
                    ar = fill(time_area, sem(:, arComp, row, col),...
                        arCol(arComp, :));
                    ar.FaceAlpha = SEMAlpha;
                    ar.LineStyle = 'none';
                end
            end
                
            % legend
            if isnumeric(uComp)
                uCompStr = num2str(uComp);
            else
                uCompStr = uComp;
            end
            if numComp > 1 && plotSEM && showLegend, legend(uCompStr, 'Location', 'NorthEast'), end
            
            for arComp = 1:numComp
                plot(time, avg(:, arComp, row, col), 'linewidth', linewidth,...
                        'color', arCol(arComp, :))
            end         
            if numComp > 1 && ~plotSEM && showLegend, legend(uCompStr, 'Location', 'NorthEast'), end

            plERP = gca;
            
            % title labels
            str = '';
            if numRow > 1, str = [str, ' | ', uRow{row}]; end
            if numCol > 1, str = [str, ' | ', uCol{col}]; end
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
                        
        end
    end
    
    set(gcf, 'Color', [1, 1, 1])
    
    %% boxplots
    if plotBoxPlot
        
        % mean amp
        fig_bp1 = figure('name', [name, '_boxplot_meanamp']);
        set(fig_bp1, 'defaultaxesfontsize', fontsize);
        % loop through each comparison/row/col 
        spIdx = 1;
        for row = 1:numRow
            for col = 1:numCol
                % plot
                subplot(numRow, numCol, spIdx);
                hold on
                spIdx = spIdx + 1;
                for comp = 1:numComp
                    notBoxPlot(cell2mat(meanamp(comp, row, col)), comp, 'jitter', .5)
                end
                % settings
                set(gca, 'xtick', 1:numComp)
                set(gca, 'xticklabel', uComp)
                xlabel(compare)
                ylabel('Mean Amplitude (uV)')
                title(titleStr(row, col))
            end
        end
        set(fig_bp1, 'Color', [1, 1, 1])
        
        % latency
        fig_bp2 = figure('name', [name, '_boxplot_latency']);
        set(fig_bp2, 'defaultaxesfontsize', fontsize);
        % loop through each comparison/row/col 
        spIdx = 1;
        for row = 1:numRow
            for col = 1:numCol
                % plot
                subplot(numRow, numCol, spIdx);
                hold on
                spIdx = spIdx + 1;
                for comp = 1:numComp
                    notBoxPlot(cell2mat(lat(comp, row, col)), comp, 'jitter', .5)
                end
                % settings
                set(gca, 'xtick', 1:numComp)
                set(gca, 'xticklabel', uComp)
                xlabel(compare)
                ylabel('Latency (s)')
                title(titleStr(row, col))
            end
        end
        set(fig_bp2, 'Color', [1, 1, 1])
        
    end
    
    %% histograms
    if plotHist
        
     % mean amp
        fig_hist1 = figure('name', [name, '_boxplot_meanamp']);
        set(fig_hist1, 'defaultaxesfontsize', fontsize);
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
        set(fig_hist1, 'Color', [1, 1, 1])
        
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
                        leg = sprintf('%s - %s', uComp{1:2});
                        legend(leg, 'Location', 'NorthEast')
                    end
                    str = '';
                    if numRow > 1, str = [str, ' | ', uRow{row}]; end
                    if numCol > 1, str = [str, ' | ', uCol{col}]; end
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
    
    tilefigs
    
    fig_bp1.Position(3) = 400;
    fig_bp2.Position(3) = 400;
    fig_hist1.Position(3) = 461;
    fig_hist1.Position(4) = 600;
    fig_hist2.Position(3) = 461;
    fig_hist2.Position(4) = 600;
    fig.Position(3) = 600;
    fig.Position(4) = 450;
    
end