function vstruct = ok_fitStableVariogram(h, gamma, varargin)
% ok_fitStableVariogram - fit a stable variogram with fixed alpha

p = inputParser;
p.addParameter("StableAlpha", 0.1);
p.parse(varargin{:});
alpha = double(p.Results.StableAlpha);

h = double(h(:));
gamma = double(gamma(:));

assert(~isempty(h) && ~isempty(gamma), "Need non-empty variogram samples.");

% initial guesses
nug0 = max(min(gamma), 0);
sill0 = max(gamma) - nug0;
if sill0 <= 0, sill0 = max(gamma); end
range0 = max(h) / 3;
if range0 <= 0, range0 = max(h); end

% bounds (avoid degeneracy)
lb = [1e-6, 1e-8, 0];       % range, sill, nugget
ub = [10*max(h), 10*max(gamma)+1e-6, max(gamma)];

objfun = @(theta) mseStable(theta, h, gamma, alpha);

theta0 = [range0, sill0, nug0];
theta = ok_fminsearchbnd(objfun, theta0, lb, ub);

vstruct = struct();
vstruct.model = "stable";
vstruct.range = theta(1);
vstruct.sill  = theta(2);
vstruct.nugget= theta(3);
vstruct.alpha = alpha;

function e = mseStable(theta, h, gamma, a)
    r = theta(1); s = theta(2); n0 = theta(3);
    pred = n0 + s * (1 - exp(-(h./max(r,1e-12)).^a));
    d = pred - gamma;
    e = mean(d.^2);
    if ~isfinite(e), e = 1e12; end
end
end
