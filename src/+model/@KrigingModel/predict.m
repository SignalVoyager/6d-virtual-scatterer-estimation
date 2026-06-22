% predict - Predict Kriging power for transmitter-receiver pairs
%
% SYNTAX:
%   [gain_sum, gain_path, gamma_path] = predict(obj, pairsTR)
%
% DESCRIPTION:
%   Predicts received power for [tx_idx, rx_idx] pairs using per-TX trained
%   ordinary Kriging models. Predicted values are converted back to mW for
%   output consistency with other models.
%
% INPUT:
%   obj     - KrigingModel object with trained scatterInfo.txModels
%   pairsTR - [N x 2] array of [tx_idx, rx_idx] pairs
%
% OUTPUT:
%   gain_sum   - [N x 1] predicted power in mW
%   gain_path  - [] (not used by Kriging baseline)
%   gamma_path - [] (not used by Kriging baseline)
%
% NOTES:
%   - Requires train() to be called first.
%   - Queries are grouped by tx_idx and predicted per TX model.
%
% ERRORS:
%   - Raises error if scatterInfo.txModels is invalid.
%   - Raises error if pairsTR is empty or not [N x 2].
%   - Raises error if a queried tx_idx has no trained TX model.
function [gain_sum, gain_path, gamma_path] = predict(obj, pairsTR)
if isempty(obj.scatterInfo) || ~isfield(obj.scatterInfo,'txModels') || isempty(obj.scatterInfo.txModels) || ~isa(obj.scatterInfo.txModels, "containers.Map") || obj.scatterInfo.txModels.Count == 0
    error('[KrigingModel.predict] scatterInfo.txModels is invalid. Call train() first.');
end
if isempty(pairsTR) || size(pairsTR,2) ~= 2
    error('[KrigingModel.predict] pairsTR must be [N x 2].');
end

Mobs = size(pairsTR,1);
gain_sum = zeros(Mobs,1);
gain_path = [];
gamma_path= [];

txIdxAll = pairsTR(:,1);
uniqTx = unique(txIdxAll, 'stable');

% build lookup
txModels = obj.scatterInfo.txModels;

for i = 1:numel(uniqTx)
    txIdx = uniqTx(i);
    mask = (txIdxAll == txIdx);

    % find model
    modelKey = sprintf("%d", txIdx);
    if ~isKey(txModels, modelKey)
        error("[KrigingModel.predict] Missing TX model for tx_idx=%d.", txIdx);
    end

    txModel = txModels(modelKey);
    powerHat = predictOneTx(obj, txModel, pairsTR(mask,:));
    if isfield(txModel, "powerDomain")
        powerDomain = lower(string(txModel.powerDomain));
    else
        powerDomain = "dbm";
    end
    switch powerDomain
        case "dbm"
            gain_sum(mask) = 10.^(powerHat/10);
        case "linear"
            gain_sum(mask) = max(powerHat, 1e-12);
        otherwise
            error("[KrigingModel.predict] Unsupported powerDomain=%s.", powerDomain);
    end
end
end
