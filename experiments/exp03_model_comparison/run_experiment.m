% run_experiment.m (MODEL COMPARISON)
% Inputs injected: expRoot, seed

dataDir = fullfile(expRoot, "data");
outDir  = fullfile(expRoot, "outputs");
logDir = fullfile(outDir, "logs");
originalDir = fullfile(outDir, "original");
finalDir = fullfile(outDir, "final");
responseDir = fullfile(dataDir, "responses");
if ~isfolder(dataDir), mkdir(dataDir); end
if ~isfolder(outDir),  mkdir(outDir);  end
if ~isfolder(logDir), mkdir(logDir); end
if ~isfolder(originalDir), mkdir(originalDir); end
if ~isfolder(finalDir), mkdir(finalDir); end
if ~isfolder(responseDir), mkdir(responseDir); end

cfg = jsondecode(fileread(fullfile(expRoot, "config.json")));
if isstruct(cfg.dataSetList), cfg.dataSetList = num2cell(cfg.dataSetList); end
showFigures = logical(cfg.runtime.showFigures);

params = struct();
params.condaEnv = string(cfg.backend.condaEnv);
params.sionnaModule = fullfile(expRoot, string(cfg.backend.sionnaModule));
params.fc = cfg.radio.fc;
params.Pt_dBm = cfg.radio.Pt_dBm;
params.areaSize = cfg.grid.areaSize;
params.gridSize = cfg.grid.gridSize;
params.tx_pos_z = cfg.grid.tx_pos_z;
params.rx_pos_z = cfg.grid.rx_pos_z;

D = cfg.comparisonDesign;
preset = string(D.scenePreset);
scene = cfg.scenes.(char(preset));
sceneBaseName = "scene_" + preset;
params.stlFile = fullfile(dataDir, sceneBaseName + ".stl");
params.plyFile = fullfile(dataDir, sceneBaseName + ".ply");
params.xmlFile = fullfile(dataDir, sceneBaseName + ".xml");
params.scatterTable = scene.scatterTable;

envObj = env.WirelessEnvironment(params);
trainSamples = D.trainSamples;
fixedTxGridList = D.fixedTxGridList;
numTxTasks = size(fixedTxGridList, 1);

E = cfg.modelEvaluation;
eopt = struct();
eopt.whichSet = string(E.whichSet);
eopt.cgmSliceMode = string(E.cgmSliceMode);
eopt.cgmGridList = E.cgmGridList;
eopt.doPdf = showFigures && E.enablePdf;
eopt.doCgm = showFigures && E.enableCgm;
eopt.doResidual = showFigures && E.enableResidual;

% ---------- shared datasets ----------
sixDTrainSet = iLoadOrBuildSixDTrainSet(envObj, D.sixDTrainDataSet, dataDir, trainSamples);
fixedTxPools = cell(numTxTasks, 1);
for iTx = 1:numTxTasks
    fixedTxPools{iTx} = iLoadOrBuildFixedTxPool(envObj, D.fixedTxPool, fixedTxGridList(iTx, :), dataDir, iTx);
end

% ---------- proposed 6D: train once, evaluate on five fixed-TX test slices ----------
m6 = cfg.models.VirtualScatter6D;
params.responseFile = fullfile(expRoot, m6.responseFile);
metrics6 = cell(numTxTasks, 1);
for iTx = 1:numTxTasks
    model6 = iCreateVirtualScatter6D(params, m6.hyper, struct("trainSet", sixDTrainSet, "testSet", fixedTxPools{iTx}));
    if iTx == 1
        model6.train("mode", "save");
    else
        model6.train("mode", "load");
    end
    [~, metrics6{iTx}, ~] = model6.evaluate(eopt, fullfile(originalDir, sprintf("VirtualScatter6D_tx%02d_seed%d", iTx, seed)));
    close all;
end

