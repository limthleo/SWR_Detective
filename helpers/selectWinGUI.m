function [winbin, winind] = selectWinGUI(data)
% selectWinGUI - Interactive GUI to select windows on a data plot
%   This function opens a GUI for selecting regions on a plot by clicking
%   on the data. Left-clicking marks the start and end of each selection window,
%   while right-clicking undoes the last selected window. The GUI allows zooming
%   and panning with toolbar options.
%
%   Parameters:
%   - data : Vector of data to plot and select windows on
%
%   Returns:
%   - winbin : Logical array where selected windows are set to true
%   - winind : N-by-2 matrix storing start and end indices of selected windows

fig = figure("WindowState", "maximized");
p = plot(data, 'b');
title("LEFT-CLICK to select window boundaries, RIGHT-CLICK to undo the last window, CLOSE to save.")
winbin = false(size(data));  % Initialize logical vector for selected windows
winind = [];  % Storage for selected window indices (start and end)
x_clicks = [];  % Temporary storage for selected x-coordinates

% Set up the axes toolbar for zoom and pan, with callback for enabling/disabling selection
axtoolbar(gca, {'zoomin', 'zoomout', 'pan', 'restoreview'}, ...
    'SelectionChangedFcn', {@tbar_changed_fcn, p});
set(fig, "Pointer", 'crosshair');  % Set cursor to crosshair for selection clarity
set(fig, "WindowButtonDownFcn", @mouse_click_callback);  % Set callback for mouse clicks

% Main loop: pauses until the figure is closed by the user
while ishandle(fig)
    pause(0.1);
end

% Populate winbin with true values for indices within selected windows
for i = 1:size(winind,1)
    winbin(winind(i,1):winind(i,2)) = true;
end

    % Toolbar state change callback function
    % This function activates/deactivates window selection based on toolbar mode
    function tbar_changed_fcn(~, event, p)
        state = event.Selection.Value;
        if strcmp(state, 'on')
            p.ButtonDownFcn = [];  % Disable selection when zoom or pan is active
            x_clicks = [];  % Clear any in-progress selection
        else
            p.ButtonDownFcn = @mouse_click_callback;  % Enable selection on regular mode
        end
    end

    % Mouse click callback for selecting windows
    % Left-click selects start and end of windows; right-click undoes the last selection
    function mouse_click_callback(~, ~)
        click_type = get(fig, 'SelectionType');
        if strcmp(click_type, 'normal')  % Left-click for window selection
            x_click = get(gca, 'CurrentPoint');
            x_clicks = [x_clicks x_click(1,1)];  % Store clicked x-coordinate
            if length(x_clicks) == 2  % After two clicks, mark the window
                winstart = max(1, round(min(x_clicks)));  % Start index of the window
                winstop = min(round(max(x_clicks)), length(data));  % End index
                winind = [winind; winstart winstop];  % Save window indices
                xregion(winind(end,1), winind(end,2), 'FaceColor', [1 0 0], ...
                    'FaceAlpha', 0.2, 'EdgeColor', 'none');  % Highlight window in red
                x_clicks = [];  % Reset x_clicks for next selection
            end
        elseif strcmp(click_type, 'alt') && ~isempty(winind)  % Right-click to undo last window
            winind(end,:) = [];  % Remove last window
            x_clicks = [];  % Reset x_clicks
            cla; hold on  % Clear and replot data and windows
            plot(data, 'b');
            for w = 1:size(winind,1)  % Re-display existing windows
                xregion(winind(w,1), winind(w,2), 'FaceColor', [1 0 0], ...
                    'FaceAlpha', 0.2, 'EdgeColor', 'none');
            end
            hold off
        end
    end
end
