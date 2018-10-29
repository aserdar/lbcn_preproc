function EpochDataAll(sbj_name, project_name, bn, dirs,el,freq_band,thr_raw,thr_diff,epoch_params,datatype)

%% INPUTS:
%   sbj_name: subject name
%   project_name: name of task
%   block_names: blocks to be analyed (cell of strings)
%   dirs: directories pointing to files of interest (generated by InitializeDirs)
%   elecs: can select subset of electrodes to epoch (default: all)
%   datatype: 'CAR', 'HFB', or 'Spect' (which type of data to load and epoch)
%   thr_raw: threshold for raw data (z-score threshold relative to all data points) to exclude timepoints
%   thr_diff: threshold for changes in signal (diff bw two consecutive points; also z-score)
%   epoch_params.locktype: 'stim' or 'resp' (which events to timelock to)
%   epoch_params.bef_time: time (in s) before event to start each epoch of data
%   epoch_params.aft_time: time (in s) after event to end each epoch of data
%   epoch_params.blc: baseline correction
%       .run: true or false (whether to run baseline correction)
%       .locktype: 'stim' or 'resp' (which event to use to choose baseline window)
%       .win: 2-element vector specifiying window relative to lock event to use for baseline, in sec (e.g. [-0.2 0])
%   epoch_params.noise.method: 'trials','timepts', or 'none' (which baseline data to
%                       exclude before baseline correction)
%               .noise_fields_trials  (which trials to exclude- if method = 'trials')
%               .noise_fields_timepts (which timepts to exclude- if method = 'timepts')

% set default paramters (if inputs are missing or empty)

if isempty(epoch_params)
    epoch_params.locktype = 'stim';
    epoch_params.noise.method = 'trials';
    epoch_params.noise.noise_fields_trials = {'bad_epochs_HFO','bad_epochs_raw_HFspike'};
    epoch_params.noise.noise_fields_timepts = {'bad_inds_HFO','bad_inds_raw_HFspike'};
    epoch_params.blc.run = true;
    epoch_params.blc.locktype = 'stim';
    epoch_params.blc.win = [-0.2 0];
    epoch_params.bef_time = -0.5;
    epoch_params.aft_time = 3;
end

if isempty(thr_diff)
    thr_diff = 15;
end

if isempty(thr_raw)
    thr_raw = 15;
end

if isempty(datatype)
    datatype = 'CAR';
end


% Check if baseline window is within desired epoched window
% Otherwise, will need to epoch baseline separately and add as separate
% input to baseline correction function
if epoch_params.blc.run && ~(strcmp(epoch_params.locktype,epoch_params.blc.locktype) && epoch_params.blc.win(1)>=epoch_params.bef_time && epoch_params.blc.win(2) <= epoch_params.aft_time)
    sep_bl = true;
else
    sep_bl = false;
end

%% loop through electrodes

% Load globalVar
fn = sprintf('%s/originalData/%s/global_%s_%s_%s.mat',dirs.data_root,sbj_name,project_name,sbj_name,bn);
load(fn,'globalVar');

% dir_CAR = [dirs.data_root,'/originalData/',sbj_name,'/',bn];
% dir_in = [dirs.data_root,'/',datatype,'Data/',sbj_name,'/',bn];
% dir_out = [dirs.data_root,'/',datatype,'Data/',sbj_name,'/',bn, '/EpochData'];

% dir_CAR = [dirs.data_root,'/originalData/',sbj_name,'/',bn];
dir_in = [globalVar.([datatype,'Data']),filesep,freq_band,filesep,sbj_name,filesep,bn];
dir_out = [dir_in,filesep,'EpochData'];
if ~exist(dir_out)
    mkdir(dir_out)
end


% if nargin < 5 || isempty(elecs)
%     elecs = setdiff(1:globalVar.nchan,globalVar.refChan);
% end

% load trialinfo
load([dirs.result_root,filesep,project_name,filesep,sbj_name,filesep,bn,filesep,'trialinfo_',bn,'.mat'])
% Select only trials that are not rest
% trialinfo = trialinfo(~strcmp(trialinfo.condNames, 'rest'),:);


if strcmp(epoch_params.locktype,'stim')
    lockevent = trialinfo.allonsets(:,1);
elseif strcmp(epoch_params.locktype,'resp')
    lockevent = trialinfo.RT_lock;
else
    lockevent = [];
end

