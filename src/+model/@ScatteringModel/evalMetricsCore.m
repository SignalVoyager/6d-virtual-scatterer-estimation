function M = evalMetricsCore(obj, P) %#ok<INUSD>
% evalMetricsCore - Compute core regression metrics on power prediction.
%
% Inputs:
%   P.y_mW, P.yhat_mW
%   Optional: P.err_dB, P.nTotal, P.nValid
%
% Outputs (struct M):
%   Linear domain:
%     mse, rmse, mae, nmse, nmae, relRMSE
%   dB domain:
%     glo_mse_dB, rmse_dB, mae_dB, medae_dB, bias_dB
%   Correlation/calibration:
%     rho_y_yhat, rho_y_res, ab
%   Counts:
%     nTotal, nValid

y_mW    = P.y_mW(:);
yhat_mW = P.yhat_mW(:);
res_mW  = y_mW - yhat_mW;

if isfield(P, "err_dB")
    err_dB = P.err_dB(:);
else
    err_dB = 10*log10(max(y_mW,1e-12)) - 10*log10(max(yhat_mW,1e-12));
end

% ---- linear-domain metrics ----
mse  = mean(res_mW.^2);
rmse = sqrt(mse);
mae  = mean(abs(res_mW));
nmse = mse / max(mean(y_mW.^2), eps);
nmae = mae / max(mean(abs(y_mW)), eps);
relRMSE = rmse / max(rms(y_mW), eps);

% ---- dB-domain metrics ----
% Keep Sun-style global dB MSE for backward comparability.
glo_mse_dB = mean(err_dB.^2);
rmse_dB    = sqrt(glo_mse_dB);
mae_dB     = mean(abs(err_dB));
medae_dB   = median(abs(err_dB));
p90ae_dB   = quantile(abs(err_dB), 0.90);
bias_dB    = mean(err_dB);

% ---- correlations ----
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

% ---- linear calibration: y ~= a*yhat + b ----
Xlin = [yhat_mW, ones(size(yhat_mW))];
ab = Xlin \ y_mW;  % [a; b]

M = struct();
M.mse = mse;
M.rmse = rmse;
M.mae = mae;
M.nmse = nmse;
M.nmae = nmae;
M.relRMSE = relRMSE;

M.glo_mse_dB = glo_mse_dB;
M.rmse_dB = rmse_dB;
M.mae_dB = mae_dB;
M.medae_dB = medae_dB;
M.p90ae_dB = p90ae_dB;
M.bias_dB = bias_dB;

M.rho_y_yhat = rho_y_yhat;
M.rho_y_res = rho_y_res;
M.ab = ab;

if isfield(P, "nTotal"), M.nTotal = P.nTotal; else, M.nTotal = numel(y_mW); end
if isfield(P, "nValid"), M.nValid = P.nValid; else, M.nValid = numel(y_mW); end
end
