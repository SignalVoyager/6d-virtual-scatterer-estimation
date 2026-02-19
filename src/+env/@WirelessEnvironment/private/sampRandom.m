% SAMPLERANDOM Randomly sample indices from a candidate pool
%
%   [pool, sel] = SAMPLERANDOM(pool, num, removeFlag)
%
% DESCRIPTION
%   Randomly selects a specified number of indices from a candidate pool.
%   Optionally removes the selected indices from the pool and returns the
%   updated pool.
%
% INPUT ARGUMENTS
%   pool        - Vector of candidate indices to sample from
%   num         - Number of indices to randomly select (non-negative integer)
%   removeFlag  - Boolean flag; if true, removes selected indices from pool
%
% OUTPUT ARGUMENTS
%   pool        - Updated candidate pool (modified only if removeFlag is true)
%   sel         - Vector of randomly selected indices (size: num x 1)
%
% REMARKS
%   - pool is converted to column vector internally
%   - Returns an empty array if num <= 0
%   - Raises an error if num exceeds the size of the pool
%   - When removeFlag is true and indices are selected, the pool is updated
%     using setdiff with 'stable' option to preserve order
%
% EXAMPLE
%   pool = [1 2 3 4 5]';
%   [updPool, selected] = sampRandom(pool, 3, true);
%   % selected contains 3 randomly chosen values
%   % updPool contains remaining 2 values
function [pool, sel] = sampRandom(pool, num, removeFlag)
pool = pool(:);
if num <= 0
    sel = zeros(0,1); % empty array
    return;
end
if num > numel(pool)
    error('sampRandom: request %d exceeds pool size %d.', num, numel(pool));
end
idx = randperm(numel(pool), num);
sel = pool(idx);
if removeFlag && ~isempty(sel)
    pool = setdiff(pool, sel, 'stable');
end
end