if sep_bl
    if strcmp(epoch_params.blc.locktype,'stim')
        bl_lockevent = trialinfo.allonsets(:,1);
    elseif strcmp(epoch_params.blc.locktype,'resp')
        bl_lockevent = trialinfo.RT_lock;
    else
        bl_lockevent = [];
    end
end

%% Get HFO bad trials:
pTS = globalVar.pathological_event_bipolar_montage;
[bad_epochs_HFO, bad_indices_HFO] = exclude_trial(pTS.ts,pTS.channel, lockevent, globalVar.channame, epoch_params.bef_time, epoch_params.aft_time, globalVar.iEEG_rate);
% Put the indices to the final sampling rate
bad_indices_HFO = cellfun(@(x) round(x./(globalVar.iEEG_rate)), bad_indices_HFO, 'UniformOutput',false); %%% CHECK THAT
% bad_indices_HFO = cellfun(@(x) round(x./(globalVar.iEEG_rate/globalVar.fs_comp)), bad_indices_HFO, 'UniformOutput',false);

%% Per electrode

%% Load data type of choice
% load(sprintf('%s/%siEEG%s_%.2d.mat',dir_in,datatype,bn,el));
load(sprintf('%s/%siEEG%s_%.2d.mat',dir_in,freq_band,bn,el));

%% Load Common Average data for bad epochs detection
data_CAR_tpm = load(sprintf('%s/CARiEEG%s_%.2d.mat',globalVar.CARData,bn,el));

% Plug channel info
data_CAR.wave = data_CAR_tpm.data.wave;
data_CAR.freqs = data.freqs;
data_CAR.wavelet_span = data.wavelet_span;
data_CAR.fsample = data_CAR_tpm.data.fsample;
data_CAR.label = data.label;
clear data_CAR_tpm

%% Epoch Common Average
ep_data_CAR = EpochData(data_CAR,lockevent,epoch_params.bef_time,epoch_params.aft_time);
data_CAR.wave = ep_data_CAR.wave;
data_CAR.time = ep_data_CAR.time;
clear ep_data_CAR

%% Epoch data type of choice
if sep_bl
    bl_data = EpochData(data,bl_lockevent,epoch_params.blc.win(1),epoch_params.blc.win(2));
end
ep_data = EpochData(data,lockevent,epoch_params.bef_time,epoch_params.aft_time);

fields = fieldnames(ep_data);
for fi = 1:length(fields)
    data.(fields{fi})=ep_data.(fields{fi});
end

% data.wave = ep_data.wave;
% data.time = ep_data.time;
clear ep_data
data.trialinfo = trialinfo;
ntrials = size(data.trialinfo,1);

%% Epoch rejection

