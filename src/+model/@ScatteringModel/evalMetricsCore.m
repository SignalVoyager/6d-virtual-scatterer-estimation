% evalMetricsCore - Compute core regression metrics on linear-scale power.
%
% SYNTAX:
%   M = evalMetricsCore(obj, P)
%
% DESCRIPTION:
%   Evaluates comprehensive regression performance metrics in linear power scale.
%   Computes error statistics, correlations, relative RMSE, and linear calibration
%   parameters comparing predicted and observed power values.
%
% INPUT:
%   obj       ScatteringModel object (unused)
%   P         struct containing:
%     .y_mW     - observed power values in mW (N x 1)
%     .yhat_mW  - predicted power values in mW (N x 1)
%
% OUTPUT:
%   M         struct with computed metrics:
%     .mse        - mean squared error on linear scale (mW²)
%     .nmse       - normalized mean squared error, normalized by mean(y_mW²)
%     .glo_mse_dB - global mean squared error in dB scale
%     .rho_y_yhat - Pearson correlation coefficient between y and yhat
%     .rho_y_res  - Pearson correlation coefficient between y and residuals
%     .relRMSE    - relative RMSE normalized by RMS of observations
%     .ab         - linear calibration coefficients [a; b] for y ≈ a*yhat + b
%
% NOTES:
%   - Correlations return NaN if either signal has zero standard deviation
%   - dB scale metrics use max(·, 1e-12) floor to avoid log(0)
%   - Linear fit solves least-squares: yhat_mW \ y_mW
function M = evalMetricsCore(obj, P) %#ok<INUSD>
y_mW    = P.y_mW;
yhat_mW = P.yhat_mW;
res_mW  = y_mW - yhat_mW;

mse  = mean(res_mW.^2);
nmse = mse / max(mean(y_mW.^2), eps);

% Sun-aligned glo_mse_dB
err_dB = 10*log10(max(y_mW,1e-12)) - 10*log10(max(yhat_mW,1e-12));
glo_mse_dB = norm(err_dB).^2 / size(y_mW,1);

% correlations
if std(y_mW) > 0 && std(yhat_mW) > 0
    R = corrcoef(y_mW, yhat_mW);
    rho_y_yhat = R(1,2);
else
    rho_y_yhat = NaN;
end

if std(y_mW) > 0 && std(res_mW) > 0
    Rr = corrcoef(y_mW, res_mW);
    rho_y_res = Rr(1,2);
else
    rho_y_res = NaN;
end

relRMSE = sqrt(mse) / max(sqrt(mean(y_mW.^2)), eps);

% linear fit y ≈ a*yhat + b
Xlin = [yhat_mW, ones(size(yhat_mW))];
ab = Xlin \ y_mW;  % [a;b]

M = struct();
M.mse = mse;
M.nmse = nmse;
M.glo_mse_dB = glo_mse_dB;
M.rho_y_yhat = rho_y_yhat;
M.rho_y_res  = rho_y_res;
M.relRMSE = relRMSE;
M.ab = ab;
end
