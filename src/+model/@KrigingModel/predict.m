function [gain_sum, gain_path, gamma_path] = predict(obj, pairsTR, varargin)
% predict - predict power in mW for [N x 2] pairsTR = [tx_idx, rx_idx]
if isempty(pairsTR)
    gain_sum = zeros(0,1);
    gain_path = [];
    gamma_path = [];
    return;
end
assert(size(pairsTR,2)==2, "[KrigingModel.predict] pairsTR must be [N x 2].");

if isempty(obj.TxModels) || obj.TxModels.Count == 0
    error("[KrigingModel.predict] Model not trained/loaded.");
end

txAll = pairsTR(:,1);
rxAll = pairsTR(:,2);
N = size(pairsTR,1);

gain_sum = nan(N,1);

% group queries by tx
txList = unique(txAll, 'stable');
for i = 1:numel(txList)
    txIdx = txList(i);
    qmask = (txAll == txIdx);

    modelKey = obj.txKey(txIdx);
    if ~isKey(obj.TxModels, modelKey)
        % unseen TX: global fallback
        zHatDb = obj.GlobalFallback.meanDb * ones(nnz(qmask),1);
        gain_sum(qmask) = 10.^(zHatDb/10);
        continue;
    end

    txModel = obj.TxModels(modelKey);
    rxIdx = rxAll(qmask);
    [xq, yq] = obj.rxIdxToXY(rxIdx);

    zHatDb = obj.predictOneTx(txModel, xq, yq);
    gain_sum(qmask) = 10.^(zHatDb/10);
end

gain_path = [];
gamma_path = [];
end