function [data, file_out, summary] =...
    eegClean(file_in, path_out, manualArt, dataVarName,...
    opt)

    if exist('dataVarName', 'var') && ~isempty(dataVarName)
        renameData = true;
    else
        dataVarName = 'data';
        renameData = false;
    end
    
    if ~exist('opt', 'var') || isempty(opt)
        opt.alpha = true;
        opt.minmax = true;
        opt.range = true;
        opt.eog = true;
        opt.flat = true;
    end

    if ~isfield(opt, 'alpha'),          opt.alpha = true;           end
    if ~isfield(opt, 'alphamaxsd'),     opt.alphamaxsd = 6;         end
    if ~isfield(opt, 'minmaxmin'),      opt.minmaxmin = -80;        end
    if ~isfield(opt, 'minmaxmax'),      opt.minmaxmax = 80;         end
    if ~isfield(opt, 'minmax'),         opt.minmax = true;          end
    if ~isfield(opt, 'range'),          opt.range = true;           end
    if ~isfield(opt, 'rangeval'),       opt.rangeval = 170;         end
    if ~isfield(opt, 'eog'),            opt.eog = true;             end
    if ~isfield(opt, 'eogmaxsd'),       opt.eogmaxsd = 6;           end
    if ~isfield(opt, 'flat'),           opt.flat = true;            end
    if ~isfield(opt, 'interpdist'),     opt.interpdist = .6;        end

    art_minMax = [];
    art_range = [];
    art_flat = [];
    art_alpha = [];
    art_eog = [];

    % define AR criteria
    ar_min = opt.minmaxmin;
    ar_max = opt.minmaxmax;
    ar_range = opt.rangeval;
    ar_eog_z = opt.eogmaxsd;
    alphaMaxSD = opt.alphamaxsd;
    
    % interpolation distance (mm)
    interp_dist = opt.interpdist;
       
    % split input path
    [filePath, fileName, fileExt] = fileparts(file_in);
    
    % make output filename
    file_out = [fileName, '.clean', '.mat'];
            
    % check output path exists
    if ~exist(path_out, 'dir')
        summary.cleanError = 'Output path does not exist.';
        return
    end
    
    % summary defaults
    summary.clean_FileIn = file_in;
    summary.clean_PathIn = filePath;
    summary.clean_FileOut = file_out;
    summary.clean_PathOut = path_out;
    summary.numChanInterp = 0;
    summary.chanInterp = '';
    summary.totInterp = 0;
    summary.propInterp = 0;
    summary.numChanExcl = 0;
    summary.chanExcl = '';
    summary.P7Bad = false;
    summary.P8Bad = false;
    summary.O1Bad = false;
    summary.O2Bad = false;
    summary.ar_postInterp = 0;
    summary.totaltrials = 0;
    summary.tpc_up = 0;
    summary.tpc_inv = 0;
    
    % load
    data = [];
    load(file_in);
    
    % if a different variable name has been passed for date (e.g.
    % data_face) then rename this to data
    if renameData
        eval(sprintf('data = %s;', dataVarName));
    end
        
    % check that data loaded successfully
    if isempty(data)
        summary.cleanValid = false;
        summary.cleanError = 'Load error';
        return
    end
    
    % check that an elec struct is present 
    if ~isfield(data, 'elec')
        summary.cleanValid = false;
        summary.cleanError = 'No elec (channel locations) info present';
        return
    end
    
    % if present, remove cfg struct from data
    if isfield(data, 'cfg'), data = rmfield(data, 'cfg'); end
    
    % get audit and summary structs from data 
    if isfield(data, 'summary')
        summary = catstruct(data.summary, summary);
        data = rmfield(data, 'summary');
    end
    
