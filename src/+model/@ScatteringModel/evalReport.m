function evalReport(~, M, B)
% evalReport - Print a compact and consistent evaluation summary.

S = iScore100(M, B);

fprintf('[Eval] Samples: total=%d, valid=%d\n', M.nTotal, M.nValid);
fprintf('[Eval] Metric guide: NMSE/relRMSE=linear power error; MAE/P90AE/Bias_dB=dB error mean/tail/offset; bucket=NMSE by low/mid/high power.\n');
fprintf('[Eval] Score100=%.2f/100 (NMSE %.0f%%, MAE_dB %.0f%%, P90AE_dB %.0f%%, |Bias| %.0f%%, bucket %.0f%%)\n', ...
    S.total, 100*S.nmse, 100*S.mae_dB, 100*S.p90ae_dB, 100*S.abs_bias_dB, 100*S.bucket);

fprintf('[Eval] Main: NMSE=%.4e, relRMSE=%.4e, MAE_dB=%.3f, P90AE_dB=%.3f, Bias_dB=%.3f\n', ...
    M.nmse, M.relRMSE, M.mae_dB, M.p90ae_dB, M.bias_dB);
fprintf('[Eval] Robust: MedAE_dB=%.3f, Corr=%.3f, Calibration a=%.3f b=%.3e\n', ...
    M.medae_dB, M.rho_y_yhat, M.ab(1), M.ab(2));

fprintf('[Eval] Buckets NMSE by y_mW quantiles: q50=%.3e, q90=%.3e | ', B.q50, B.q90);
printOne('LOW', B.LOW);
fprintf(' | ');
printOne('MID', B.MID);
fprintf(' | ');
printOne('HIGH', B.HIGH);
fprintf('\n');

function printOne(name, s)
    if s.count == 0
        fprintf('%s empty', name);
    else
        fprintf('%s %.3g (n=%d)', name, s.nmse, s.count);
    end
end
end

function S = iScore100(M, B)
% Score100 is a compact CGM reconstruction score:
%   30% global linear NMSE, 25% mean dB error, 20% 90th-percentile dB error,
%   10% calibration bias, 15% balanced NMSE across low/mid/high power buckets.
S = struct();
S.nmse = iLowerBetterLog(M.nmse, 2e-3, 5e-2);
S.mae_dB = iLowerBetterLinear(M.mae_dB, 2.0, 10.0);
S.p90ae_dB = iLowerBetterLinear(M.p90ae_dB, 5.0, 25.0);
S.abs_bias_dB = iLowerBetterLinear(abs(M.bias_dB), 0.5, 6.0);
S.bucket = iBucketScore(B);

w = [0.30, 0.25, 0.20, 0.10, 0.15];
vals = [S.nmse, S.mae_dB, S.p90ae_dB, S.abs_bias_dB, S.bucket];
S.total = 100 * sum(w .* vals) / sum(w);
S.total = max(0, min(100, S.total));
end

function s = iBucketScore(B)
scores = [
    iLowerBetterLog(B.LOW.nmse, 2e-2, 1e1), ...
    iLowerBetterLog(B.MID.nmse, 2e-2, 1e1), ...
    iLowerBetterLog(B.HIGH.nmse, 2e-2, 1e1)];
s = mean(scores, "omitnan");
if ~isfinite(s), s = 0; end
end

function s = iLowerBetterLinear(x, good, bad)
if ~isfinite(x)
    s = 0;
    return;
end
s = (bad - x) / max(bad - good, eps);
s = max(0, min(1, s));
end

function s = iLowerBetterLog(x, good, bad)
if ~isfinite(x) || x <= 0
    s = 0;
    return;
end
lx = log10(x);
lg = log10(good);
lb = log10(bad);
s = (lb - lx) / max(lb - lg, eps);
s = max(0, min(1, s));
end
