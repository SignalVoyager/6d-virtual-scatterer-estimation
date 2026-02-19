function plotPdfCompare(obj, P, opt) %#ok<INUSD>
% plotPdfCompare - compare PDFs of ground-truth and predicted powers in dBm.
% Histogram PDFs can be optionally smoothed by moving average.
if nargin < 3 || isempty(opt), opt = struct(); end
if ~isfield(opt,"binWidth_dB"), opt.binWidth_dB = 1.0; end
if ~isfield(opt,"smoothWin"),   opt.smoothWin = 3; end

valid = P.valid;
y_dBm    = 10*log10(P.y_mW(valid));
yhat_dBm = 10*log10(P.yhat_mW(valid));

bw = opt.binWidth_dB;
lo = floor(min([y_dBm; yhat_dBm]));
hi = ceil(max([y_dBm; yhat_dBm]));
edges = (lo:bw:hi).';
centers = edges(1:end-1) + bw/2;

y_pdf    = histcounts(y_dBm,    edges, 'Normalization', 'pdf');
yhat_pdf = histcounts(yhat_dBm, edges, 'Normalization', 'pdf');

if opt.smoothWin > 1
    y_pdf    = movmean(y_pdf,    opt.smoothWin);
    yhat_pdf = movmean(yhat_pdf, opt.smoothWin);
end

figure;
plot(centers, y_pdf,    'LineWidth', 1.8); hold on;
plot(centers, yhat_pdf, 'LineWidth', 1.8);
grid on;
xlabel('Power (dBm)');
ylabel('PDF');
title('PDF comparison: Ground truth y vs Prediction yhat');
legend('y (GT)', 'yhat', 'Location', 'best');
end
