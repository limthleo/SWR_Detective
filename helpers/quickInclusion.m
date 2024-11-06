function [inclvec, inclDC] = quickInclusion(data_lfp, data_mov, SR, params, flag, figflag)
% quickInclusion - Identifies and marks segments for inclusion based on movement and DC artifact detection.
%   This function processes local field potential (LFP) and movement data to identify periods of minimal movement 
%   and flag sections with DC artifacts. The resulting inclusion vector (inclvec) is filtered based on movement 
%   thresholds and minimum duration requirements. Optionally, the user can manually mark DC artifact regions via a GUI.
%
%   Inputs:
%   - data_lfp : Vector of raw LFP data to evaluate for inclusion
%   - data_mov : Vector of movement data, used to determine periods of minimal movement
%   - SR : Sampling rate of the LFP and movement data in Hz
%   - params : Struct containing parameters for inclusion criteria:
%       - movthresh : Threshold for movement detection (values below this threshold indicate minimal movement)
%       - movmindur : Minimum duration (in samples) for continuous inclusion
%   - flag : Logical flag; if true, invokes a GUI to manually mark DC artifacts
%   - figflag : Logical flag; if true, generates a figure for visualization
%
%   Outputs:
%   - inclvec : Logical vector indicating periods of minimal movement based on threshold and duration criteria
%   - inclDC : Logical vector marking sections with DC artifacts (if flag is true, regions are selected by GUI)

% Handle optional figflag and flag arguments
if nargin < 6
    figflag = false;
end
if nargin < 5
    flag = false;
end

% Step 1: Detect minimal movement periods based on movement threshold
inclvec = abs(data_mov) < params.movthresh;  % Mark segments below movement threshold

% Step 2: Remove short periods of minimal movement that don't meet minimum duration criteria
diffvec = diff([0; inclvec; 0]);
starts = find(diffvec == 1); 
ends = find(diffvec == -1) - 1;

% Filter out segments shorter than movmindur
for i = 1:length(starts)
    if ends(i) - starts(i) + 1 <= params.movmindur
        inclvec(starts(i):ends(i)) = false;
    end
end

% Step 3: Optionally, allow manual DC artifact marking via GUI
if flag
    inclDC = selectWinGUI(data_lfp);  % GUI-based artifact marking
    inclDC = ~inclDC;  % Convert to logical inclusion vector for DC artifact regions
else
    inclDC = false(size(inclvec));
end

% Step 4: Optional visualization of LFP, movement, and inclusion vectors
if figflag
    t_vals = (0:1/SR:(length(data_lfp)-1)/SR)';  % Time vector for plotting
    printFig(t_vals, data_lfp, data_mov, inclvec, inclDC);  % Display inclusion results
end

end

function printFig(t_vals, data_lfp, data_mov, inclvec, inclDC)
% printFig - Visualizes LFP and movement traces, marking detected DC artifacts and periods of minimal movement.
%   This function creates a figure showing:
%     1. LFP trace with DC artifact sections marked in red
%     2. Movement trace with minimal movement sections highlighted in green

    f = figure('WindowState', 'maximized');
    tl = tiledlayout(f, 2, 1);
    ax = gobjects(1, 2);

    % Plot LFP trace with DC artifact regions in red
    ax(1) = nexttile(tl);
    lfpremdc = data_lfp; 
    lfpremdc(inclDC) = NaN;  % Mark DC artifact regions as NaN for visualization
    hold on
    plot(t_vals, data_lfp, 'b', 'DisplayName', 'Non-interpolated LFP')
    plot(t_vals, lfpremdc, 'r', 'DisplayName', 'DC Artifact')
    hold off
    title('LFP Trace with DC Artifact Marking (Red)')
    ylabel('LFP (V)')
    xlabel('Time (s)')
    legend

    % Plot movement trace with minimal movement regions highlighted in green
    ax(2) = nexttile(tl);
    plot(t_vals, data_mov, 'r', 'DisplayName', 'Movement Data')
    hold on
    % Highlight regions with minimal movement (inclvec == true)
    xregion(t_vals(diff([0; inclvec; 0]) == 1), ...
            t_vals(find(diff([0; inclvec; 0]) == -1) - 1), 'FaceColor', 'g')
    hold off
    title('Movement Trace with Minimal Movement Highlighted (Green)')
    ylabel('Velocity (cm/s)')
    xlabel('Time (s)')
    legend

    % Link x-axes for synchronized zooming and panning
    linkaxes(ax, 'x')
end