% ---------- 3D baseline: five fixed-TX Monte Carlo tasks, geometry RX from pool ----------
m3 = cfg.models.VirtualScatter3D;
metrics3 = cell(numTxTasks, 1);
for iTx = 1:numTxTasks
    trainSet = iSelectGeometryRxFromPool(fixedTxPools{iTx}, params, D.threeDTrainSelection, trainSamples);
    params.responseFile = fullfile(responseDir, sprintf("response_virtualscatter3d_tx%02d.mat", iTx));
    ray = struct("trainSet", trainSet, "testSet", fixedTxPools{iTx});
    model3 = iCreateVirtualScatter3D(params, m3.hyper, ray);
    model3.train("mode", "save");
    [~, metrics3{iTx}, ~] = model3.evaluate(eopt, fullfile(originalDir, sprintf("VirtualScatter3D_tx%02d_seed%d", iTx, seed)));
    close all;
end

% ---------- Kriging baseline: five fixed-TX Monte Carlo tasks, random RX from pool ----------
mk = cfg.models.KrigingModel;
metricsK = cell(numTxTasks, 1);
for iTx = 1:numTxTasks
    trainSet = iSelectRandomRows(fixedTxPools{iTx}, trainSamples);
    params.responseFile = fullfile(responseDir, sprintf("response_kriging_tx%02d.mat", iTx));
    ray = struct("trainSet", trainSet, "testSet", fixedTxPools{iTx});
    modelK = iCreateKrigingModel(params, mk.hyper, ray);
    modelK.train("mode", "save");
    [~, metricsK{iTx}, ~] = modelK.evaluate(eopt, fullfile(originalDir, sprintf("KrigingModel_tx%02d_seed%d", iTx, seed)));
    close all;
end

comparisonTable = iBuildComparisonTable(cfg, trainSamples, metrics6, metrics3, metricsK);
outCsv = fullfile(finalDir, sprintf("model_comparison_table_seed%d.csv", seed));
outMat = fullfile(finalDir, sprintf("model_comparison_table_seed%d.mat", seed));
writetable(comparisonTable, outCsv);
save(outMat, "comparisonTable");
fprintf("[COMPARISON] Saved final comparison table: %s\n", outCsv);
fprintf("[COMPARISON] Done. preset=%s, outputs=%s\n", preset, outDir);

function data = iLoadOrBuildSixDTrainSet(envObj, spec, dataDir, trainSamples)
dataPath = fullfile(dataDir, string(spec.name) + ".mat");
dataMode = lower(string(spec.dataMode));
if dataMode == "load" && isfile(dataPath)
    data = envObj.loadDataset(dataPath);
    return;
end
if dataMode == "load"
    warning("[COMPARISON] Missing 6D train cache, generating once: %s", dataPath);
end
data = iBuildGeomTxRxPool(envObj, spec, dataPath, trainSamples);
end

function data = iBuildGeomTxRxPool(envObj, spec, dataPath, trainSamples)
maxSide = min(7, spec.maxBinSide);
radiusList = spec.radiusFallbacks;
data = zeros(0, 3);
batchIdx = 0;
while size(data, 1) < trainSamples
    batchIdx = batchIdx + 1;
    batch = iGenerateGeomBatch(envObj, spec, dataPath, batchIdx, maxSide, radiusList);
    data = [data; batch]; %#ok<AGROW>
    [~, ia] = unique(data(:,1:2), "rows", "stable");
    data = data(ia, :);
    fprintf("[COMPARISON] 6D geom pool batch=%d, unique samples=%d/%d\n", batchIdx, size(data, 1), trainSamples);
end
data = data(1:trainSamples, :);
envObj.saveDataset(dataPath, data);
end

