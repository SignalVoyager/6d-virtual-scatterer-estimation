function [pool, sel] = sampRandom(pool, num, removeFlag)
% sampRandom - randomly sample indices from a candidate pool.
% Optionally removes selected indices from the returned pool.
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
