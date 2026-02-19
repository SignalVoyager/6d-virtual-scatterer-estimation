function evalReport(~, M, B)
% evalReport - Print a compact and consistent evaluation summary.

fprintf('[Eval] Samples: total=%d, valid=%d\n', M.nTotal, M.nValid);
fprintf('[Eval] Score100=%.2f/100\n', M.score100);
fprintf('[Eval] Score breakdown: MAE_dB=%.1f, RMSE_dB=%.1f, NMSE=%.1f, |Bias|=%.1f, Corr=%.1f\n', ...
    M.scoreBreakdown.mae_dB, M.scoreBreakdown.rmse_dB, M.scoreBreakdown.nmse, ...
    M.scoreBreakdown.abs_bias_dB, M.scoreBreakdown.corr);

fprintf('[Eval] Linear: MAE=%.4e mW, RMSE=%.4e mW, MSE=%.4e mW^2\n', ...
    M.mae, M.rmse, M.mse);
fprintf('[Eval] Linear(norm): NMAE=%.4e, NMSE=%.4e, relRMSE=%.4e\n', ...
    M.nmae, M.nmse, M.relRMSE);

fprintf('[Eval] dB: MAE=%.4f dB, RMSE=%.4f dB, MedAE=%.4f dB, Bias=%.4f dB\n', ...
    M.mae_dB, M.rmse_dB, M.medae_dB, M.bias_dB);
fprintf('[Eval] Sun glo_mse_dB=%.6e\n', M.glo_mse_dB);

fprintf('[Eval] Corr: corr(y,yhat)=%.3f, corr(y,res)=%.3f\n', ...
    M.rho_y_yhat, M.rho_y_res);
fprintf('[Eval] Calibration: y ~= a*yhat + b, a=%.3f, b=%.3e\n', ...
    M.ab(1), M.ab(2));

fprintf('[Eval] Buckets (by y_mW quantiles): q50=%.3e, q90=%.3e\n', B.q50, B.q90);
printOne('LOW  (<=q50)', B.LOW);
printOne('MID  (q50-q90)', B.MID);
printOne('HIGH (>q90)', B.HIGH);
fprintf('\n');

function printOne(name, s)
    if s.count == 0
        fprintf('[Eval] %s: empty bucket\n', name);
    else
        fprintf('[Eval] %s: MSE=%.3e, NMSE=%.3f, count=%d\n', ...
            name, s.mse, s.nmse, s.count);
    end
end
end