% Su method 1: reject based on spikes in LF and HF components of signal
[be.bad_epochs_raw_LFspike, filtered_beh,spkevtind,spkts_raw_LFspike] = LBCN_filt_bad_trial(data_CAR.wave',data_CAR.fsample);
% Amy method: reject based on outliers of the raw signal and jumps (i.e.
% difference between consecutive data points)
[be.bad_epochs_raw_jump, badinds_jump] = epoch_reject_raw(data_CAR.wave,thr_raw,thr_diff);
% Su method 2: reject based on spikes in HF component of signal
[be.bad_epochs_raw_HFspike, filtered_beh,spkevtind,spkts_raw_HFspike] = LBCN_filt_bad_trial_noisy(data_CAR.wave',data_CAR.fsample);

ds = data_CAR.fsample/data.fsample; % how much spectral/HFB data was downsampled relative to CAR data

if strcmp(datatype,'Spec')
    %if spectral data, average across frequency dimension before epoch rejection
    [be.bad_epochs_spec_HFspike, filtered_beh,spkevtind,spkts_spec_HFspike] = LBCN_filt_bad_trial(squeeze(nanmean(abs(data.wave),1))',data.fsample);
else % CAR or HFB (i.e. 1 frequency)
    [be.bad_epochs_spec_HFspike, filtered_beh,spkevtind,spkts_spec_HFspike] = LBCN_filt_bad_trial(data.wave',data.fsample);
end

% Organize bad indices
for i = 1:size(spkts_raw_LFspike,2)
    bad_inds_raw_LFspike{i,1} = find(spkts_raw_LFspike(:,i) == 1);
    bad_inds_raw_LFspike{i,1} = setdiff(unique(floor(bad_inds_raw_LFspike{i,1}/ds)),0); % convert inds to downsampled inds
    bad_inds_raw_HFspike{i,1} = find(spkts_raw_HFspike(:,i) == 1);
    bad_inds_raw_HFspike{i,1} = setdiff(unique(floor(bad_inds_raw_HFspike{i,1}/ds)),0); % convert inds to downsampled inds
    bad_inds_raw_jump{i,1} = badinds_jump.all{i};
    bad_inds_raw_jump{i,1} = setdiff(unique(floor(bad_inds_raw_jump{i,1}/ds)),0); % convert inds to downsampled inds
    bad_inds_spec_HFspike{i,1} = find(spkts_spec_HFspike(:,i) == 1);
end



%% Update trailinfo and globalVar with bad trials and bad indices
data.trialinfo.bad_epochs_raw_LFspike = be.bad_epochs_raw_LFspike';
data.trialinfo.bad_epochs_raw_HFspike = be.bad_epochs_raw_HFspike';
data.trialinfo.bad_epochs_raw_jump = be.bad_epochs_raw_jump;
data.trialinfo.bad_epochs_spec_HFspike = be.bad_epochs_spec_HFspike';

bad_epochs_HFO_tmp = zeros(size(data.trialinfo,1),1,1);
bad_epochs_HFO_tmp(bad_epochs_HFO{el}) = 1;
data.trialinfo.bad_epochs_HFO = logical(bad_epochs_HFO_tmp);

data.trialinfo.bad_epochs = data.trialinfo.bad_epochs_raw_LFspike | data.trialinfo.bad_epochs_raw_HFspike | data.trialinfo.bad_epochs_raw_jump ...
    | data.trialinfo.bad_epochs_spec_HFspike | data.trialinfo.bad_epochs_HFO;

data.trialinfo.bad_inds_raw_LFspike = bad_inds_raw_LFspike;
data.trialinfo.bad_inds_raw_HFspike = bad_inds_raw_HFspike;
data.trialinfo.bad_inds_raw_jump = bad_inds_raw_jump;
data.trialinfo.bad_inds_spec_HFspike = bad_inds_spec_HFspike;

% data.trialinfo.bad_inds_raw = bad_inds_raw; % based on the raw signal
data.trialinfo.bad_inds_HFO = bad_indices_HFO(:,el); % based on spikes in the raw signal

data.trialinfo.bad_inds = cell(ntrials,1);
for ui = 1:ntrials
    bad_inds_all = union_several(data.trialinfo.bad_inds_raw_LFspike{ui,:},data.trialinfo.bad_inds_raw_HFspike{ui,:},data.trialinfo.bad_inds_raw_jump{ui,:},...
        data.trialinfo.bad_inds_spec_HFspike{ui,:},data.trialinfo.bad_inds_HFO{ui,:});
    data.trialinfo.bad_inds{ui} = bad_inds_all(:)';
    data.trialinfo.bad_inds{ui} = setdiff(data.trialinfo.bad_inds{ui},0);
end


%% Inspect bad epochs
be.bad_epochs_HFO = data.trialinfo.bad_epochs_HFO;
%     InspectBadEpochs(bad_epochs_raw, spkevtind, spkts, data_CAR.wave', data.fsample);

CompareBadEpochs(be, data_CAR, data, datatype, bn, el, globalVar)

%% Run baseline correction (either calculate from data if locktype = stim or uses these values when locktype = 'resp')
if epoch_params.blc.run
    if sep_bl
        data_blc = BaselineCorrect(data,bl_data,epoch_params);
    else
        data_blc = BaselineCorrect(data,epoch_params.blc.win,epoch_params);
    end
    data.wave = data_blc.wave;
    
    % store the phase separately for spectral data
    if strcmp(datatype,'Spec')
        data.phase = data_blc.phase;
    end
end

%% Update data structure
% data.label = globalVar.channame{el};
% if strcmp(datatype,'CAR')
%     data.fsample = globalVar.iEEG_rate;
% else
%     data.fsample = globalVar.iEEG_rate; %%% here again.
% end

% Naming specs based on the epoching parameters
if epoch_params.blc.run == true
    bl_tag = 'bl_corr_';
else
    bl_tag = [];
end
fn_out = sprintf('%s/%siEEG_%slock_%s%s_%.2d.mat',dir_out,freq_band,epoch_params.locktype,bl_tag,bn,el);
save(fn_out,'data')
disp(['Data epoching: Block ', bn, ' ' bl_tag,' Elec ',num2str(el)])


%% save updated globalVar (with bad epochs)
% fn = [dirs.data_root,'/OriginalData/',sbj_name,'/global_',project_name,'_',sbj_name,'_',bn,'.mat'];
% save(fn,'globalVar')

end


