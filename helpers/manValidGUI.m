function mvfig = manValidGUI(manvalid, data_lfp, fdata_lfp, rpwin, SR, filename, scores, xRange, yOffset, flag)
% manValidGUI - Manual validation interface for reviewing detected sharp wave ripples (SWRs).
%   Displays LFP data with highlighted ripple windows, allowing the user to validate events 
%   by toggling them as valid or invalid. Includes a slider for navigating through pages of 
%   detected ripples and keyboard shortcuts for easier navigation.
%
%   Inputs:
%   - manvalid : Initial vector of manual validation flags (logical vector)
%   - data_lfp : Raw LFP data vector for displaying sharp wave ripples
%   - fdata_lfp : Filtered LFP data vector, shown optionally as specified by the `flag`
%   - rpwin : Matrix specifying the ripple windows; columns represent [start, peak, end] times (in samples)
%   - SR : Sampling rate of LFP data in Hz
%   - filename : String, file name for display on the interface
%   - scores : Vector of scores for each ripple, used to prioritize validation (sorted in descending order)
%   - xRange : Range (in seconds) for each plot window around ripple peaks
%   - yOffset : Offset factor for y-axis limits for each ripple plot, relative to amplitude
%   - flag : Logical, determines whether to sort ripples by score initially
%
%   Output:
%   - mvfig : Handle to the created UI figure for potential further customization
%
%   This function also enables in-GUI toggling of validation with mouse clicks and includes keyboard shortcuts:
%       - Left/Right arrows: Navigate pages
%       - 'a': Toggle batch highlight for the current page
%       - 'f': Toggle between raw and filtered LFP display

% Set default values for optional parameters
if nargin < 10, flag = true; end
if nargin < 9 || isempty(yOffset), yOffset = 0.7; end
if nargin < 8 || isempty(xRange), xRange = 0.6; end
if nargin < 7 || isempty(scores), scores = fliplr(1:length(manvalid)); end
if nargin < 6, filename = []; end

%% Initialize variables
t_vals = (1:length(data_lfp)) / SR;  % Time vector in seconds
rpidx = rpwin(:, 2);  % Ripple peak indices
rplim = [rpwin(:, 1), rpwin(:, 3)];  % Ripple start and end indices
halfwin = floor(xRange * SR / 2);  % Half window size in samples

%% Create the general UI window
mvfig = uifigure("WindowState", "maximized");
mvfig.Name = 'SWR: Manual Validation';
mvfig.CloseRequestFcn = @closeFunction;
mvfig.KeyPressFcn = @keyPressFunction;

mv_grid = uigridlayout(mvfig);
mv_grid.RowHeight = {25, '1x', '1x', '1x', 25};
mv_grid.ColumnWidth = {'1x', '1x', '1x', '1x'};

