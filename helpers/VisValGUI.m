function efig = VisValGUI(fdata_lfp, data_lfp, inclvec, rpwin, SR, manvalid, xRange, yOffset)
% VisValGUI - Visualize and validate hippocampal sharp-wave ripples (SWRs)
%   This function creates an interactive GUI for manually inspecting and
%   validating SWR events based on LFP data. Users can scroll through time,
%   view frequency scalograms, and see filtered and raw LFP traces.
%
%   Parameters:
%   - fdata_lfp : Array of filtered LFP data
%   - data_lfp  : Array of raw LFP data
%   - inclvec   : Logical vector indicating included regions
%   - rpwin     : Matrix defining ripple start, peak, and end times (N x 3)
%   - SR        : Sampling rate (Hz)
%   - manvalid  : (Optional) Logical array for manually validated events
%   - xRange    : (Optional) Display range in seconds
%   - yOffset   : (Optional) Offset factor for y-axis in plots
%
%   Returns:
%   - efig : Handle to the created uifigure

if nargin < 8 || isempty(yOffset), yOffset = 1; end
if nargin < 7 || isempty(xRange), xRange = 3; end
if nargin < 6 || isempty(manvalid), manvalid = true(size(rpwin, 1), 1); end

%% Initialize Variables
% Define time values based on sampling rate
t_vals = (1:length(fdata_lfp)) / SR;
rpidx = rpwin(:,2);
rplim = [rpwin(:,1), rpwin(:,3)];

%% Create General UI Window
% Initialize the figure and layout
efig = uifigure("WindowState", "maximized");
efig.Name = 'SWR Vision: Sanity Check';
efig.CloseRequestFcn = @closeFunction;
efig.KeyPressFcn = @keyPressFcn;

% Create grid layout for UI components
egrid = uigridlayout(efig);
egrid.RowHeight = {50, '1x', '1x', '1x', 50};
egrid.ColumnWidth = {'1x', '1x', '1x'};

%% Populate UI Window
% Title display for current SWR event
titleLabel = uilabel(egrid);
titleLabel.Text = 'On Display: SWR #';
titleLabel.FontSize = 16;
titleLabel.FontWeight = 'bold';
titleLabel.Layout.Row = 1;
titleLabel.Layout.Column = 1;

% Time and SWR number input fields with callback functions
timePanel = uipanel(egrid);
timePanel.Layout.Row = 1;
timePanel.Layout.Column = 2;
timeLabel = uilabel(timePanel);
timeLabel.Text = 'time (s):';
timeInput = uieditfield(timePanel, 'numeric');
timeInput.ValueChangedFcn = @(src, event) jumpTime();

swrPanel = uipanel(egrid);
swrPanel.Layout.Row = 1;
swrPanel.Layout.Column = 3;
swrLabel = uilabel(swrPanel);
swrLabel.Text = 'SWR #:';
swrInput = uieditfield(swrPanel, 'numeric');
swrInput.ValueChangedFcn = @(src, event) jumpEvent();

%% Define Axes for Scalogram and LFP Traces
scax = uiaxes(egrid);
ylabel(scax, 'Frequency (Hz)');
scax.Layout.Row = 2;
scax.Layout.Column = [1 3];

flfpax = uiaxes(egrid);
ylabel(flfpax, 'Filtered LFP (V)');
flfpax.Layout.Row = 3;
flfpax.Layout.Column = [1 3];

rlfpax = uiaxes(egrid);
ylabel(rlfpax, 'Raw LFP (V)');
rlfpax.Layout.Row = 4;
rlfpax.Layout.Column = [1 3];

%% Generate Indices for SWR Windows
swrInd = win2ind(rplim);
swrNum = zeros(length(swrInd), 1);
TswrInd = win2ind(rplim(manvalid,:));
FswrInd = win2ind(rplim(~manvalid,:));
exclInd = find(~inclvec);

%% Initialize Plot with Current Time Window
current_t = 1; 
xRange = floor(xRange * SR);
updatePlots();

%% Scroll Bar for Time Navigation
scroll = uislider(egrid);
scroll.Limits = [1, length(t_vals) - xRange + 1];
scroll.Value = current_t;
scroll.ValueChangedFcn = @(src, event) updateT();
scroll.Layout.Row = 5;
scroll.Layout.Column = [1 3];

%% Nested Functions

