function [pool, sel] = sampGeometryBins(pool, gridPos, sc_pos, M, rMin, rMax, removeFlag)
% Two-step:
% 1) candidate filter by radius
% 2) pick one per angle bin (0..2pi) using candidates
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