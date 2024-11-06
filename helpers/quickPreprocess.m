function fdata_lfp = quickPreprocess(data_lfp, interpvec, SR, params, figflag)
% quickPreprocess - Preprocesses local field potential (LFP) data.
%   This function preprocesses LFP data by handling exclusions, offset corrections, 
%   interpolation, padding, filtering, and optional visualization. It removes powerline 
%   noise, high-frequency noise, and low-frequency artifacts to prepare the LFP signal 
%   for further analysis.
%
%   Inputs:
%   - data_lfp : Vector of raw LFP data to preprocess
%   - interpvec : Logical vector specifying segments to include for interpolation
%   - SR : Sampling rate of the LFP data in Hz
%   - params : Struct containing filter parameters:
%       - noise_freqs : Vector of frequencies to notch filter
%       - frem : Width around each noise frequency to filter
%       - hpcutoff : High-pass cutoff frequency to remove DC components
%       - lpcutoff : Low-pass cutoff frequency to reduce artifacts
%   - figflag : Logical flag to display a figure comparing the raw and preprocessed data
%
%   Output:
%   - fdata_lfp : Preprocessed LFP data

% Handle optional figflag argument
if nargin < 5
    figflag = false;
end

% Step 1: Set NaNs for excluded segments based on interpvec
fdata_lfp = data_lfp;
fdata_lfp(~interpvec) = NaN;

% Step 2: Patch together non-excluded segments
tmp = diff([0; interpvec; 0]);
segments_start = find(tmp == 1); 
segments_end = find(tmp == -1) - 1;
for i = 2:length(segments_start)
    offset = fdata_lfp(segments_start(i)) - fdata_lfp(segments_end(i-1));
    fdata_lfp(segments_start(i):end) = fdata_lfp(segments_start(i):end) - offset;
end

% Step 3: Interpolate over NaN values to fill excluded sections
fdata_lfp = fillmissing(fdata_lfp, 'linear', 'EndValues', 'nearest');

% Step 4: Pad edges to reduce filter boundary effects
padlen = round(0.1 * length(fdata_lfp));  % Padding length is 10% of the data length
padsig = [flip(fdata_lfp(2:padlen+1)); fdata_lfp; flip(fdata_lfp(end-padlen:end-1))];

% Step 5: Apply notch filter to remove powerline noise
for f = 1:length(params.noise_freqs)
    [z, p, k] = butter(10, [params.noise_freqs(f) - params.frem(f), ...
                            params.noise_freqs(f) + params.frem(f)] * 2 / SR, 'stop');
    [sos, g] = zp2sos(z, p, k);
    padsig = filtfilt(sos, g, padsig);  % Apply zero-phase filter
end

% Step 6: Apply high-pass filter to remove low-frequency components (DC trend)
[sb, sa] = butter(4, params.hpcutoff * 2 / SR, 'high');
padsig = filtfilt(sb, sa, padsig);

% Step 7: Apply low-pass filter to remove high-frequency noise
[sb, sa] = butter(8, params.lpcutoff * 2 / SR, 'low');
padsig = filtfilt(sb, sa, padsig);

% Step 8: Remove padding to return processed data to original length
fdata_lfp = padsig(padlen+1:end-padlen);

% Optional: Display figure comparing raw and preprocessed data if figflag is true
if figflag
    t_vals = (0:1/SR:(length(data_lfp)-1)/SR)';  % Time vector for visualization
    printFig(t_vals, data_lfp, fdata_lfp, SR);  % Call helper function to display figure
end

end

function printFig(t_vals, data_lfp, fdata_lfp, SR)
% printFig - Helper function to display comparisons of raw and preprocessed LFP data.
%   This function creates a figure with two plots: the power spectra of the raw and 
%   preprocessed data, and the time-domain traces of the raw and preprocessed LFP signals.
    f = figure('WindowState', 'maximized');
    tl = tiledlayout(f, 2, 1);

    % Power spectrum comparison
    nexttile(tl)
    title('Power Spectrum Comparison')
    [pxx1, fq1] = pspectrum(data_lfp, SR);
    [pxx2, fq2] = pspectrum(fdata_lfp, SR);
    hold on
    plot(fq1, pow2db(pxx1), 'DisplayName', 'Raw Power Spectrum')
    plot(fq2, pow2db(pxx2), 'DisplayName', 'Preprocessed Power Spectrum')
    hold off
    xlabel('Frequency (Hz)')
    ylabel('Power (dB)')
    legend

    % LFP trace comparison
    nexttile(tl)
    title('LFP Trace Comparison')
    hold on
    plot(t_vals, data_lfp, 'g-', 'LineWidth', 0.6, 'DisplayName', 'Raw Trace')
    plot(t_vals, fdata_lfp, 'r-', 'LineWidth', 0.6, 'DisplayName', 'Preprocessed Trace')
    hold off
    xlabel('Time (s)')
    ylabel('LFP (V)')
    legend
end
