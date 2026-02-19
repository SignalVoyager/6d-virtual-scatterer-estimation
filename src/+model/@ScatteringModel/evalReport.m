function evalReport(obj, M, B)
% evalReport - print consolidated evaluation metrics and bucket summaries.
% Uses a consistent console format shared by all derived models.
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
