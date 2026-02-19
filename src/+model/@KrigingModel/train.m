function train(obj, varargin)
% train - fit per-TX kriging models using training set.
%
% Optional name-value:
%   "mode" : "fit"|"save"|"load" (default "fit")
p = inputParser;
p.addParameter("mode", "fit");
p.parse(varargin{:});
mode = string(p.Results.mode);

if mode == "load"
    obj.loadModel();
    return;
end

trainSet = obj.raytracingResults.trainSet;
assert(~isempty(trainSet), "[KrigingModel.train] Empty trainSet.");

% Global fallback: mean in dB (ignoring non-positive)
y = trainSet(:,3);
y = y(y>0);
if isempty(y)
    globalMeanDb = -100;
else
    globalMeanDb = mean(10*log10(y));
end
obj.GlobalFallback.meanDb = globalMeanDb;

% Group by TX
txAll = trainSet(:,1);
txList = unique(txAll, 'stable');

if obj.KrigingSpec.verbose
    fprintf("[KrigingModel.train] TX count=%d, minSamplesPerTx=%d\n", ...
        numel(txList), obj.KrigingSpec.minSamplesPerTx);
end

for i = 1:numel(txList)
    txIdx = txList(i);
    mask = (txAll == txIdx);
    sub = trainSet(mask, :);
    rxIdx = sub(:,2);
    powMw = sub(:,3);

    % Convert rx index to XY
    [x, yxy] = obj.rxIdxToXY(rxIdx);
    zDb = 10*log10(max(powMw, 1e-12));
    zDb(isinf(zDb)) = -100;

    % Optional subsampling for speed (keep stable but random)
    if numel(zDb) > obj.KrigingSpec.maxPairsForFit
        keep = randperm(numel(zDb), obj.KrigingSpec.maxPairsForFit);
        x = x(keep); yxy = yxy(keep); zDb = zDb(keep);
    end

    modelKey = obj.txKey(txIdx);

    try
        if numel(zDb) < obj.KrigingSpec.minSamplesPerTx
            txModel = obj.makeFallbackModel(txIdx, x, yxy, zDb, "too_few_samples");
        else
            txModel = obj.fitOneTxModel(txIdx, x, yxy, zDb);
        end
    catch ME
        txModel = obj.makeFallbackModel(txIdx, x, yxy, zDb, "fit_failed:" + string(ME.identifier));
        if obj.KrigingSpec.verbose
            warning("[KrigingModel.train] TX=%d fit failed: %s", txIdx, ME.message);
        end
    end

    obj.TxModels(modelKey) = txModel;

    if obj.KrigingSpec.verbose && mod(i, max(1, floor(numel(txList)/10))) == 0
        fprintf("[KrigingModel.train] progress %d/%d\n", i, numel(txList));
    end
end

% Store into scatterInfo for save/load compatibility
obj.scatterInfo = struct();
obj.scatterInfo.modelType = "KrigingModel";
obj.scatterInfo.KrigingSpec = obj.KrigingSpec;
obj.scatterInfo.GlobalFallback = obj.GlobalFallback;
obj.scatterInfo.TxModels = obj.TxModels; % containers.Map is savable in MAT

if mode == "save"
    obj.saveModel();
end
end