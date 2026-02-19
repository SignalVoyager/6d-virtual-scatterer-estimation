function evaluate(obj, whichSet, viewMode, varargin)
% evaluate - visualize ray tracing outputs
% whichSet: "train" or "test"
% viewMode:
%   "txHeatmap" -> heatmap for a specific TX index (requires orderTx)
%   "rxCount"   -> count of RX observations per grid
%   "txCount"   -> count of TX observations per grid
if isempty(obj.raytracingResults)
    error('[WirelessEnvironment] No raytracingResults to plot.');
end

% pick data table: [tx, rx, p_mW]
if whichSet == "train"
    data = obj.raytracingResults.trainSet;
    titlePrefix = "Train";
else
    data = obj.raytracingResults.testSet;
    titlePrefix = "Test";
end

txAll = data(:,1);
rxAll = data(:,2);
y_mW  = data(:,3);

% grid config
gridSize = obj.GridSpec.gridSize;
areaSize = obj.GridSpec.areaSize;
scattererTable = obj.SceneSpec.scatterTable;

Kx = floor(areaSize(1)/gridSize);
Ky = floor(areaSize(2)/gridSize);

xCenters = (-areaSize(1)/2 + gridSize/2) : gridSize : (areaSize(1)/2 - gridSize/2);
yCenters = (-areaSize(2)/2 + gridSize/2) : gridSize : (areaSize(2)/2 - gridSize/2);

switch string(viewMode)
    case "txHeatmap"
        uniqTx = unique(txAll, 'stable');
        orderTx  = varargin{1};

        if orderTx > numel(uniqTx), error('orderTx out of range.'); end
        txGridIdx = uniqTx(orderTx);

        sel = (txAll == txGridIdx);
        rxGridIdx = rxAll(sel);
        h_lin  = y_mW(sel);

        powerMap = nan(Ky, Kx);
        for i = 1:numel(rxGridIdx)
            [iy, ix] = ind2sub([Ky, Kx], rxGridIdx(i));
            powerMap(iy, ix) = h_lin(i);
        end

        figure;
        imagesc(xCenters, yCenters, 10*log10(powerMap));
        set(gca,'YDir','normal'); axis equal tight;
        colorbar; xlabel('x (m)'); ylabel('y (m)');
        title(sprintf('%s: RX heatmap (dBm), TX grid = %d', titlePrefix, txGridIdx));

        hold on;
        [ty, tx] = ind2sub([Ky, Kx], txGridIdx);
        plot(xCenters(tx), yCenters(ty), 'p', 'MarkerSize', 14, 'LineWidth', 2);
        text(xCenters(tx), yCenters(ty), '  TX', 'FontWeight', 'bold', 'VerticalAlignment','middle');

    case "rxCount"
        cntMap = zeros(Ky, Kx);
        for i = 1:numel(rxAll)
            [iy, ix] = ind2sub([Ky, Kx], rxAll(i));
            cntMap(iy, ix) = cntMap(iy, ix) + 1;
        end

        figure;
        imagesc(xCenters, yCenters, cntMap);
        set(gca,'YDir','normal'); axis equal tight;
        colorbar; xlabel('x (m)'); ylabel('y (m)');
        title(sprintf('%s: RX sampling count map', titlePrefix));

    case "txCount"
        cntMap = zeros(Ky, Kx);
        for i = 1:numel(txAll)
            [iy, ix] = ind2sub([Ky, Kx], txAll(i));
            cntMap(iy, ix) = cntMap(iy, ix) + 1;
        end

        figure;
        imagesc(xCenters, yCenters, cntMap);
        set(gca,'YDir','normal'); axis equal tight;
        colorbar; xlabel('x (m)'); ylabel('y (m)');
        title(sprintf('%s: TX sampling count map', titlePrefix));

    otherwise
        error('Unknown viewMode: %s', viewMode);
end

% draw scatterers
hold on;
for n = 1:size(scattererTable,1)
    rectangle('Position', [scattererTable(n,1), scattererTable(n,2), scattererTable(n,4), scattererTable(n,5)], 'LineWidth', 1.5);
    text(scattererTable(n,1), scattererTable(n,2), sprintf(' S%d', n), 'FontWeight','bold', 'VerticalAlignment','bottom');
end
end
    