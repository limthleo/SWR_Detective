% WIN2IND Convert window boundaries to a vector of indices
%
%   IND = WIN2IND(WIN) takes a matrix WIN, where each row specifies a range
%   of indices, and returns a column vector IND containing all the indices
%   within these specified ranges.
%
%   Input:
%     WIN - An Nx2 matrix, where each row [a, b] defines a range of indices
%           from a to b (inclusive).
%
%   Output:
%     IND - A column vector containing all indices specified by the ranges
%           in WIN. Each range in WIN is converted to a sequence of indices,
%           which are concatenated to form IND.
%
%   Example:
%     win = [1 3; 5 7];
%     ind = win2ind(win);
%     % ind will be: [1; 2; 3; 5; 6; 7]
%
%   See also ARRAYFUN, VERTCAT.

function ind = win2ind(win)
    % Create cell array where each cell contains indices from win(x,1) to win(x,2)
    ind = arrayfun(@(x) (win(x,1):win(x,2))', 1:size(win,1), 'UniformOutput', false);
    % Concatenate all indices from cell array into a single column vector
    ind = vertcat(ind{:});
end
