function plotCgmMap(obj, txGrid, opt)
% plotCgmMap - visualize predicted receiver power map (CGM) for one TX grid.
% Values are shown in dBm and invalid grids are excluded from prediction.
if nargin < 3 || isempty(opt), opt = struct(); end

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