% Update plots with the current time window
    function updatePlots()
        this_win = current_t:(current_t + xRange - 1);
        t_win = t_vals(this_win);

        % Frequency scalogram
        if ~isempty(scax.Children)
            delete(scax.Children);
        end
        hold(scax, 'on')
        [cfs, freqs] = cwt(fdata_lfp(this_win), 'amor', SR);
        h = pcolor(scax, t_win, freqs, abs(cfs));
        set(h, 'EdgeColor', 'none')
        ylim(scax, [min(freqs) max(freqs)])
        xlim(scax, [t_win(1) t_win(end)])
        hold(scax, 'off')

        % Filtered LFP trace with highlighted regions
        if ~isempty(flfpax.Children)
            delete(flfpax.Children);
        end
        hold(flfpax, 'on')
        flfpplot = fdata_lfp(this_win);
        plot(flfpax, t_win, flfpplot, 'k')
        displayWindows(flfpax, exclInd, this_win, 'r');
        displayWindows(flfpax, TswrInd, this_win, 'g');
        displayWindows(flfpax, FswrInd, this_win, 'y');
        yoffset = range(flfpplot) * yOffset;
        ylim(flfpax, [min(flfpplot)-yoffset max(flfpplot)+yoffset]);
        xlim(flfpax, [t_win(1) t_win(end)]);
        hold(flfpax, 'off')

        % Raw LFP trace with highlighted regions
        if ~isempty(rlfpax.Children)
            delete(rlfpax.Children);
        end
        hold(rlfpax, 'on')
        rlfpplot = data_lfp(this_win);
        plot(rlfpax, t_win, rlfpplot, 'k')
        displayWindows(rlfpax, exclInd, this_win, 'r');
        displayWindows(rlfpax, TswrInd, this_win, 'g');
        displayWindows(rlfpax, FswrInd, this_win, 'y');
        yoffset = range(rlfpplot) * yOffset;
        ylim(rlfpax, [min(rlfpplot)-yoffset max(rlfpplot)+yoffset]);
        xlim(rlfpax, [t_win(1) t_win(end)]);
        hold(rlfpax, 'off')

        % Update the slider and title
        scroll.Value = current_t;
        updateTitle(this_win)
    end

% Updates time with slider
    function updateT()
        current_t = floor(scroll.Value);
        updatePlots();
    end

% Updates title with displayed SWR numbers
    function updateTitle(window)
        [~, common_indices] = intersect(swrInd, window);
        if ~isempty(common_indices)
            thisidx = unique(swrNum(common_indices));
            titleLabel.Text = ['On Display: SWR #' vectorToString(thisidx)];
        else
            titleLabel.Text = 'On Display: SWR #';
        end
    end

% Jumps to a specific time
    function jumpTime()
        current_t = floor(timeInput.Value * SR);
        current_t = min(max(current_t, 1), length(t_vals) - xRange + 1);
        updatePlots();
    end

% Jumps to a specific SWR event
    function jumpEvent()
        current_e = min(ceil(swrInput.Value), size(rpidx, 1));
        scroll.Value = max(1, min(rpidx(current_e) - floor(xRange / 2), length(t_vals) - xRange + 1));
        updateT();
    end

% Display regions for different SWR states
    function displayWindows(axes, indices, window, colour)
        common_indices = intersect(indices, window);
        if ~isempty(common_indices)
            start_indices = common_indices([true; diff(common_indices) > 1]);
            end_indices = common_indices([diff(common_indices) > 1; true]);
            for k = 1:length(start_indices)
                patchHandle = xregion(axes, [t_vals(start_indices(k)), t_vals(end_indices(k))], ...
                    'FaceColor', colour, 'FaceAlpha', 0.2);
                set(patchHandle, 'ButtonDownFcn', @windowClickCallback);
            end
        end
    end

% Toggle manual validation status on click
    function windowClickCallback(src, ~)
        thisInd = src.Value * SR;
        thisNum = intersect(unique(swrNum(swrInd >= thisInd(1))), unique(swrNum(swrInd <= thisInd(2))));
        manvalid(thisNum) = ~manvalid(thisNum);
        updatePlots();
    end

% Close function with prompt for saving manual validation
    function closeFunction(~, ~)
        selection = uiconfirm(efig, 'Do you want to save the manual validation?', ...
                              'Close Request', ...
                              'Options', {'Yes', 'No', 'Cancel'}, ...
                              'DefaultOption', 1, 'CancelOption', 3);
        if strcmp(selection, 'Yes')
            assignin('base', 'manvalid', manvalid);
            disp(['Validated ', num2str(sum(manvalid)), ' out of ', num2str(length(manvalid)), ' events!']);
        end
        if ~strcmp(selection, 'Cancel')
            delete(efig);
        end
    end
end