%     try
        
        % check for all flat channels
        allFlat = all(cellfun(@(x) all(x(:) == 0), data.trial));
        if allFlat
            summary.cleanError = 'All channels flat';
            summary.cleanValid = false;
            return
        end
        
        % remove additional channels (just keep 10-20)
        cfg = [];
        cfg.channel = data.elec.label;
        data = ft_selectdata(cfg, data);
        
        % make channel neighbours struct for later use in interpolation
        cfg = [];
        cfg.method = 'distance';
        cfg.layout = data.elec;
        cfg.neighbourdist = interp_dist;
        nb = ft_prepare_neighbours(cfg, data); 
        
        % artefact detection to mark trial/channel combinations that need
        % interpolation. don't look at eog here, since we don't want to
        % interpolate those artefacts
        if opt.minmax,  art_minMax  = eegAR_MinMax(data, ar_min, ar_max);   end
        if opt.range,   art_range   = eegAR_Range(data, ar_range);          end
        if opt.flat,    art_flat    = eegAR_Flat(data);                     end
        if opt.alpha,   art_alpha   = eegAR_Alpha(data, alphaMaxSD);        end
        art = eegAR_Combine(data, art_minMax, art_range, art_flat,...
            art_alpha);
        
        % find channels with >80% bad trials, and intepolate the entire
        % channel for all trials (this is faster than doing it
        % trial-by-trial, which is what we do for more sparse aretfacts in
        % the next stage)
        propBad = art.chanBreakdown / length(data.trial);
        chanInterp = propBad >= .8;
        chanInterpLabs = data.label(chanInterp);
        interp = false(length(data.label), length(data.trial));
        interp(chanInterp, :) = true;
        
        % interpolate any bad channels
        if any(chanInterp)
            
            % interpolate
            cfg = [];
            cfg.method = 'spline';
            cfg.badchannel = chanInterpLabs;
            cfg.neighbours = nb;
            data = ft_channelrepair(cfg, data);
            summary.numChanInterp = length(chanInterpLabs);
            summary.chanInterp = cell2char(chanInterpLabs);
            
            % run AR-D again to update artefacts post-interpolation
            if opt.minmax,  art_minMax  = eegAR_MinMax(data, ar_min, ar_max);   end
            if opt.range,   art_range   = eegAR_Range(data, ar_range);          end
            if opt.flat,    art_flat    = eegAR_Flat(data);                     end
            if opt.alpha,   art_alpha   = eegAR_Alpha(data, alphaMaxSD);        end
            art = eegAR_Combine(data, art_minMax, art_range, art_flat,...
                art_alpha);
            
        else
            summary.channels_interp = 'none';
        end

        % interpolate trials with detected artefacts on a per-channel basis
        [data, ~, ~,...
            summary.totInterp, summary.propInterp, trInterp,...
            data.interpNeigh, data.cantInterp] =...
            eegInterpTrial(data, art, interp_dist, nb);
        interp = interp | trInterp;

        % post-interpolation, rerun AR-D in order to detect those channels
        % with so many artefacts that they should be exluded from avg ref,
        % and from future AR-D
        if opt.minmax,  art_minMax  = eegAR_MinMax(data, ar_min, ar_max);   end
        if opt.range,   art_range   = eegAR_Range(data, ar_range);          end
        if opt.flat,    art_flat    = eegAR_Flat(data);                     end
        if opt.alpha,   art_alpha   = eegAR_Alpha(data, alphaMaxSD);        end
        art = eegAR_Combine(data, art_minMax, art_range, art_flat,...
            art_alpha);
        
        % exclude trials with >40% bad trials (but not EOG channels, since
        % these pollute other channels, so should be dropped when bad)
        labels_eog = {'FP1', 'FP2', 'FPz', 'AF7', 'AF8'};
        idx_eog = cellfun(@(x) strcmpi(data.label, x), labels_eog,...
            'uniform', false);
        idx_eog = any(horzcat(idx_eog{:}), 2);        
        propBad = sum(art.matrix, 2) / size(art.matrix, 2);                 
        chanExcl = ~idx_eog & propBad > .4;
        summary.numChanExcl = sum(chanExcl);
        summary.chanExcl = cell2char(data.label(chanExcl));
        
        % mark whether key channels are bad
        summary.P7Bad = strcmpi(summary.chanExcl, 'P7');
        summary.P8Bad = strcmpi(summary.chanExcl, 'P8');
        summary.O1Bad = strcmpi(summary.chanExcl, 'O1');
        summary.O2Bad = strcmpi(summary.chanExcl, 'O2');    
        
        % AR - just frontal channels for blinks
        if opt.eog, art_eog = eegAR_EOGStat(data, ar_eog_z, ~idx_eog); end

        % AR - to drop trials
        if opt.minmax,  art_minMax  = eegAR_MinMax(data, ar_min, ar_max);   end
        if opt.range,   art_range   = eegAR_Range(data, ar_range);          end
        if opt.flat,    art_flat    = eegAR_Flat(data);                     end
        if opt.alpha,   art_alpha   = eegAR_Alpha(data, alphaMaxSD);        end
        art_drop = eegAR_Combine(data, art_minMax, art_range, art_eog,...
            art_flat, art_alpha, {'minmax', 'range', 'eog', 'flat', 'alpha'});
        summary.ar_postInterp = art_drop.trialsGood;
        
        % count trials per condition
        tab = eegCountTrialNumbers(data, art_drop);
        idx_up = tab(:, 1) >= 223 & tab(:, 1) <= 225;
        idx_inv = tab(:, 1) >= 226 & tab(:, 1) <= 228;
        if ~isempty(tab)
            summary.totaltrials = sum(tab(:, 2));
            summary.tpc_up = sum(tab(idx_up, 2));
            summary.tpc_inv = sum(tab(idx_inv, 2));       
        else
            summary.totaltrials = length(data.trial);
            summary.tpc_up = 0;
            summary.tpc_inv = 0;
        end
        
        % store audit and summary structs
        data.summary = summary;
        
        % store artefact detection matrices 
        data.art = art_drop.matrix;
        if isfield(art_drop, 'type')
            data.artType = art_drop.type;
        end
        data.interp = interp;
        data.chanExcl = chanExcl;

        % save
        if renameData, eval(sprintf('%s = data;', dataVarName)); end
        save(fullfile(path_out, file_out), dataVarName, '-v6')
        
%     catch ERR
%         
%         summary.cleanError = ERR.message;
%         return
%         
%     end
    
    summary.cleanValid = true;
    summary.cleanError = 'None';

end