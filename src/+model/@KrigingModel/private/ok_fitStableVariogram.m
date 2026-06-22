% ok_fitStableVariogram - Fit a stable semivariogram with fixed alpha.
%
% SYNTAX:
%   vstruct = ok_fitStableVariogram(h, gamma)
%   vstruct = ok_fitStableVariogram(h, gamma, Name, Value)
%
% INPUTS:
%   h     - [M x 1] lag distances.
%   gamma - [M x 1] experimental semivariance at each lag.
%
% NAME-VALUE:
%   "StableAlpha" - fixed alpha in the stable model (default: 0.1).
%   "BinCount"    - [M x 1] pair counts per lag bin (optional).
%   "UseWeightedLS" - true/false, whether to use BinCount-weighted LS
%                     (default: false).
%
% MODEL:
%   gamma_model(h) = nugget + sill * (1 - exp(-(h/range)^alpha))
%
% OUTPUT:
%   vstruct - struct with fields:
%             .model  = "stable"
%             .range
%             .sill
%             .nugget
%             .alpha
%
% NOTES:
%   - alpha is fixed; only range/sill/nugget are optimized.
%   - Objective is mean squared error between model and experimental gamma.
%   - Uses bounded Nelder-Mead via ok_fminsearchbnd.
function vstruct = ok_fitStableVariogram(h, gamma, varargin)
p = inputParser;
p.addParameter("StableAlpha", 0.1);
p.addParameter("BinCount", []);
p.addParameter("UseWeightedLS", false);
p.parse(varargin{:});
alpha = double(p.Results.StableAlpha);
binCount = p.Results.BinCount;
useWeightedLS = logical(p.Results.UseWeightedLS);

% Ensure column vectors and numeric type for optimization.
h = double(h(:));
gamma = double(gamma(:));
binCount = double(binCount(:));

assert(~isempty(h) && ~isempty(gamma), "Need non-empty variogram samples.");
assert(numel(h) == numel(gamma), "h and gamma must have same size.");
if useWeightedLS
    assert(~isempty(binCount), ...
        "BinCount is required when UseWeightedLS=true.");
    assert(numel(binCount) == numel(h), ...
        "BinCount must have same size as h.");
end

% Initial guesses from data scale.
nug0 = max(min(gamma), 0);
sill0 = max(gamma) - nug0;
if sill0 <= 0, sill0 = max(gamma); end
range0 = max(h) / 3;
if range0 <= 0, range0 = max(h); end

% Parameter bounds to avoid degenerate solutions:
% theta = [range, sill, nugget].
lb = [1e-6, 1e-8, 0];       % range, sill, nugget
ub = [10*max(h), 10*max(gamma)+1e-6, max(gamma)];

% Build weights for optional weighted least squares.
if useWeightedLS
    w = max(binCount, 0);
    if sum(w) <= 0
        w = ones(size(h));
    end
else
    w = ones(size(h));
end
w = w / sum(w);

% Objective: weighted (or uniform) least squares.
objfun = @(theta) wlsStable(theta, h, gamma, alpha, w);

theta0 = [range0, sill0, nug0];
% Bounded optimization in transformed space.
theta = ok_fminsearchbnd(objfun, theta0, lb, ub);

% Pack fitted variogram parameters.
vstruct = struct();
vstruct.model = "stable";
vstruct.range = theta(1);
vstruct.sill  = theta(2);
vstruct.nugget= theta(3);
vstruct.alpha = alpha;

function e = wlsStable(theta, h, gamma, a, w)
    r = theta(1); s = theta(2); n0 = theta(3);
    pred = n0 + s * (1 - exp(-(h./max(r,1e-12)).^a));
    d = pred - gamma;
    e = sum((d.^2) .* w);
    % Guard optimization against invalid arithmetic.
    if ~isfinite(e), e = 1e12; end
end
end
