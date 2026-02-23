%% PLOTRESIDUALMAP
% Visualizes spatial prediction residuals for a scattering model across train+test samples.
%
% SYNTAX
%   plotResidualMap(obj, txGrid)
%   plotResidualMap(obj, txGrid, opt)
%
% DESCRIPTION
%   Generates a scatter plot of prediction errors (predicted minus target power in dB)
%   for all receiver locations associated with a specified transmitter grid point.
%   The function computes residuals from combined train and test datasets, applies
%   noise floor corrections, and highlights regions with large prediction errors.
%
% INPUTS
%   obj         ScatteringModel object with raytracing results and prediction capability
%   txGrid      [N x 2] array of transmitter grid coordinates [col, row] where
%               col ranges in [1, Kx] and row ranges in [1, Ky]
%
% OPTIONAL PARAMETERS (opt structure)
%   topPercentile   Percentile threshold for highlighting large-error points
%                   Default: 95 (highlights top 5% of absolute residuals)
%   q               Noise floor quantile for signal clipping
%                   Default: 0.02
%   eps_min         Minimum value to prevent log(0) in dB conversion
%                   Default: 1e-12
%
% OUTPUT
%   Figure with scatter plot showing:
%   - Spatial distribution of receivers colored by residual magnitude
%   - Transmitter location marked with pentagon
%   - Scatterer rectangles with labels
%   - Circles highlighting largest prediction errors
%
% NOTES
%   - Warnings issued if no train/test samples exist for specified transmitter
%   - Invalid values (NaN, Inf, negative) in predictions/targets are zeroed
%   - Residual is defined as 10*log10(predicted/target) in dB
function plotResidualMap(obj, txGrid, opt)
if nargin < 3 || isempty(opt), opt = struct(); end
if ~isfield(opt,"topPercentile"), opt.topPercentile = 95; end
if ~isfield(opt,"q"), opt.q = 0.02; end
if ~isfield(opt,"eps_min"), opt.eps_min = 1e-12; end

C = obj.getPlotContext();
Kx = C.Kx; Ky = C.Ky;
xCenters = C.xCenters; yCenters = C.yCenters;
scatterTable = C.scatterTable;
gridSize = C.gridSize;

% txGrid: [col,row]
assert(all(txGrid(:,1) >= 1 & txGrid(:,1) <= Kx), 'col out of range.');
assert(all(txGrid(:,2) >= 1 & txGrid(:,2) <= Ky), 'row out of range.');
txGridIdx = sub2ind([Ky, Kx], txGrid(:,2), txGrid(:,1));

% collect samples for this TX from train+test
pairsTR = [obj.raytracingResults.trainSet; obj.raytracingResults.testSet];
pairsTR = pairsTR(pairsTR(:,1) == txGridIdx, :);

if isempty(pairsTR)
    warning('[plot] No train/test samples found for tx_idx=%d. Skip diagnostic plots.', txGridIdx);
    return;
end

y_mW    = pairsTR(:,3);
yhat_mW = obj.predict(pairsTR(:,1:2));
[y_mW, yhat_mW] = applyNoiseFloor(y_mW, yhat_mW, opt.q, opt.eps_min);

eps_mW = opt.eps_min;
bad_true = isnan(y_mW) | isinf(y_mW) | (y_mW < 0); y_mW(bad_true) = 0;
bad_pred = isnan(yhat_mW) | isinf(yhat_mW) | (yhat_mW < 0); yhat_mW(bad_pred) = 0;

y_dBm    = 10*log10(max(y_mW, eps_mW));
yhat_dBm = 10*log10(max(yhat_mW, eps_mW));

res_dB  = yhat_dBm - y_dBm;
abs_res = abs(res_dB);

[ry, rx] = ind2sub([Ky, Kx], pairsTR(:,2));
rx_xy = [xCenters(rx).', yCenters(ry).'];

figure;
scatter(rx_xy(:,1), rx_xy(:,2), 40, res_dB, 'filled'); hold on;
set(gca, 'YDir', 'normal');
axis equal;
xlim([xCenters(1)-gridSize/2, xCenters(end)+gridSize/2]);
ylim([yCenters(1)-gridSize/2, yCenters(end)+gridSize/2]);
colorbar;
title(sprintf('10log10(hhat/h) (dB), TX=%d (train+test)', txGridIdx), 'Interpreter', 'latex');
xlabel('x (m)', 'Interpreter', 'latex'); ylabel('y (m)', 'Interpreter', 'latex');

% mark TX
[ty, tx] = ind2sub([Ky, Kx], txGridIdx);
tx_pos = [xCenters(tx), yCenters(ty)];
plot(tx_pos(1), tx_pos(2), 'p', 'MarkerSize', 14, 'LineWidth', 2);
text(tx_pos(1), tx_pos(2), '  TX', 'FontWeight', 'bold', 'VerticalAlignment','middle', 'Interpreter', 'latex');

% draw scatterers
for n = 1:size(scatterTable,1)
    rectangle('Position', [scatterTable(n,1), scatterTable(n,2), scatterTable(n,4), scatterTable(n,5)], 'LineWidth', 1.2);
    text(scatterTable(n,1), scatterTable(n,2), sprintf(' S%d', n), 'FontWeight','bold', 'VerticalAlignment','bottom', 'Interpreter', 'latex');
end

% highlight large-error points (top percentile)
thr = prctile(abs_res, opt.topPercentile);
idx_bad = find(abs_res >= thr);
plot(rx_xy(idx_bad,1), rx_xy(idx_bad,2), 'o', 'MarkerSize', 10, 'LineWidth', 1.8);
end
