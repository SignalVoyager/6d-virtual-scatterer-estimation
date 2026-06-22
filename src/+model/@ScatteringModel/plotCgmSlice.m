% plotCgmSlice - Visualize 2D slice of 6D CKM
%
% Syntax:
%   plotCgmSlice(obj, mode, gridPos)
%
% Description:
%   Visualizes a 2D slice of the 6D CKM by fixing either
%   Tx or Rx position and sweeping the other across the grid.
%
% Input Arguments:
%   obj      - 6D CKM model object
%   mode     - 'fixTx' or 'fixRx'
%   gridPos  - [col, row] grid index to fix
%
% Notes:
%   - Invalid grids excluded
%   - Power displayed in dBm
%   - Scatterers overlaid
%   - Color scale clipped to [1%, 99%]

function plotCgmSlice(obj, mode, gridPos)

C = obj.getPlotContext();
Kx = C.Kx; 
Ky = C.Ky; 

xCenters = C.xCenters; 
yCenters = C.yCenters;
if isfield(C, 'plotMask')
    plotMask = C.plotMask;
else
    plotMask = C.invalidMask;
end
scatterTable = C.scatterTable;
gridSize = C.gridSize;

assert(any(strcmp(mode, {'fixTx','fixRx'})), 'Invalid mode.');
assert(all(gridPos(1) >= 1 & gridPos(1) <= Kx), 'col out of range.');
assert(all(gridPos(2) >= 1 & gridPos(2) <= Ky), 'row out of range.');

fixedIdx = sub2ind([Ky, Kx], gridPos(2), gridPos(1));
validLin = find(~plotMask(:));

fprintf('[%s.plot6D] mode=%s, fixed_idx=%d\n', ...
    obj.ModelSpec.modelId, mode, fixedIdx);

yhat = nan(Ky, Kx);

switch mode

    case 'fixTx'
        % Tx fixed, sweep Rx
        pairsTR = [repmat(fixedIdx, numel(validLin), 1), validLin];

    case 'fixRx'
        % Rx fixed, sweep Tx
        pairsTR = [validLin, repmat(fixedIdx, numel(validLin), 1)];

end

gain_vec = obj.predict(pairsTR);   % mW
gain_vec(gain_vec < 0) = NaN;
yhat(validLin) = gain_vec;

% -------- Visualization --------
figure;

yhat_dBm = 10*log10(yhat);
imagesc(xCenters, yCenters, yhat_dBm); hold on;

set(gca, 'YDir', 'normal');
axis equal tight;

xlim([xCenters(1)-gridSize/2, xCenters(end)+gridSize/2]);
ylim([yCenters(1)-gridSize/2, yCenters(end)+gridSize/2]);

vals = yhat_dBm(~isnan(yhat_dBm));
if ~isempty(vals)
    clim([prctile(vals,1), prctile(vals,99)]);
end

cb = colorbar;
cb.Label.String = 'Received power (dBm)';
cb.Label.Interpreter = 'latex';
set(gca, 'FontSize', 16);

if strcmp(mode,'fixTx')
    title(sprintf('6D CKM Slice (Fix TX idx=%d)', fixedIdx), 'Interpreter', 'latex', 'FontSize', 20);
else
    title(sprintf('6D CKM Slice (Fix RX idx=%d)', fixedIdx), 'Interpreter', 'latex', 'FontSize', 20);
end

xlabel('x (m)', 'Interpreter', 'latex', 'FontSize', 18);
ylabel('y (m)', 'Interpreter', 'latex', 'FontSize', 18);

% ---- Mark fixed position ----
[fy, fx] = ind2sub([Ky, Kx], fixedIdx);
fixed_pos = [xCenters(fx), yCenters(fy)];

plot(fixed_pos(1), fixed_pos(2), 'p', ...
    'MarkerSize', 16, 'LineWidth', 2);

if strcmp(mode,'fixTx')
    text(fixed_pos(1), fixed_pos(2), '  TX', ...
        'FontWeight','bold','VerticalAlignment','middle', 'Interpreter', 'latex', 'FontSize', 18);
else
    text(fixed_pos(1), fixed_pos(2), '  RX', ...
        'FontWeight','bold','VerticalAlignment','middle', 'Interpreter', 'latex', 'FontSize', 18);
end

% ---- Draw scatterers ----
for n = 1:size(scatterTable,1)
    rectangle('Position', ...
        [scatterTable(n,1), scatterTable(n,2), ...
         scatterTable(n,4), scatterTable(n,5)], ...
        'LineWidth', 1.5);
    text(scatterTable(n,1), scatterTable(n,2), ...
        sprintf(' S%d', n), ...
        'FontWeight','bold','VerticalAlignment','bottom', 'Interpreter', 'latex', 'FontSize', 16);
end

end
