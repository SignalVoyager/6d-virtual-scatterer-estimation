% predictOneTx - Predict values for one TX model and query pairsTR.
%
% SYNTAX:
%   powerHatDbm = predictOneTx(obj, txModel, pairsTR)
%
% INPUTS:
%   obj     - KrigingModel object.
%   txModel - one TX model struct from scatterInfo.txModels.
%   pairsTR - [N x 2] query pairs [tx_idx, rx_idx]. Only rx_idx is used
%             for XY mapping; tx_idx grouping is handled in predict().
%
% OUTPUT:
%   powerHat - [N x 1] predicted values in txModel.powerDomain.
function powerHat = predictOneTx(obj, txModel, pairsTR)
% Map query RX linear indices to XY centers.
gridSize = obj.GridSpec.gridSize;
areaSize = obj.GridSpec.areaSize;
Kx = floor(areaSize(1) / gridSize);
Ky = floor(areaSize(2) / gridSize);

rxIdx = pairsTR(:,2);
[ry, rx] = ind2sub([Ky, Kx], rxIdx);

xCenters = (-areaSize(1)/2 + gridSize/2) + gridSize*(rx-1);
yCenters = (-areaSize(2)/2 + gridSize/2) + gridSize*(ry-1);

xq = xCenters(:);
yq = yCenters(:);

if isfield(txModel, "zTrain")
    zTrain = txModel.zTrain;
elseif isfield(txModel, "powerTrainDbm")
    zTrain = txModel.powerTrainDbm;
    txModel.powerDomain = "dbm";
else
    error("[KrigingModel.predictOneTx] Missing training response field.");
end

switch string(txModel.type)
    case "kriging"
        powerHat = ok_ordinaryKriging( ...
            txModel.vstruct, ...
            txModel.xTrain, txModel.yTrain, zTrain, ...
            xq, yq, ...
            "KNeighbors", obj.KNeighbors);

    otherwise
        error("[KrigingModel.predictOneTx] Unsupported tx model type: %s", string(txModel.type));
end
end
