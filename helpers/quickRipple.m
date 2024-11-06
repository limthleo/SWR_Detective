function [rpwin, rpdur, rppow, rpfrq] = quickRipple(fdata_lfp, SR, inclvec, params, verbose)
% quickRipple - Detects ripple events in LFP data using wavelet analysis.
%   This function uses wavelet transforms to detect ripples in the local field 
%   potential (LFP) data and applies several thresholds to identify, refine, and 
%   validate ripple events based on power, frequency, duration, and cycle constraints.
%
%   Inputs:
%   - fdata_lfp : Vector of LFP data to analyze
%   - SR : Sampling rate of the LFP data in Hz
%   - inclvec : Logical vector specifying inclusion zones in the data
%   - params : Struct of parameters with fields:
%       - rpfreqs : Vector of frequencies for the wavelet analysis
%       - wavcycs : Number of wavelet cycles
%       - eventthresh : Threshold (in MAD) above median for ripple event detection
%       - boundthresh : Threshold for bounding boxes (in MAD)
%       - mergethresh : Maximum gap between ripples to allow merging
%       - rpdurmin : Minimum allowed ripple duration (s)
%       - rpdurmax : Maximum allowed ripple duration (s)
%       - mincyc : Minimum ripple cycles to consider as valid
%   - verbose : Logical flag for detailed output display
%
%   Outputs:
%   - rpwin : N-by-3 matrix with start, peak, and end indices for each detected ripple
%   - rpdur : Vector of ripple durations (s)
%   - rppow : Vector of maximum ripple power values
%   - rpfrq : Vector of ripple frequencies corresponding to peak power

% Step 1: Wavelet transform of the LFP data
coeffmat = wavconv(fdata_lfp, params.rpfreqs, params.wavcycs, SR);
coeffamp = abs(coeffmat);  % Amplitude of wavelet coefficients
coeffpha = angle(coeffmat);  % Phase of wavelet coefficients

% Step 2: Define detection thresholds based on amplitude statistics
evthresh = median(coeffamp(:, inclvec), 'all') + ...
    params.eventthresh * mad(coeffamp(:, inclvec), 1, 'all');
bthresh = median(coeffamp(:, inclvec), 'all') + ...
    params.boundthresh * mad(coeffamp(:, inclvec), 1, 'all');

% Step 3: Detect ripple events with region-based approach
bracket = regionprops(coeffamp >= bthresh, coeffamp, ...
    "MaxIntensity", "BoundingBox", "WeightedCentroid");
bracket = bracket([bracket.MaxIntensity] >= evthresh, :);
peakidx = reshape([bracket.WeightedCentroid], 2, []).';  % Peak indices
boundidx = round(reshape([bracket.BoundingBox], 4, []).');  % Bound indices
rpwin = [boundidx(:, 1), round(peakidx(:, 1)), boundidx(:, 1) + boundidx(:, 3)];  % Ripple windows
rpdur = (rpwin(:, 3) - rpwin(:, 1)) / SR;  % Duration of ripples
rppow = [bracket.MaxIntensity]';  % Power at peaks
rpfrq = interp1(1:length(params.rpfreqs), params.rpfreqs, peakidx(:, 2), 'linear');  % Frequency at peaks

% Step 4: Exclude ripples outside inclusion zones
if verbose
    disp(sum(~any(inclvec(rpwin), 2)) + "/" + size(rpwin, 1) + " were found in the exclusion zone.")
end
% Filter out events not entirely within inclusion zone
rpdur = rpdur(~any(inclvec(rpwin) == 0, 2));
rppow = rppow(~any(inclvec(rpwin) == 0, 2));
rpfrq = rpfrq(~any(inclvec(rpwin) == 0, 2));
rpwin = rpwin(~any(inclvec(rpwin) == 0, 2), :);

% Step 5: Merge ripples within specified distance
mergebin = [(rpwin(2:end, 1) - rpwin(1:end-1, 3)) <= params.mergethresh; false];
mergestruct = bwconncomp(mergebin);
for r = 1:length(mergestruct.PixelIdxList)
    startmerge = min(mergestruct.PixelIdxList{r});
    stopmerge = max(mergestruct.PixelIdxList{r}) + 1;
    % Update the merged ripple's attributes
    [rppow(startmerge), maxpow] = max(rppow(startmerge:stopmerge));
    rpwin(startmerge, :) = [min(rpwin(startmerge:stopmerge, 1)), ...
                            rpwin(startmerge + maxpow - 1, 2), ...
                            max(rpwin(startmerge:stopmerge, 3))];
    rpdur(startmerge) = (rpwin(startmerge, 3) - rpwin(startmerge, 1)) / SR;
    rpfrq(startmerge) = rpfrq(startmerge + maxpow - 1);
    % Set other entries in merge group to NaN for later removal
    rpwin(startmerge+1:stopmerge, :) = NaN;
    rppow(startmerge+1:stopmerge) = NaN;
    rpdur(startmerge+1:stopmerge) = NaN;
    rpfrq(startmerge+1:stopmerge) = NaN;
end
% Remove NaN entries from merged results
rpwin = rmmissing(rpwin);
rppow = rmmissing(rppow);
rpdur = rmmissing(rpdur);
rpfrq = rmmissing(rpfrq);
if verbose
    disp(sum(mergebin) + length(mergestruct.PixelIdxList) + " events were merged into " + length(mergestruct.PixelIdxList) + " events.")
end

% Step 6: Exclude ripples not meeting duration constraints
if verbose
    disp(sum(rpdur < params.rpdurmin | rpdur > params.rpdurmax) + "/" + size(rpwin, 1) + " did not meet the duration threshold.")
end
% Apply duration threshold filtering
valid_dur = rpdur >= params.rpdurmin & rpdur <= params.rpdurmax;
rppow = rppow(valid_dur);
rpfrq = rpfrq(valid_dur);
rpwin = rpwin(valid_dur, :);
rpdur = rpdur(valid_dur);

% Step 7: Exclude ripples not meeting cycle threshold
cycbin = false(size(rpwin, 1), 1);
for r = 1:size(rpwin, 1)
    tmpamp = coeffamp(:, rpwin(r, 1):rpwin(r, 3));
    tmppha = coeffpha(:, rpwin(r, 1):rpwin(r, 3));
    [~, tmp] = max(tmpamp);  % Identify peak
    phase_vals = tmppha(sub2ind(size(tmppha), tmp, 1:size(tmppha, 2)));
    phase_unwrapped = unwrap(phase_vals);
    % Check if cycle threshold is met
    cycbin(r) = (phase_unwrapped(end) - phase_unwrapped(1)) / (2 * pi) < params.mincyc;
end
if verbose
    disp(sum(cycbin) + "/" + size(rpwin, 1) + " did not meet the minimum cycle threshold.")
end
% Filter out entries not meeting cycle threshold
rpdur = rpdur(~cycbin);
rppow = rppow(~cycbin);
rpfrq = rpfrq(~cycbin);
rpwin = rpwin(~cycbin, :);

% Display final count of detected ripples if verbose
if verbose
    disp("Overall, " + size(rpwin, 1) + " potential ripple events were detected.")
end

end
