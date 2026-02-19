function txModel = makeFallbackModel(obj, txIdx, x, y, zDb, reason)
txModel = struct();
txModel.type = "fallback";
txModel.tx_idx = txIdx;
txModel.reason = string(reason);
txModel.fallback = obj.KrigingSpec.fallback;

txModel.xTrain = x(:);
txModel.yTrain = y(:);
txModel.zTrain = zDb(:);

if isempty(zDb)
    txModel.meanDb = obj.GlobalFallback.meanDb;
else
    txModel.meanDb = mean(zDb);
end
end