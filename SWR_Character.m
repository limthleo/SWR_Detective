%%              Wavelet-Based SWR Characterisation                %%
% After detecting and validating SWR events, characterise each validated
% ripple events through a wavelet-based approach.
clear; clc; close all
addpath % path to the helpers ... 
cd % path to the data foler...
verbose = true; figflag = true; % turn on to display messages and show figures respectively

%% 1. Load the Dataset
% Load the dataset
[filename, path] = uigetfile('.mat');
load(path+string(filename))

% Unpack the previously validated event features
unpack_struct(Data.SWR);
SR = Data.nFs;              

% Only the window and duration will be taken;
% the frequency and power will be recalculated more precisely.
rpwin = rpwin(manvalid, :);
rpdur = rpdur(manvalid, :);

%% 2. Wavelet transform the dataset (this may take a few minutes)
wavfreqs = 80:0.25:250;                     % ripple frequencies to wavelet transform (Hz)
coeffmat = wavconv(data_lfp, wavfreqs, params.wavcycs, SR);
coeffpow = abs(coeffmat).^2; coeffpha = angle(coeffmat);

%% 3. Characterise each ripples' features
% Initialise the ripple features
instfreq = cell(size(rpwin,1), 1);          % nx1 cell array of instantaneous ripple frequency (Hz)
instphase = cell(size(rpwin,1), 1);         % nx1 cell array of instantaneous ripple phase (rad)
domfreq = zeros(size(rpwin,1), 1);          % nx1 vector of ripple dominant frequency (Hz)
entropy = zeros(size(rpwin,1), 1);          % nx1 vector of ripple entropy (bits)
rppow = zeros(size(rpwin,1), 1);            % nx1 vector of ripple power (AU)

% Loop through each ripple and fill the feature arrays
for r = 1:size(rpwin,1)
    % Temporary wavelet power/phase plots
    tmppower = coeffpow(:, rpwin(r,1):rpwin(r,3));
    tmpphase = coeffpha(:, rpwin(r,1):rpwin(r,3));
    rppow(r) = max(tmppower, [], "all"); % ripple power
    [~, maxind] = max(max(tmppower, [], 1));
    rpwin(r,2) = rpwin(r,1) + maxind - 1; % adjust peak index to peak ripple power
    % Get the statistical distribution of frequencies
    pf = mean(tmppower, 2);
    pf = pf./sum(pf);
    [~, thisfreq]= max(pf); domfreq(r) = wavfreqs(thisfreq); % mode over frequencies
    entropy(r) = -sum(pf.*log2(pf));
    % Get the instantaneous frequency and phase
    [~, maxind] = max(tmppower);
    instfreq{r} = wavfreqs(maxind);
    instphase{r} = tmpphase(sub2ind(size(tmpphase), maxind, 1:size(tmpphase,2)));
end

rpiei = [diff(rpwin(:,2))/SR; NaN];         % nx1 vector of forward ripple inter-event interval (s)

%% 4. Save the results
% Save the results to a field named "valid_SWR"
Data.valid_SWR.instfreq = instfreq;
Data.valid_SWR.instphase = instphase;
Data.valid_SWR.rpwin = rpwin;
Data.valid_SWR.rpfeats = array2table([rpiei rpdur domfreq entropy rppow], ...
    "VariableNames", {'IEI (s)', 'Duration (s)', 'Frequency (Hz)', 'Entropy (bits)', 'Power (AU)'});

save(path+string(filename), "Data")
if verbose
    disp("Finished saving to "+path+string(filename)+"!")
end
