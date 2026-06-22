% ok_ordinaryKriging - Ordinary Kriging interpolation in 2D RX space.
%
% SYNTAX:
%   zhat = ok_ordinaryKriging(vstruct, x, y, z, xq, yq)
%   zhat = ok_ordinaryKriging(vstruct, x, y, z, xq, yq, Name, Value)
%
% INPUTS:
%   vstruct - variogram parameter struct with fields:
%             .nugget, .sill, .range, .alpha
%   x, y    - [N x 1] training coordinates
%   z       - [N x 1] training response (typically dBm)
%   xq, yq  - [M x 1] query coordinates
%
% NAME-VALUE OPTIONS:
%   "KNeighbors" - number of nearest training points used per query.
%                  inf or >= N uses global Kriging with all points.
%                  default: inf
%
% OUTPUT:
%   zhat    - [M x 1] predicted response at query points.
%
% NOTES:
%   - Covariance is converted from stable semivariogram as:
%       C(h) = (nugget + sill) - gamma(h)
%   - A small diagonal jitter is added for numerical stability.
%   - Local Kriging (KNeighbors < N) solves one small system per query.
function zhat = ok_ordinaryKriging(vstruct, x, y, z, xq, yq, varargin)
x = double(x(:)); y = double(y(:)); z = double(z(:));
xq = double(xq(:)); yq = double(yq(:));

n = numel(z);
m = numel(xq);

p = inputParser;
p.addParameter("KNeighbors", inf);
p.parse(varargin{:});
kNeighbors = p.Results.KNeighbors;
if isempty(kNeighbors) || ~isfinite(double(kNeighbors))
    kNeighbors = n;
else
    kNeighbors = max(2, min(n, floor(double(kNeighbors))));
end

% Covariance function from semivariogram:
% C(h) = (nugget + sill) - gamma(h)
% where gamma(0)=nugget ideally; we keep it consistent numerically.
function C = covStable(h)
    nug = vstruct.nugget;
    sill = vstruct.sill;
    rngv = vstruct.range;
    a = vstruct.alpha;

    gamma = nug + sill * (1 - exp(-(h./max(rngv,1e-12)).^a));
    C = (nug + sill) - gamma;
end

zhat = nan(m,1);
if kNeighbors >= n
    % Global kriging path.
    dx = x - x.';
    dy = y - y.';
    D  = hypot(dx, dy);
    K  = covStable(D);
    K = K + 1e-10*eye(n); % small jitter for numerical stability

    A = [K, ones(n,1); ones(1,n), 0];
    A = (A + A.')/2; % symmetrize

    for i = 1:m
        d = hypot(x - xq(i), y - yq(i));
        k = covStable(d);

        rhs = [k; 1];
        sol = A \ rhs;
        w = sol(1:n);

        zhat(i) = w.' * z;
    end
else
    % Local kriging path: nearest neighbors per query.
    for i = 1:m
        dAll = hypot(x - xq(i), y - yq(i));
        [~, order] = sort(dAll, 'ascend');
        idx = order(1:kNeighbors);

        xk = x(idx);
        yk = y(idx);
        zk = z(idx);

        dx = xk - xk.';
        dy = yk - yk.';
        D  = hypot(dx, dy);
        K  = covStable(D);
        K  = K + 1e-10*eye(kNeighbors);

        A = [K, ones(kNeighbors,1); ones(1,kNeighbors), 0];
        A = (A + A.')/2;

        k = covStable(dAll(idx));
        rhs = [k; 1];
        sol = A \ rhs;
        w = sol(1:kNeighbors);

        zhat(i) = w.' * zk;
    end
end
end
