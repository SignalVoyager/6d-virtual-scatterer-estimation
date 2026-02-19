% plotCgmMap - Visualize predicted receiver power map (CGM) for one TX grid position.
%
% Syntax:
%   plotCgmMap(obj, txGrid)
%   plotCgmMap(obj, txGrid, opt)
%
% Description:
%   Generates a 2D power map visualization showing predicted receiver power levels
%   for all valid grid points with respect to a single transmitter grid position.
%   Power values are displayed in dBm with invalid grids excluded from the prediction.
%   The visualization includes transmitter location, grid cells, and scatterer 
%   positions overlaid on the power map.
%
% Input Arguments:
%   obj     - ScatteringModel object containing the model configuration and prediction method
%   txGrid  - [Ntx x 2] array of transmitter grid positions in [col, row] format
%             where col is in range [1, Kx] and row is in range [1, Ky]
%   opt     - (optional) Configuration structure for plotting options (default: empty struct)
%
% Output:
%   None. Displays a figure with the power map visualization.
%
% Notes:
%   - Invalid grid points are excluded from power prediction
%   - Power values are clipped to display range [1st percentile, 99th percentile]
%   - Transmitter position is marked with a 'p' marker
%   - Scatterer rectangles and labels are overlaid on the map
%   - Axes are set to equal aspect ratio with normal y-direction orientation
%
% See Also:
%   predict, getPlotContext, sub2ind
function plotCgmMap(obj, txGrid, ~)
C = obj.getPlotContext();
Kx = C.Kx; Ky = C.Ky; K = C.K;
xCenters = C.xCenters; yCenters = C.yCenters;
invalidMask = C.invalidMask;
scatterTable = C.scatterTable;
gridSize = C.gridSize;

% txGrid: [col,row]
assert(all(txGrid(:,1) >= 1 & txGrid(:,1) <= Kx), 'col out of range.');
assert(all(txGrid(:,2) >= 1 & txGrid(:,2) <= Ky), 'row out of range.');
txGridIdx = sub2ind([Ky, Kx], txGrid(:,2), txGrid(:,1));

fprintf('[%s.plot] Reconstructing CKM for tx_idx=%d (K=%d grids)\n', obj.ModelSpec.modelId, txGridIdx, K);

yhat = nan(Ky, Kx);
validLin = find(~invalidMask(:));
pairsTR = [repmat(txGridIdx, numel(validLin), 1), validLin];

gain_vec = obj.predict(pairsTR);        % [Nvalid x 1] (mW)
gain_vec(gain_vec < 0) = NaN;
yhat(validLin) = gain_vec;

figure;
yhat_dBm = 10*log10(yhat);
imagesc(xCenters, yCenters, yhat_dBm); hold on;
set(gca, 'YDir', 'normal');
axis equal tight;
xlim([xCenters(1)-gridSize/2, xCenters(end)+gridSize/2]);
ylim([yCenters(1)-gridSize/2, yCenters(end)+gridSize/2]);

vals = yhat_dBm(~isnan(yhat_dBm));
if ~isempty(vals)
    clim([prctile(vals, 1), prctile(vals, 99)]);
end
colorbar;
title(sprintf('Pred CGM (dBm, TX grid index = %d)', txGridIdx));
xlabel('x (m)'); ylabel('y (m)');

% mark TX
[ty, tx] = ind2sub([Ky, Kx], txGridIdx);
tx_pos = [xCenters(tx), yCenters(ty)];
plot(tx_pos(1), tx_pos(2), 'p', 'MarkerSize', 14, 'LineWidth', 2);
text(tx_pos(1), tx_pos(2), '  TX', 'FontWeight', 'bold', 'VerticalAlignment','middle');

% draw scatterers
for n = 1:size(scatterTable,1)
    rectangle('Position', [scatterTable(n,1), scatterTable(n,2), scatterTable(n,4), scatterTable(n,5)], 'LineWidth', 1.5);
    text(scatterTable(n,1), scatterTable(n,2), sprintf(' S%d', n), 'FontWeight','bold', 'VerticalAlignment','bottom');
end
end
