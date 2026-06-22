% TRAIN Trains per-transmitter Kriging models using raytracing results
%
% SYNTAX:
%   train(obj)
%   train(obj, Name, Value)
%
% DESCRIPTION:
%   Performs per-transmitter training in 2D spatial domain (x,y) using
%   ordinary Kriging in dBm space.
%
% INPUT PARAMETERS:
%   obj          - KrigingModel object
%   mode         - (Name-Value) Training mode, one of:
%                  "fit"   - Train and store model in memory (default)
%                  "load"  - Load previously trained model from disk
%                  "save"  - Train and save model to disk
%
% ALGORITHM:
%   For each unique transmitter in the training set:
%   1. Extract TX-specific pairsTR=[tx_idx, rx_idx] and powMw
%   2. Inside fitOneTxModel: map RX index to (x,y), convert mW to dBm
%   3. Fit per-TX variogram + ordinary Kriging model
%
% OUTPUT:
%   Populates obj.scatterInfo with:
%   - txModels: containers.Map keyed by tx_idx string
%   - meta:     Training metadata and hyperparameters
%
% NOTES:
%   - Requires obj.raytracingResults.trainSet to be populated
%   - Uses model properties: MaxDistance, NumBins, StableAlpha
%
% SEE ALSO:
%   fitOneTxModel, predict, loadModel, saveModel
function train(obj, varargin)
p = inputParser;
p.addParameter("mode", "fit");
p.parse(varargin{:});
mode = lower(string(p.Results.mode));

if mode == "load"
    obj.loadModel();
    return;
end

trainSet = obj.raytracingResults.trainSet;

txList = unique(trainSet(:,1), 'stable');
txModels = containers.Map('KeyType','char','ValueType','any');

fprintf("[KrigingModel.train] TX count=%d\n", numel(txList));

for k = 1:numel(txList)
    txIdx = txList(k);
    subSet = trainSet((trainSet(:,1) == txIdx), :);

    pairsTR = subSet(:,1:2);
    powMw = subSet(:,3);

    txModel = fitOneTxModel(obj, pairsTR, powMw);
    
    modelKey = sprintf("%d", txModel.tx_idx);
    txModels(modelKey) = txModel;

    fprintf("[KrigingModel.train] progress %d/%d\n", k, numel(txList));
end

obj.scatterInfo = struct( ...
    "txModels", txModels, ...
    "meta", struct( ...
        "MaxDistance", obj.MaxDistance, ...
        "NumBins", obj.NumBins, ...
        "StableAlpha", obj.StableAlpha, ...
        "UseWeightedFit", obj.UseWeightedFit, ...
        "KNeighbors", obj.KNeighbors, ...
        "PowerDomain", obj.PowerDomain));

if mode == "save"
    obj.saveModel();
end
end

