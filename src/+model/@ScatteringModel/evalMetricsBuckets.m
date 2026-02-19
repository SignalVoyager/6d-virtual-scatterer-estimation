function B = evalMetricsBuckets(obj, P, qList) %#ok<INUSD>
% evalMetricsBuckets - compute MSE/NMSE statistics in quantile-based buckets.
% Splits samples into LOW/MID/HIGH groups using q50 and q90 of y_mW.
if nargin < 3 || isempty(qList), qList = [0.50 0.90]; end
y_mW   = P.y_mW;
res_mW = P.res_mW;

q50 = quantile(y_mW, qList(1));
q90 = quantile(y_mW, qList(2));

B = struct();
B.q50 = q50;
B.q90 = q90;

B.LOW  = oneBucket(y_mW <= q50);
B.MID  = oneBucket((y_mW > q50) & (y_mW <= q90));
B.HIGH = oneBucket(y_mW > q90);

function out = oneBucket(mask)
    out = struct('mse', NaN, 'nmse', NaN, 'count', 0);
    if ~any(mask), return; end
    mse_b = mean(res_mW(mask).^2);
    nmse_b = mse_b / max(mean(y_mW(mask).^2), eps);
    out.mse = mse_b;
    out.nmse = nmse_b;
    out.count = nnz(mask);
end
end
