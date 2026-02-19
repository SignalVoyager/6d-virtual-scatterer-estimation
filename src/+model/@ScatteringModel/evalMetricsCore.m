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
M.bias_dB = bias_dB;

M.rho_y_yhat = rho_y_yhat;
M.rho_y_res = rho_y_res;
M.ab = ab;

if isfield(P, "nTotal"), M.nTotal = P.nTotal; else, M.nTotal = numel(y_mW); end
if isfield(P, "nValid"), M.nValid = P.nValid; else, M.nValid = numel(y_mW); end

% ---- compact model score (0-100, higher is better) ----
spec = iDefaultScoreSpec();
if isfield(P, "scoreSpec") && isstruct(P.scoreSpec)
    spec = iMergeScoreSpec(spec, P.scoreSpec);
end

sMaeDb  = iScoreLowerBetter(mae_dB,     spec.mae_dB_good,  spec.mae_dB_bad);
sRmseDb = iScoreLowerBetter(rmse_dB,    spec.rmse_dB_good, spec.rmse_dB_bad);
sNmse   = iScoreLowerBetter(nmse,       spec.nmse_good,    spec.nmse_bad);
sBiasDb = iScoreLowerBetter(abs(bias_dB), spec.bias_dB_good, spec.bias_dB_bad);
sCorr   = iScoreHigherBetter(rho_y_yhat, spec.corr_bad, spec.corr_good);

w = spec.weights;
w = w / max(sum(w), eps);
score100 = 100 * ( ...
    w(1)*sMaeDb + ...
    w(2)*sRmseDb + ...
    w(3)*sNmse + ...
    w(4)*sBiasDb + ...
    w(5)*sCorr);
score100 = max(0, min(100, score100));

M.score100 = score100;
M.scoreBreakdown = struct( ...
    'mae_dB', 100*sMaeDb, ...
    'rmse_dB', 100*sRmseDb, ...
    'nmse', 100*sNmse, ...
    'abs_bias_dB', 100*sBiasDb, ...
    'corr', 100*sCorr);
end

function s = iScoreLowerBetter(x, good, bad)
if ~isfinite(x)
    s = 0;
    return;
end
if bad <= good
    bad = good + eps;
end
s = (bad - x) / (bad - good);
s = max(0, min(1, s));
end

function s = iScoreHigherBetter(x, bad, good)
if ~isfinite(x)
    s = 0;
    return;
end
if good <= bad
    good = bad + eps;
end
s = (x - bad) / (good - bad);
s = max(0, min(1, s));
end

function spec = iDefaultScoreSpec()
spec = struct();
% Weights: [MAE_dB, RMSE_dB, NMSE, abs(Bias_dB), Corr]
spec.weights = [0.30, 0.25, 0.20, 0.10, 0.15];

% "good" and "bad" anchors for linear mapping to [0,1]
spec.mae_dB_good = 1.0;
spec.mae_dB_bad  = 12.0;
spec.rmse_dB_good = 1.5;
spec.rmse_dB_bad  = 15.0;
spec.nmse_good = 0.02;
spec.nmse_bad  = 1.0;
spec.bias_dB_good = 0.5;
spec.bias_dB_bad  = 6.0;
spec.corr_good = 0.95;
spec.corr_bad  = 0.20;
end

function out = iMergeScoreSpec(def, usr)
out = def;
keys = fieldnames(def);
for i = 1:numel(keys)
    k = keys{i};
    if isfield(usr, k)
        out.(k) = usr.(k);
    end
end
end