% Title label
titleLabel = uilabel(mv_grid, 'Text', sprintf('%s Manual Validation', filename), ...
                     'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
titleLabel.Layout.Row = 1; titleLabel.Layout.Column = [1 4];

% Create a 3x4 grid of axes for displaying SWR traces
axesHandles = gobjects(3, 4);
for i = 1:3
    for j = 1:4
        ax = uiaxes(mv_grid);
        ax.Layout.Row = i + 1;
        ax.Layout.Column = j;
        ax.Color = 'white';
        ax.HitTest = 'off';  % Disable interaction
        axesHandles(i, j) = ax;
    end
end

% Sort ripples by score if flag is true
if flag
    [scores, sorted_indices] = sort(scores, 'descend');
else
    sorted_indices = 1:length(scores);
end
manvalid = manvalid(sorted_indices);
rpidx = rpidx(sorted_indices); 
rplim = rplim(sorted_indices, :);
[~, refvec] = sort(sorted_indices);

n_pages = max(ceil(length(rpidx) / 12), 2);
slider = uislider(mv_grid, 'Value', 1, 'Limits', [1, n_pages], ...
    'ValueChangedFcn', @(src, ~) updateBatch(src.Value, flag));
slider.Layout.Row = 5; slider.Layout.Column = [1 4];

updateBatch(1, flag);  % Initial batch update

%% Functions
    function updateBatch(batch, flag)
        % updateBatch - Updates the displayed batch of SWRs based on current slider position
        firstSWR = (batch - 1) * 12 + 1;
        lastSWR = min(batch * 12, length(rpidx));
        
        if flag
            lfp = data_lfp;
        else
            lfp = fdata_lfp;
        end
    
        for idx = 1:12
            row = ceil(idx/4); col = idx - 4*(row-1);
            ax = axesHandles(row,col);
            if firstSWR + idx - 1 <= lastSWR
                s = firstSWR + idx - 1;
                window = max(1, rpidx(s) - halfwin):min(rpidx(s) + halfwin, length(lfp));
                plot(ax, t_vals(window), lfp(window), 'k', 'LineWidth', 0.2);
                hold(ax, 'on');
                xregion(ax, t_vals(rplim(s,1)), t_vals(rplim(s,2)), 'FaceColor', 'g', 'FaceAlpha', 0.2);
                xline(ax, t_vals(rpidx(s)), 'k--');
                hold(ax, 'off');
                xlim(ax, t_vals([window(1) window(end)]));
                traceRange = max(lfp(window)) - min(lfp(window));
                ylim(ax, [min(lfp(window)) - yOffset * traceRange, max(lfp(window)) + yOffset * traceRange]);
                ax.Title.String = sprintf('Ripple #%d, Score: %.2f', sorted_indices(s), scores(s));
                if manvalid(s)
                    ax.Color = [0.565, 0.933, 0.565];
                else
                    ax.Color = 'white';
                end
                ax.HitTest = 'on';  % Enable hit test for the axes
                ax.ButtonDownFcn = @(src, event) toggleValid(ax);
            else
                cla(ax);  % Clear the axes if there are no more ripples to show
                ax.Title.String = '';
                ax.HitTest = 'off';
                ax.Color = 'white';
            end
        end
    end

    function toggleValid(ax)
        % toggleValid - Toggles the validation status of the selected ripple
        [row, col] = find(axesHandles == ax);
        idx = (row - 1) * 4 + col;
        s = (slider.Value - 1) * 12 + idx; 
        if manvalid(s)
            manvalid(s) = false;
            ax.Color = 'white';
        else
            manvalid(s) = true;
            ax.Color = [0.565, 0.933, 0.565];
        end
    end

    function keyPressFunction(~, event)
        % keyPressFunction - Handles keyboard shortcuts for navigation and validation
        switch event.Key
            case 'leftarrow'
                if slider.Value > 1
                    slider.Value = slider.Value - 1;
                    updateBatch(slider.Value, flag);
                end
            case 'rightarrow'
                if slider.Value < n_pages
                    slider.Value = slider.Value + 1;
                    updateBatch(slider.Value, flag);
                end
            case 'a'
                highlightBatch();
            case 'f'
                if flag
                    flag = false;
                else
                    flag = true;
                end
                updateBatch(slider.Value, flag);
        end
    end

    function highlightBatch()
        firstSWR = (slider.Value - 1) * 12 + 1;
        lastSWR = min(slider.Value * 12, length(rpidx));
        highlightflag = sum(manvalid(firstSWR:lastSWR)) == (lastSWR-firstSWR+1);
        
        for idx = 1:12
            if firstSWR + idx - 1 <= lastSWR
                s = firstSWR + idx - 1;
                ax = axesHandles(idx);
                if ~highlightflag
                    manvalid(s) = true;
                    ax.Color = [0.565, 0.933, 0.565];
                else
                    manvalid(s) = false;
                    ax.Color = 'white';
                end
            end
        end
    end

    function closeFunction(~, ~)
        % closeFunction - Confirms save and closes the GUI
        selection = uiconfirm(mvfig, 'Do you want to save the manual validation?', ...
                              'Close Request', ...
                              'Options', {'Yes', 'No', 'Cancel'}, ...
                              'DefaultOption', 1, 'CancelOption', 3);
    
        switch selection
            case 'Yes'
                manvalid = manvalid(refvec);
                assignin('base', 'manvalid', manvalid);
                disp('Validated '+string(sum(manvalid))+' out of '+string(length(manvalid))+' events!')
                delete(mvfig);
            case 'No'
                delete(mvfig);
            case 'Cancel'
                % Do nothing
        end
    end

end