function batch = iGenerateGeomBatch(envObj, spec, dataPath, batchIdx, maxSide, radiusList)
lastErr = [];
for iRadius = 1:size(radiusList, 1)
    rMin = radiusList(iRadius, 1);
    rMax = radiusList(iRadius, 2);
    for side = maxSide:-1:3
        [folder, baseName, ~] = fileparts(dataPath);
        batchPath = fullfile(folder, sprintf("%s_batch%02d_r%g_%g_side%d.mat", baseName, batchIdx, rMin, rMax, side));
        args = {"txNumPerSc", side, "rxNumPerSc", side, "radiationMin", rMin, "radiationMax", rMax};
        try
            batch = envObj.generateDataset(spec.Nt_side, spec.Nr_side, "save", "save", batchPath, ...
                "samplingMode", "geom-geom", "samplingArgs", args);
            fprintf("[COMPARISON] geom batch accepted: radius=[%g,%g], side=%d\n", rMin, rMax, side);
            return;
        catch ME
            lastErr = ME;
            warning("[COMPARISON] geom batch failed at radius=[%g,%g], side=%d: %s", rMin, rMax, side, ME.message);
        end
    end
end
rethrow(lastErr);
end

function data = iLoadOrBuildFixedTxPool(envObj, spec, txGridCR, dataDir, txTaskIdx)
dataPath = fullfile(dataDir, sprintf("fixedtx_pool_dense_tx%02d.mat", txTaskIdx));
dataMode = lower(string(spec.dataMode));
if dataMode == "load" && isfile(dataPath)
    data = envObj.loadDataset(dataPath);
    return;
end
if dataMode == "load"
    warning("[COMPARISON] Missing fixed-TX pool cache, generating once: %s", dataPath);
end
rxNum = spec.rxNum;
if rxNum < 0, rxNum = inf; end
data = envObj.generateDataset(spec.Nt_side, spec.Nr_side, "save", "save", dataPath, ...
    "samplingMode", "list-rand", "samplingArgs", {"txGridList", txGridCR, "rxNum", rxNum});
end

function data = iSelectGeometryRxFromPool(pool, params, selectionCfg, targetSamples)
rxIdx = pool(:, 2);
[rxXY, validMask] = iGridIdxToXY(rxIdx, params);
pool = pool(validMask, :);
rxXY = rxXY(validMask, :);

scatterTable = params.scatterTable;
centers = [scatterTable(:,1) + scatterTable(:,4)/2, scatterTable(:,2) + scatterTable(:,5)/2];
radiusList = selectionCfg.radiusFallbacks;
chosen = false(size(pool, 1), 1);

for iRadius = 1:size(radiusList, 1)
    rMin = radiusList(iRadius, 1);
    rMax = radiusList(iRadius, 2);
    for iSc = 1:size(centers, 1)
        d = hypot(rxXY(:,1) - centers(iSc, 1), rxXY(:,2) - centers(iSc, 2));
        cand = find(~chosen & d >= rMin & d < rMax);
        if isempty(cand), continue; end
        cand = cand(randperm(numel(cand)));
        need = targetSamples - nnz(chosen);
        chosen(cand(1:min(need, numel(cand)))) = true;
        if nnz(chosen) >= targetSamples
            data = pool(chosen, :);
            return;
        end
    end
end

if nnz(chosen) < targetSamples
    rest = find(~chosen);
    rest = rest(randperm(numel(rest)));
    need = targetSamples - nnz(chosen);
    chosen(rest(1:min(need, numel(rest)))) = true;
end
data = pool(chosen, :);
if size(data, 1) > targetSamples
    data = data(1:targetSamples, :);
end
end

function data = iSelectRandomRows(pool, targetSamples)
n = min(targetSamples, size(pool, 1));
idx = randperm(size(pool, 1), n);
data = pool(idx, :);
end

function [xy, validMask] = iGridIdxToXY(gridIdx, params)
gridSize = params.gridSize;
areaSize = params.areaSize;
Kx = floor(areaSize(1) / gridSize);
Ky = floor(areaSize(2) / gridSize);
validMask = gridIdx >= 1 & gridIdx <= Kx * Ky;
[row, col] = ind2sub([Ky, Kx], gridIdx(validMask));
x = ((col(:) - (Kx + 1) / 2) * gridSize);
y = ((row(:) - (Ky + 1) / 2) * gridSize);
xy = [x, y];
end

