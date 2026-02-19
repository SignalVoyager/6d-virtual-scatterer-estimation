% SAMPUSERGRIDLIST Sample user grid list from available pool
%
%   [POOL, SEL] = SAMPUSERGRIDLIST(POOL, TXGRIDCR, KX, KY, REMOVEFLAG)
%
%   Samples grid positions from an available pool based on specified and 
%   random selections. Supports both explicit grid coordinate specification 
%   and random filling of remaining positions.
%
%   INPUT ARGUMENTS:
%       POOL        - [M x 1] vector of available grid indices
%       TXGRIDCR    - [N x 2] array of [col, row] coordinates
%                     [0, 0] indicates random fill position
%       KX          - number of columns in grid
%       KY          - number of rows in grid
%       REMOVEFLAG  - boolean, if true removes selected indices from POOL
%
%   OUTPUT ARGUMENTS:
%       POOL        - [M' x 1] updated pool (empty if REMOVEFLAG=false)
%       SEL         - [N' x 1] selected grid indices in stable order
%
%   NOTES:
%       - Grid coordinates are 1-indexed with [col, row] convention
%       - Explicit selections must be within [1,KX] x [1,KY] bounds
%       - Explicit selections are intersected with available pool
%       - Random selections fill from remaining pool after explicit picks
%       - Error raised if random selections exceed available pool size
%       - Output indices follow linear indexing with row-major order [KY, KX]
%
%   EXAMPLES:
%       [pool, sel] = sampUserGridList(pool, [1,1; 0,0], 10, 10, true);
%       % Select (1,1) explicitly and 1 random position, remove from pool
function [pool, sel] = sampUserGridList(pool, txGridCR, Kx, Ky, removeFlag)
pool = pool(:);

isRand = (txGridCR(:,1)==0 & txGridCR(:,2)==0);
cr = txGridCR(~isRand, :);

if ~isempty(cr)
    assert(all(cr(:,1)>=1 & cr(:,1)<=Kx), 'col out of range.');
    assert(all(cr(:,2)>=1 & cr(:,2)<=Ky), 'row out of range.');
    selSpec = sub2ind([Ky,Kx], cr(:,2), cr(:,1));
    selSpec = unique(selSpec, 'stable');

    % enforce free grids only
    selSpec = intersect(selSpec(:), pool(:), 'stable');
else
    selSpec = zeros(0,1);
end

nRand = sum(isRand);
if nRand > 0
    pool2 = setdiff(pool(:), selSpec(:), 'stable');
    if nRand > numel(pool2)
        error('sampUserGridList: random fill %d exceeds remaining pool %d.', nRand, numel(pool2));
    end
    idx = randperm(numel(pool2), nRand);
    selRand = pool2(idx);
else
    selRand = zeros(0,1);
end

sel = [selSpec(:); selRand(:)];
sel = unique(sel, 'stable');

if removeFlag && ~isempty(sel)
    pool = setdiff(pool, sel, 'stable');
end
end