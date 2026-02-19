function [pool, sel] = sampUserGridList(pool, txGridCR, Kx, Ky, removeFlag)
% txGridCR: [N x 2] = [col,row], with [0,0] meaning random fill
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