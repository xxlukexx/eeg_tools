function [dataCombined, eventsCombined] = join_brainvision_folder(folderPath, varargin)
%JOIN_BRAINVISION_FOLDER  Concatenate all BrainVision files in a folder
%
%   [dataCombined, eventsCombined] = join_brainvision_folder(folderPath)
%   [...] = join_brainvision_folder(folderPath,'OutputFile','/path/out.mat','Verbose',false)
%
% Requires FieldTrip on the MATLAB path.
%
% -------------------------------------------------------------------------
% Luke Maynard • 2025-05-02  – fixed sample-count bug (size(…,2) ≠ numel(...))
% -------------------------------------------------------------------------

%% ── options ──────────────────────────────────────────────────────────────
p = inputParser();
addRequired(p,'folderPath',@(x)ischar(x)||isstring(x));
addParameter(p,'OutputFile',[],@(x)ischar(x)||isstring(x));
addParameter(p,'Verbose',true,@(x)islogical(x)&&isscalar(x));
parse(p,folderPath,varargin{:});

outFile = string(p.Results.OutputFile);
verbose = p.Results.Verbose;

%% ── locate header files ──────────────────────────────────────────────────
hdrFiles = dir(fullfile(folderPath,'*.vhdr'));
assert(~isempty(hdrFiles),'No *.vhdr files found in %s',folderPath);

[~,idx] = sort([hdrFiles.datenum]);   % chronological order
hdrFiles = hdrFiles(idx);
nParts   = numel(hdrFiles);

if verbose
    fprintf('Found %d recording part(s) in "%s".\n',nParts,folderPath);
end

%% ── read first part ──────────────────────────────────────────────────────
cfg           = [];
cfg.dataset   = fullfile(hdrFiles(1).folder,hdrFiles(1).name);
dataCombined  = ft_preprocessing(cfg);
eventsCombined = ft_read_event(strrep(cfg.dataset,'.vhdr','.vmrk'));

totalSamples = size(dataCombined.trial{1},2);   % *** fixed ***
lastTimeEnd  = dataCombined.time{1}(end);
fs           = dataCombined.fsample;

%% ── loop over remaining parts ────────────────────────────────────────────
for k = 2:nParts
    cfg.dataset = fullfile(hdrFiles(k).folder,hdrFiles(k).name);
    partData    = ft_preprocessing(cfg);
    partEvents  = ft_read_event(strrep(cfg.dataset,'.vhdr','.vmrk'));
    partSamples = size(partData.trial{1},2);    % *** fixed ***

    % consistency checks
    if abs(partData.fsample - fs) > 1e-6
        error('Sampling-rate mismatch between first file and %s',hdrFiles(k).name);
    end
    if size(partData.trial{1},1) ~= size(dataCombined.trial{1},1)
        error('Channel-count mismatch between first file and %s',hdrFiles(k).name);
    end

    % concatenate signal & time
    dataCombined.trial{1} = [dataCombined.trial{1}, partData.trial{1}];
    dataCombined.time{1}  = [dataCombined.time{1},  partData.time{1}+lastTimeEnd];

    % shift and append events
    for e = 1:numel(partEvents)
        partEvents(e).sample = partEvents(e).sample + totalSamples;
        if isfield(partEvents,'time')
            partEvents(e).time = partEvents(e).time + lastTimeEnd;
        end
    end
    eventsCombined = [eventsCombined(:); partEvents(:)]; %#ok<AGROW>

    % book-keeping
    totalSamples = totalSamples + partSamples;           % *** fixed ***
    lastTimeEnd  = dataCombined.time{1}(end);

    if verbose
        fprintf('  Appended part %d/%d (%d samples, total %d)\n', ...
                k,nParts,partSamples,totalSamples);
    end
end

%% ── finalise combined structure ─────────────────────────────────────────
dataCombined.sampleinfo = [1 totalSamples];
dataCombined.events     = eventsCombined;

%% ── sanity check ────────────────────────────────────────────────────────
if verbose, fprintf('Running sanity check...\n'); end
cursor = 0;
for k = 1:nParts
    cfg.dataset = fullfile(hdrFiles(k).folder,hdrFiles(k).name);
    partData    = ft_preprocessing(cfg);

    thisLen = size(partData.trial{1},2);                 % *** fixed ***
    slice   = dataCombined.trial{1}(:,cursor + (1:thisLen));

    maxDiff = max(abs(slice(:) - partData.trial{1}(:)));
    if verbose
        fprintf('  Part %d: max(abs(diff)) = %.3g\n',k,maxDiff);
    end
    if maxDiff ~= 0
        error('Sanity check failed for part %d (max diff %.3g)',k,maxDiff);
    end
    cursor = cursor + thisLen;                           % *** fixed ***
end

%% ── save if requested ───────────────────────────────────────────────────
if ~isempty(outFile)
    if verbose, fprintf('Saving combined data to "%s"...\n',outFile); end
    data   = dataCombined; 
    events = eventsCombined; 
    save(outFile,'data','events','-v7.3');
end

if verbose
    fprintf('Done. Total samples = %d\n',totalSamples);
end
end
