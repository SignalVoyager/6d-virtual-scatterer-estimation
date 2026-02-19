function Results = aggregateGridSamples(Results, opt)
% Postprocess based on (tx,rx) indices only.
% - directed: if false, convert to undirected key (min,max) before dedup (not used in your default).
% - allowSelf: if false, remove tx==rx.
% - dedup global: unique rows by key with 'stable'.
if isempty(Results)
    return;
end

tx = Results(:,1);
rx = Results(:,2);

% 1) self-pair removal
if isfield(opt,'allowSelf') && ~opt.allowSelf
    keep = (tx ~= rx);
    Results = Results(keep,:);
    if isempty(Results), return; end
    tx = Results(:,1);
    rx = Results(:,2);
end

% 2) build dedup key
if isfield(opt,'directed') && ~opt.directed
    % undirected key: treat (t,r) and (r,t) as same
    a = min(tx, rx);
    b = max(tx, rx);
    key = [a, b];
else
    % directed key
    key = [tx, rx];
end

% 3) global dedup (stable)
if isfield(opt,'dedup') && opt.dedup
    [~, ia] = unique(key, 'rows', 'stable');
    Results = Results(ia, :);
end
end
