function M = evalMetricsCore(obj, P) %#ok<INUSD>
% evalMetricsCore - compute core regression metrics on linear-scale power.
% Returns global error, correlations, relative RMSE, and linear calibration fit.
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
