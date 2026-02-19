function zHatDb = predictOneTx(obj, txModel, xq, yq)
xq = xq(:); yq = yq(:);

switch string(txModel.type)
    case "kriging"
        zHatDb = ok_ordinaryKriging( ...
            txModel.vstruct, ...
            txModel.xTrain, txModel.yTrain, txModel.zTrain, ...
            xq, yq);

    case "fallback"
        fb = string(txModel.fallback);
        switch fb
            case "idw"
                zHatDb = ok_idwPredict(txModel.xTrain, txModel.yTrain, txModel.zTrain, xq, yq, obj.KrigingSpec.idwPower);
            case "nearest"
                zHatDb = ok_idwPredict(txModel.xTrain, txModel.yTrain, txModel.zTrain, xq, yq, 100); % strong nearest-like
            case "globalmean"
                zHatDb = obj.GlobalFallback.meanDb * ones(size(xq));
            otherwise
                zHatDb = txModel.meanDb * ones(size(xq));
        end

    otherwise
        zHatDb = obj.GlobalFallback.meanDb * ones(size(xq));
end
end