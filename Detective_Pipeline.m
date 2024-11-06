%%              Pipeline to Find Sharp Wave Ripples                %%
% Load LFP and velocity recordings and tweak the parameters to most
% realistically maximise true positive detection of sharp wave ripples.
clear; clc; close all
addpath % path to the helpers ... 
cd % path to the data foler...
verbose = true; figflag = true; % turn on to display messages and show figures respectively

%% 1. Preparations
% Load the dataset
[filename, path] = uigetfile('.mat');
load(path+string(filename))
fname = filename(1:end-4);

% Initialize the dataset
data_lfp    = Data.dspon_data(:, 2);                % LFP trace
data_mov    = Data.dspon_data(:,3);                 % Velocity trace
SR          = Data.nFs;                             % Sampling rate (Hz)
t_vals      = (0:1/SR:(length(data_lfp)-1)/SR)';    % Time trace
if verbose
    disp('The trace is '+string(t_vals(end))+' seconds long.')
end

%% 2. Build the inclusion vector
params.movthresh   = 0.5;                       % movement threshold (cm/s)
params.movmindur   = 3*SR;                      % minimum movement duration to count as movement-free

if ~isfield(Data.SWR, "interpvec")
    [inclvec, interpvec] = ...
        quickInclusion(data_lfp, data_mov, SR, params, true, figflag);
else
    inclvec = ...
        quickInclusion(data_lfp, data_mov, SR, params, false, figflag);
    interpvec = Data.SWR.interpvec;
end

%% 3. Preprocess the LFP trace
params.hpcutoff    = 0.3;                       % highpass cutoff to remove DC trend (Hz)
params.noise_freqs = 50*(1:7);                  % powerline noise frequencies (Hz)
params.frem        = 0.5*ones(1,7);             % frequency before and after noise frequencies to notch (Hz)
params.lpcutoff    = 400;                       % lowpass cutoff to minimise high-frequency noise (Hz)

fdata_lfp = ...
    quickPreprocess(data_lfp, interpvec, SR, params, figflag);

%% 4. Detect ripple events (may take a few minutes to load)
params.rpfreqs     = 80:250;                    % ripple frequencies to wavelet transform (Hz)
params.wavcycs     = 5;                         % wavelet cycles (#)
params.eventthresh = 15;                        % # MAD above median to detect events
params.boundthresh = 10;                        % # MAD above median to detect boundaries
params.mergethresh = round(0.020*SR);           % merge events within this distance (s)
params.rpdurmin    = 0.010;                     % minimum required ripple duration (s)
params.rpdurmax    = 0.500;                     % maximum required ripple duration (s)
params.mincyc      = 1.8;                       % minimum # of ripple cycles required

[rpwin, rpdur, rppow, rpfrq] = ...
    quickRipple(fdata_lfp, SR, inclvec&interpvec, params, verbose);

%% 5. Manually validate events
% Score each event based on ranking
scores = zeros(size(rpwin,1), 3);
scores(:,1) = arrayfun(@(x) find(sort(rppow, 'ascend') == x, 1, 'first'), rppow);
scores(:,2) = arrayfun(@(x) find(sort(abs(rpdur-0.05), 'descend') == x, 1, 'first'), abs(rpdur-0.05));
scores(:,3) = arrayfun(@(x) find(sort(abs(rpfrq-160), 'descend') == x, 1, 'first'), abs(rpfrq-160));
scores = sum(scores, 2);
scores = round(100*(scores-min(scores))./(max(scores)-min(scores))); % minmax normalization

% Check if a manual validation was already done with this structure
if isfield(Data.SWR, "manvalid")
    manvalid = Data.SWR.manvalid;
else
    manvalid = false(length(scores), 1);
end

% Manually validate each event
% De/select events to validate them (green for valid).
% Press 'A' to toggle between validating all events within the current page.
% Press 'F' to toggle between the raw and filtered traces.
manValidGUI(manvalid, data_lfp, fdata_lfp, rpwin, SR, fname, scores);

%% 6. Sanity Check (optional)
% An alternative manual validation GUI:
% It visualises events embedded within the entire trace to view them in context.
% Press LEFT/RIGHT arrow keys to move back/forward in time.
% Press SHIFT + LEFT/RIGHT to skip to the next event.
% Click on the event window to (un)validate them
% (Green: Valid, Yellow: Invalid).

VisValGUI(fdata_lfp, data_lfp, inclvec, rpwin, SR, manvalid);

%% 7. Save results to Datproc
% Save results to the structure within a field named 'SWR'
Data.SWR.data_lfp   = fdata_lfp;                % tx1 filtered LFP vector
Data.SWR.inclvec    = inclvec;                  % tx1 inclusion binary vector
Data.SWR.interpvec  = interpvec;                % tx1 non-interpolated binary vector
Data.SWR.scores     = scores;                   % nx1 vector of rank-based scores
Data.SWR.manvalid   = manvalid;                 % nx1 binary vector of valid events
Data.SWR.rpwin      = rpwin;                    % nx3 array of ripple start/peak/end indices
Data.SWR.rpdur      = rpdur;                    % nx1 vector of ripple durations (s)
Data.SWR.rppow      = rppow;                    % nx1 vector of ripple power (AU)
Data.SWR.rpfrq      = rpfrq;                    % nx1 vector of ripple frequency (Hz)
Data.SWR.params     = params;                   % parameter structure

save(path+string(filename), "Data")
if verbose
    disp("Finished saving to "+path+string(filename)+"!")
end