function modelObj = iCreateVirtualScatter6D(params, h, ray)
modelObj = model.VirtualScatter6D(params, "VirtualScatter6D", ray, ...
    "NumCenters", h.NumCenters, ...
    "PathLossExp", h.PathLossExp, ...
    "RefDistance", h.RefDistance, ...
    "EpsDist", h.EpsDist, ...
    "Solver", h.Solver);
end

function modelObj = iCreateVirtualScatter3D(params, h, ray)
modelObj = model.VirtualScatter3D(params, "VirtualScatter3D", ray, ...
    "NumCenters", h.NumCenters, ...
    "PathLossExp", h.PathLossExp, ...
    "RefDistance", h.RefDistance, ...
    "EpsDist", h.EpsDist, ...
    "Solver", h.Solver);
end

function modelObj = iCreateKrigingModel(params, h, ray)
if isfield(h, "PowerDomain")
    powerDomain = h.PowerDomain;
else
    powerDomain = "dbm";
end
modelObj = model.KrigingModel(params, "KrigingModel", ray, ...
    "MaxDistance", h.MaxDistance, ...
    "NumBins", h.NumBins, ...
    "StableAlpha", h.StableAlpha, ...
    "UseWeightedFit", logical(h.UseWeightedFit), ...
    "KNeighbors", h.KNeighbors, ...
    "PowerDomain", powerDomain);
end

function T = iBuildComparisonTable(cfg, trainSamples, metrics6, metrics3, metricsK)
keys = ["VirtualScatter6D", "VirtualScatter3D", "KrigingModel"];
metricSets = {metrics6, metrics3, metricsK};
rows = struct([]);
for i = 1:numel(keys)
    spec = iComparisonMethodSpec(cfg, keys(i));
    M = iAverageMetrics(metricSets{i});
    rows(i).Method = char(spec.displayName);
    rows(i).ModelKey = char(keys(i));
    rows(i).EvaluationAssumption = char(spec.evaluationAssumption);
    rows(i).SamplesUsedInExperiment = trainSamples;
    rows(i).Full6DDeploymentMultiplier = spec.deploymentMultiplier;
    rows(i).EquivalentFull6DSamples = trainSamples * spec.deploymentMultiplier;
    rows(i).NMAE = M.nmae;
    rows(i).MAE_dB = M.mae_dB;
end
T = struct2table(rows);
end

function avg = iAverageMetrics(metrics)
avg = struct();
if iscell(metrics)
    nmaeVals = cellfun(@(m) m.nmae, metrics);
    maeVals = cellfun(@(m) m.mae_dB, metrics);
else
    nmaeVals = arrayfun(@(m) m.nmae, metrics);
    maeVals = arrayfun(@(m) m.mae_dB, metrics);
end
avg.nmae = mean(nmaeVals, "omitnan");
avg.mae_dB = mean(maeVals, "omitnan");
end

function methodSpec = iComparisonMethodSpec(cfg, modelKey)
defaultMultiplier = cfg.comparisonTable.full6DDeploymentMultiplier;
methodSpec = struct("displayName", string(modelKey), ...
    "evaluationAssumption", "Not specified", ...
    "deploymentMultiplier", defaultMultiplier);
methods = cfg.comparisonTable.methods;
key = char(string(modelKey));
if isfield(methods, key)
    raw = methods.(key);
    if isfield(raw, "displayName"), methodSpec.displayName = string(raw.displayName); end
    if isfield(raw, "evaluationAssumption"), methodSpec.evaluationAssumption = string(raw.evaluationAssumption); end
    if isfield(raw, "deploymentMultiplier"), methodSpec.deploymentMultiplier = raw.deploymentMultiplier; end
end
end
