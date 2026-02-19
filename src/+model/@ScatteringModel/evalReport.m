%% evalReport
% Generates and displays a comprehensive evaluation report of model performance
% metrics and statistics.
%
% Syntax:
%   evalReport(obj, M, B)
%
% Description:
%   Prints formatted evaluation metrics including mean squared error (MSE),
%   normalized MSE (NMSE), correlation coefficients, and performance statistics
%   stratified by output quantile buckets (LOW, MID, HIGH).
%
% Input Arguments:
%   obj - ScatteringModel object instance
%   M   - struct containing evaluation metrics with fields:
%         - mse: Mean squared error value
%         - nmse: Normalized mean squared error
%         - glo_mse_dB: Global MSE in decibels
%         - rho_y_yhat: Correlation between actual and predicted outputs
%         - rho_y_res: Correlation between actual output and residuals
%         - relRMSE: Relative RMSE (normalized by RMS of actual output)
%         - ab: 2-element vector [a, b] for linear fit y ≈ a*yhat + b
%   B   - struct containing bucketed statistics with fields:
%         - q50: 50th percentile (median) threshold
%         - q90: 90th percentile threshold
%         - LOW: struct with metrics for y <= q50 (fields: count, mse, nmse)
%         - MID: struct with metrics for q50 < y <= q90 (fields: count, mse, nmse)
%         - HIGH: struct with metrics for y > q90 (fields: count, mse, nmse)
%
% Output:
%   None. Function prints formatted report to command window.
%
% See Also:
%   ScatteringModel
function evalReport(~, M, B)
fprintf('[Eval] MSE=%.4e, NMSE=%.4e\n', M.mse, M.nmse);
fprintf('[Eval] glo_mse_dB=%.6e\n', M.glo_mse_dB);

fprintf('[Eval] corr(y, yhat)=%.3f, corr(y, residual)=%.3f\n', M.rho_y_yhat, M.rho_y_res);
fprintf('[Eval] Relative RMSE (sqrt(MSE)/rms(y)) = %.3f\n', M.relRMSE);

fprintf('[Eval] y ≈ a*yhat + b: a=%.3f, b=%.3e\n', M.ab(1), M.ab(2));

fprintf('[Eval] Buckets by y quantiles: q50=%.3e, q90=%.3e\n', B.q50, B.q90);
printOne('LOW  (<=q50)', B.LOW);
printOne('MID  (q50-q90)', B.MID);
printOne('HIGH (>q90)', B.HIGH);
fprintf('\n');

function printOne(name, s)
    if s.count == 0
        fprintf('[Eval] %s: empty bucket\n', name);
    else
        fprintf('[Eval] %s: MSE=%.3e, NMSE=%.3f, count=%d\n', name, s.mse, s.nmse, s.count);
    end
end
end
