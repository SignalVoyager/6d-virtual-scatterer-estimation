% plotPdfCompare - Compare probability density functions of ground-truth and predicted powers in dBm.
%
% SYNTAX:
%   plotPdfCompare(obj, P, opt)
%
% DESCRIPTION:
%   Compares the probability density functions (PDFs) of ground-truth and 
%   predicted power measurements by computing normalized histograms. The histograms
%   are binned according to a specified bin width and can be smoothed using a 
%   moving average filter. A figure is generated displaying both PDFs overlaid 
%   for visual comparison.
%
% INPUT ARGUMENTS:
%   obj         - ScatteringModel object
%   P           - Structure containing power measurements with fields:
%                   .y_mW     - Ground-truth power in milliwatts [N x 1]
%                   .yhat_mW  - Predicted power in milliwatts [N x 1]
%                   .valid    - Logical indices of valid measurements [N x 1]
%   opt         - (Optional) Options structure with fields:
%                   .binWidth_dB - Histogram bin width in dB (default: 1.0)
%                   .smoothWin   - Moving average window size (default: 3)
%                                  Set to 1 to disable smoothing
%
% OUTPUT ARGUMENTS:
%   (none) - Generates a figure with overlaid PDF plots
%
% NOTES:
%   - Powers are converted to dB scale (dBm) before histogram computation
%   - Only valid measurements (P.valid == true) are included in the analysis
%   - Histogram normalization is set to 'pdf' for probability density comparison
function plotPdfCompare(obj, P, opt) %#ok<INUSD>
if nargin < 3 || isempty(opt), opt = struct(); end
if ~isfield(opt,"binWidth_dB"), opt.binWidth_dB = 1.0; end
if ~isfield(opt,"smoothWin"),   opt.smoothWin = 3; end

if isfield(P, "y_mW_raw") && isfield(P, "yhat_mW_raw")
    yUse = P.y_mW_raw;
    yhatUse = P.yhat_mW_raw;
else
    yUse = P.y_mW;
    yhatUse = P.yhat_mW;
end

valid = ~isnan(yUse) & ~isinf(yUse) & (yUse > 0) & ...
        ~isnan(yhatUse) & ~isinf(yhatUse) & (yhatUse > 0);
y_dBm    = 10*log10(yUse(valid));
yhat_dBm = 10*log10(yhatUse(valid));

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
xlabel('Power (dBm)', 'Interpreter', 'latex');
ylabel('PDF', 'Interpreter', 'latex');
title('PDF comparison: Ground truth y vs Prediction yhat', 'Interpreter', 'latex');
legend('y (GT)', 'yhat', 'Location', 'best', 'Interpreter', 'latex');
end
