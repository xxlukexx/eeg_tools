function eeg = eegFieldtrip2EEGLab(data)

    eeg.chanlocs = [];

    for i=1:size(data.trial,2)
      eeg.data(:,:,i) = single(data.trial{i});
    end

    eeg.setname    = 'fieldtrip_dataset';
    eeg.filename   = '';
    eeg.filepath   = '';
    eeg.subject    = '';
    eeg.group      = '';
    eeg.condition  = '';
    eeg.session    = [];
    eeg.comments   = 'preprocessed with fieldtrip';
    eeg.nbchan     = size(data.trial{1},1);
    eeg.trials     = size(data.trial,2);
    eeg.pnts       = size(data.trial{1},2);
    eeg.srate      = data.fsample;
    eeg.xmin       = data.time{1}(1);
    eeg.xmax       = data.time{1}(end);
    eeg.times      = data.time{1};
    eeg.ref        = []; %'common';
    eeg.event      = [];
    eeg.epoch      = [];
    eeg.icawinv    = [];
    eeg.icasphere  = [];
    eeg.icaweights = [];
    eeg.icaact     = [];
    eeg.saved      = 'no';
    
    for c = 1:length(data.label)
        eeg.chanlocs(c).label = data.label{c};
    end

end