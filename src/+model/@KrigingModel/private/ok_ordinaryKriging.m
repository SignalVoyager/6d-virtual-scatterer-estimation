function zhat = ok_ordinaryKriging(vstruct, x, y, z, xq, yq)
% ok_ordinaryKriging - ordinary kriging in 2D

x = double(x(:)); y = double(y(:)); z = double(z(:));
xq = double(xq(:)); yq = double(yq(:));

n = numel(z);
m = numel(xq);

if n == 0
    zhat = nan(m,1);
    return;
end
if n == 1
    zhat = z(1) * ones(m,1);
    return;
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

% Build kriging system [K 1; 1^T 0] * [w; mu] = [k; 1]
% K: [n x n] covariance between training points
dx = x - x.';
dy = y - y.';
D  = hypot(dx, dy);
K  = covStable(D);

% add small jitter for numerical stability
K = K + 1e-10*eye(n);

A = [K, ones(n,1); ones(1,n), 0];
A = (A + A.')/2; % symmetrize

zhat = nan(m,1);
for i = 1:m
    d = hypot(x - xq(i), y - yq(i));
    k = covStable(d);

    rhs = [k; 1];
    sol = A \ rhs;
    w = sol(1:n);

    zhat(i) = w.' * z;
end
end
