%% evalMetricsBuckets
% Compute MSE/NMSE statistics in quantile-based buckets.
%
% Syntax:
%   B = evalMetricsBuckets(obj, P)
%   B = evalMetricsBuckets(obj, P, qList)
%
% Description:
%   Splits samples into LOW/MID/HIGH groups based on quantiles of the 
%   power measurements (y_mW). Computes mean squared error (MSE) and 
%   normalized MSE (NMSE) for each bucket.
%
% Input Arguments:
%   obj    - ScatteringModel object
%   P      - Structure containing:
%            .y_mW    - measured power values [N x 1]
%            .res_mW  - residuals (estimation errors) [N x 1]
%   qList  - Quantile thresholds for bucketing (default: [0.50 0.90])
%            [q50, q90] specify the 50th and 90th percentile boundaries
%
% Output Arguments:
%   B      - Structure containing quantile-based bucket statistics:
%            .q50    - 50th percentile threshold value
%            .q90    - 90th percentile threshold value
%            .LOW    - Statistics for y_mW <= q50
%            .MID    - Statistics for q50 < y_mW <= q90
%            .HIGH   - Statistics for y_mW > q90
%
%   Each bucket contains:
%            .mse    - Mean squared error for the bucket
%            .nmse   - Normalized MSE (relative to mean power^2)
%            .count  - Number of samples in the bucket
%
% See Also:
%   quantile, mean
function B = evalMetricsBuckets(obj, P, qList) %#ok<INUSD>
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
