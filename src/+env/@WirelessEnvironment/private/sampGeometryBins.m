% SAMPGEOMETRYBINS Sample geometry bins by radius and angle
%
%   [pool, sel] = SAMPGEOMETRYBINS(pool, gridPos, sc_pos, M, rMin, rMax, removeFlag)
%
%   Selects M samples from a pool of indices using a two-step geometric filtering:
%   1) Candidate filtering by radius range [rMin, rMax)
%   2) Uniform angular binning: picks one random sample per angle bin (0..2π)
%
%   INPUTS:
%       pool        - Column vector of candidate pool indices
%       gridPos     - (N x 2) array of grid positions [x, y]
%       sc_pos      - (1 x 2) row vector of scatterer position [x, y]
%       M           - Number of angle bins (samples to select)
%       rMin        - Minimum radius threshold (inclusive)
%       rMax        - Maximum radius threshold (exclusive)
%       removeFlag  - Logical flag; if true, removes selected samples from pool
%
%   OUTPUTS:
%       pool        - Updated pool with selected samples removed (if removeFlag=true)
%       sel         - (M x 1) column vector of selected sample indices
%
%   NOTES:
%       - Angles are computed as atan2(dy, dx) in range [0, 2π)
%       - Each angular bin must contain at least one radius-filtered candidate
%       - Selected indices must be unique (collisions trigger error)
%       - Errors if candidate set is empty or bins cannot be filled
%
%   ERRORS:
%       - 'empty candidate set': No samples within [rMin, rMax)
%       - 'empty bin': Angle bin m has no valid candidates
%       - 'reps collided': Duplicate selections across bins; increase pool density
function [pool, sel] = sampGeometryBins(pool, gridPos, sc_pos, M, rMin, rMax, removeFlag)
pool = pool(:);
if M <= 0
    sel = zeros(0,1);
    return;
end

dxy = gridPos - sc_pos;
r = hypot(dxy(:,1), dxy(:,2));
theta = mod(atan2(dxy(:,2), dxy(:,1)), 2*pi);

cand = pool(r(pool) >= rMin & r(pool) < rMax);
if isempty(cand)
    error('sampGeomBins: empty candidate set. Enlarge rMin/rMax or freeIdx.');
end

edges = linspace(0, 2*pi, M+1);
sel = zeros(M,1);

for m = 1:M
    bin = cand(theta(cand) >= edges(m) & theta(cand) < edges(m+1));
    if isempty(bin)
        error('sampGeomBins: empty bin %d/%d. Enlarge pool or relax rMin/rMax.', m, M);
    end
    sel(m) = bin(randi(numel(bin)));
end

sel = unique(sel, 'stable');
if numel(sel) < M
    % Collision across bins can happen on coarse grids.
    error('sampGeomBins: reps collided across bins. Increase pool density or reduce bins.');
end

if removeFlag
    pool = setdiff(pool, sel, 'stable');
end
end