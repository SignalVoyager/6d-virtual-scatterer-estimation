% fitOneTxModel - Fit one TX-specific Kriging payload from raw pairsTR/powMw.
%
% SYNTAX:
%   txModel = fitOneTxModel(obj, pairsTR, powMw)
%
% INPUTS:
%   obj     - KrigingModel object.
%   pairsTR - [N x 2] array of [tx_idx, rx_idx] for one TX group.
%   powMw   - [N x 1] received power observations in mW.
%
% OUTPUT:
%   txModel - struct containing:
%             .type = "kriging"
%             .tx_idx
%             .vstruct (fitted stable variogram params)
%             .xTrain, .yTrain, .zTrain, .powerDomain
%             .meta (diagnostic metadata)
function txModel = fitOneTxModel(obj, pairsTR, powMw)
assert(size(pairsTR,2) == 2, "[KrigingModel.fitOneTxModel] pairsTR must be [N x 2].");
assert(numel(powMw) == size(pairsTR,1), ...
    "[KrigingModel.fitOneTxModel] powMw length must match pairsTR rows.");

% Decode grid geometry and map RX linear index to XY centers.
gridSize = obj.GridSpec.gridSize;
areaSize = obj.GridSpec.areaSize;

Kx = floor(areaSize(1) / gridSize);
Ky = floor(areaSize(2) / gridSize);

rxIdx = pairsTR(:,2);
txIdx = unique(pairsTR(:,1), 'stable');

[ry, rx] = ind2sub([Ky, Kx], rxIdx);
xCenters = (-areaSize(1)/2 + gridSize/2) + gridSize*(rx-1);
yCenters = (-areaSize(2)/2 + gridSize/2) + gridSize*(ry-1);

x = xCenters(:);
y = yCenters(:);

switch obj.PowerDomain
    case "dbm"
        zTrain = 10*log10(max(powMw, 1e-12));
        zTrain(isinf(zTrain)) = -100;
    case "linear"
        zTrain = max(powMw, 1e-12);
    otherwise
        error("[KrigingModel.fitOneTxModel] Unsupported PowerDomain=%s", obj.PowerDomain);
end

% Build binned experimental variogram.
maxDist = obj.MaxDistance;

vg = ok_experimentalVariogram([x y], zTrain, ...
    "MaxDistance", maxDist, ...
    "NumBins", obj.NumBins);

% Fit stable variogram parameters from experimental bins.
vstruct = ok_fitStableVariogram(vg.distance, vg.gamma, ...
    "StableAlpha", obj.StableAlpha, ...
    "BinCount", vg.count, ...
    "UseWeightedLS", obj.UseWeightedFit);

% Pack TX model payload for prediction.
txModel = struct();
txModel.type = "kriging";
txModel.tx_idx = txIdx(1);
txModel.vstruct = vstruct;
txModel.xTrain = x(:);
txModel.yTrain = y(:);
txModel.zTrain = zTrain(:);
txModel.powerDomain = obj.PowerDomain;
txModel.meta = struct( ...
    "n", numel(zTrain), ...
    "maxDist", maxDist, ...
    "useWeightedFit", obj.UseWeightedFit, ...
    "powerDomain", obj.PowerDomain);
end
