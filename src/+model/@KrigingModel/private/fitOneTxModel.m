function txModel = fitOneTxModel(obj, txIdx, x, y, zDb)
% 1) experimental variogram
if isempty(obj.KrigingSpec.maxDistance)
    % heuristic: diagonal of area
    L = norm(obj.GridSpec.areaSize);
    maxDist = 0.6 * L;
else
    maxDist = obj.KrigingSpec.maxDistance;
end

vg = ok_experimentalVariogram([x y], zDb, ...
    "MaxDistance", maxDist, ...
    "NumBins", obj.KrigingSpec.numBins);

% 2) fit stable variogram (alpha fixed)
vstruct = ok_fitStableVariogram(vg.distance, vg.gamma, ...
    "StableAlpha", obj.KrigingSpec.stableAlpha);

% 3) pack model
txModel = struct();
txModel.type = "kriging";
txModel.tx_idx = txIdx;
txModel.vstruct = vstruct;
txModel.xTrain = x(:);
txModel.yTrain = y(:);
txModel.zTrain = zDb(:);
txModel.meta = struct("n", numel(zDb), "maxDist", maxDist);
end