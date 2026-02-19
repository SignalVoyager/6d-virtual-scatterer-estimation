function printKrigingTrainingSummary(obj)
keys = obj.TxModels.keys;
nTx = numel(keys);
nKrig = 0;
nFb = 0;
nSamp = zeros(nTx,1);

for i = 1:nTx
    m = obj.TxModels(keys{i});
    if isfield(m,"meta") && isfield(m.meta,"n")
        nSamp(i) = m.meta.n;
    elseif isfield(m,"zTrain")
        nSamp(i) = numel(m.zTrain);
    end
    if string(m.type) == "kriging", nKrig = nKrig + 1; else, nFb = nFb + 1; end
end

fprintf("[KrigingModel] fitted kriging TX=%d/%d, fallback TX=%d/%d\n", nKrig, nTx, nFb, nTx);
fprintf("[KrigingModel] samples/Tx: min=%d, median=%d, max=%d\n", min(nSamp), round(median(nSamp)), max(nSamp));
end