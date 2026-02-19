function zhat = ok_idwPredict(x, y, z, xq, yq, p)
% ok_idwPredict - inverse distance weighting predictor in 2D

x = x(:); y = y(:); z = z(:);
xq = xq(:); yq = yq(:);

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

zhat = nan(m,1);
for i = 1:m
    d = hypot(x - xq(i), y - yq(i));
    d = max(d, 1e-9);
    w = 1 ./ (d.^p);
    w = w / sum(w);
    zhat(i) = w.' * z;
end
end
