% AGGREGATEGRIDSAMPLES Postprocess results based on transmitter and receiver indices.
%
%   RESULTS = AGGREGATEGRIDSAMPLES(RESULTS, OPT) performs postprocessing on a
%   results matrix by filtering and deduplicating entries based on (tx, rx) pairs.
%
%   INPUT:
%       RESULTS - M×N matrix of results where columns 1 and 2 contain transmitter
%                 (tx) and receiver (rx) indices, respectively.
%       OPT     - Structure with optional fields controlling filtering behavior:
%           .allowSelf  - Logical; if false, removes entries where tx == rx
%                         (default: true, allows self-pairs).
%           .directed   - Logical; if false, treats (tx, rx) and (rx, tx) as
%                         identical pairs and deduplicates accordingly
%                         (default: true, treats as directed).
%           .dedup      - Logical; if true, removes duplicate (tx, rx) key pairs
%                         while preserving first occurrence order
%                         (default: false, no deduplication).
%
%   OUTPUT:
%       RESULTS - Filtered and deduplicated results matrix. Rows are removed
%                 according to the postprocessing rules specified in OPT.
%
%   NOTES:
%       - If RESULTS is empty, returns immediately without modification.
%       - Deduplication uses 'stable' mode to maintain row order.
%       - For undirected mode, the key is normalized to (min(tx,rx), max(tx,rx)).
%
%   See also: unique
function Results = aggregateGridSamples(Results, opt)
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
