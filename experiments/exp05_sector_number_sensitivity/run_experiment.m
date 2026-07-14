% run_experiment.m (SECTOR-NUMBER SENSITIVITY)
% Inputs injected by main_all_experiments.m: expRoot, seed

dataDir = fullfile(expRoot, "data");
outDir = fullfile(expRoot, "outputs");
logDir = fullfile(outDir, "logs");
originalDir = fullfile(outDir, "original");
finalDir = fullfile(outDir, "final");
metricDir = fullfile(originalDir, "metrics");
modelOriginalDir = fullfile(originalDir, "model");
responseDir = fullfile(dataDir, "responses");
dirs = {dataDir, outDir, logDir, originalDir, finalDir, metricDir, modelOriginalDir, responseDir};
for iDir = 1:numel(dirs)
    if ~isfolder(dirs{iDir}), mkdir(dirs{iDir}); end
end

cfg = jsondecode(fileread(fullfile(expRoot, "config.json")));
if isstruct(cfg.dataSetList), cfg.dataSetList = num2cell(cfg.dataSetList); end
showFigures = logical(cfg.runtime.showFigures);
cacheSeed = seed;
if isfield(cfg.runtime, "dataCacheSeed"), cacheSeed = cfg.runtime.dataCacheSeed; end

S = cfg.sectorSensitivity;
metricName = string(S.metric);
rtTag = iPropagationTagFromConfig(cfg);
cleanCfg = iCleaningConfig(cfg);
if isfield(cfg.runtime, "refreshFinalOnly") && logical(cfg.runtime.refreshFinalOnly)
    iRefreshFinal(originalDir, finalDir, metricName, S, rtTag);
    return;
end

params = iBaseParams(cfg, dataDir, expRoot, S);
envObj = env.WirelessEnvironment(params);
if ~isfile(params.stlFile) || ~isfile(params.xmlFile)
    envObj.datasetScene("save");
end

testSpec = iDataSetSpec(cfg.dataSetList, string(cfg.models.VirtualScatter6D.datasetSelection.testSet));
testSet = iLoadOrBuildTestSet(envObj, params, testSpec, dataDir, expRoot, S);
testSet = iCleanPowerDataSet(testSet, cleanCfg, "test");
fprintf("[M-SENS] Test set ready: %d pairs.\n", size(testSet, 1));
fprintf("[M-SENS] Ray tracing order: %d reflections, %d diffractions.\n", params.maxRef, params.maxDif);

E = cfg.modelEvaluation;
eopt = struct();
eopt.whichSet = string(E.whichSet);
eopt.cgmSliceMode = string(E.cgmSliceMode);
eopt.cgmGridList = E.cgmGridList;
eopt.doPdf = showFigures && logical(E.enablePdf);
eopt.doCgm = showFigures && logical(E.enableCgm);
eopt.doResidual = showFigures && logical(E.enableResidual);
if isfield(E, "q"), eopt.q = E.q; end
if isfield(E, "eps_min"), eopt.eps_min = E.eps_min; end
if isfield(E, "eps_mW"), eopt.eps_mW = E.eps_mW; end

MList = S.MList(:).';
numRepeats = S.numRepeats;
numScatterers = size(params.scatterTable, 1);
rows = struct([]);
rowIdx = 0;
fprintf("[M-SENS] preset=%s, numScatterers=%d, MList=%s, metric=%s\n", ...
    string(S.scenePreset), numScatterers, mat2str(MList), metricName);

for iM = 1:numel(MList)
    sectorM = MList(iM);
    sampleSide = iResolveSampleSide(S.trainSampling, sectorM);
    requestedSamples = numScatterers * sampleSide * sampleSide;

    for iRepeat = 1:numRepeats
        trainTag = sprintf("M%d_K%d_n%d_%s_rep%02d_seed%d", sectorM, sampleSide, requestedSamples, iPropagationTag(params), iRepeat, cacheSeed);
        trainPath = fullfile(dataDir, "train_" + string(trainTag) + ".mat");
        trainSet = iLoadOrBuildTrainSet(envObj, params, S.trainSampling, sectorM, sampleSide, requestedSamples, trainPath);
        trainSet = iCleanPowerDataSet(trainSet, cleanCfg, sprintf("train M=%d K=%d seed=%d", sectorM, sampleSide, seed));

        runTag = sprintf("M%d_K%d_n%d_%s_rep%02d_seed%d", sectorM, sampleSide, requestedSamples, iPropagationTag(params), iRepeat, seed);
        params.responseFile = fullfile(responseDir, "response_" + string(runTag) + ".mat");
        if logical(cfg.runtime.forceRetrain) && isfile(params.responseFile)
            delete(params.responseFile);
        end

        ray = struct("trainSet", trainSet, "testSet", testSet);
        fprintf("\n[M-SENS] M=%d | K=%d | repeat=%d/%d | requested=%d | actual=%d | test=%d\n", ...
            sectorM, sampleSide, iRepeat, numRepeats, requestedSamples, size(trainSet, 1), size(testSet, 1));

        modelObj = iCreateVirtualScatter6D(params, cfg.models.VirtualScatter6D.hyper, sectorM, ray);
        modelObj.train("mode", "save");
        [P, M, B] = modelObj.evaluate(eopt, fullfile(modelOriginalDir, runTag));
        close all;

        rowIdx = rowIdx + 1;
        rows(rowIdx).seed = seed;
        rows(rowIdx).repeat = iRepeat;
        rows(rowIdx).M = sectorM;
        rows(rowIdx).sampleSide = sampleSide;
        rows(rowIdx).numScatterers = numScatterers;
        rows(rowIdx).requestedSamples = requestedSamples;
        rows(rowIdx).actualSamples = size(trainSet, 1);
        rows(rowIdx).testSamples = size(testSet, 1);
        rows(rowIdx).numSectorPairs = sectorM * sectorM;
        rows(rowIdx).samplesPerScatterer = sampleSide * sampleSide;
        rows(rowIdx).numResponseCoefficients = numScatterers * sectorM * sectorM;
        rows(rowIdx).samplesPerCoefficient = size(trainSet, 1) / max(rows(rowIdx).numResponseCoefficients, 1);
        rows(rowIdx).rmse_dB = M.rmse_dB;
        rows(rowIdx).mae_dB = M.mae_dB;
        rows(rowIdx).p90ae_dB = M.p90ae_dB;
        rows(rowIdx).bias_dB = M.bias_dB;
        rows(rowIdx).nmse = M.nmse;
        rows(rowIdx).nmae = M.nmae;
        rows(rowIdx).relRMSE = M.relRMSE;
        rows(rowIdx).rho_y_yhat = M.rho_y_yhat;
        rows(rowIdx).nValid = M.nValid;
        rows(rowIdx).eval_q = iGetFieldOrDefault(eopt, "q", NaN);
        rows(rowIdx).eval_eps_min = iGetFieldOrDefault(eopt, "eps_min", NaN);
        rows(rowIdx).eval_eps_mW = iGetFieldOrDefault(eopt, "eps_mW", NaN);

        save(fullfile(metricDir, "metrics_" + string(runTag) + ".mat"), ...
            "P", "M", "B", "sectorM", "sampleSide", "requestedSamples", "trainSet", "testSet", "seed");
    end
end

rawTable = struct2table(rows);
rawCsv = fullfile(originalDir, sprintf("sector_number_raw_%s_seed%d.csv", rtTag, seed));
writetable(rawTable, rawCsv);
save(fullfile(originalDir, sprintf("sector_number_raw_%s_seed%d.mat", rtTag, seed)), "rawTable");
iRefreshFinal(originalDir, finalDir, metricName, S, rtTag);
fprintf("[M-SENS] Done. Raw metrics: %s\n", rawCsv);

function params = iBaseParams(cfg, dataDir, expRoot, S)
preset = string(S.scenePreset);
scene = cfg.scenes.(char(preset));
sceneBaseName = "scene_" + preset;
params = struct();
params.condaEnv = string(cfg.backend.condaEnv);
params.sionnaModule = fullfile(expRoot, string(cfg.backend.sionnaModule));
params.fc = cfg.radio.fc;
params.Pt_dBm = cfg.radio.Pt_dBm;
params.areaSize = cfg.grid.areaSize;
params.gridSize = cfg.grid.gridSize;
params.tx_pos_z = cfg.grid.tx_pos_z;
params.rx_pos_z = cfg.grid.rx_pos_z;
params.stlFile = fullfile(dataDir, sceneBaseName + ".stl");
params.plyFile = fullfile(dataDir, sceneBaseName + ".ply");
params.xmlFile = fullfile(dataDir, sceneBaseName + ".xml");
params.scatterTable = scene.scatterTable;
params.maxRef = 5;
params.maxDif = 2;
if isfield(cfg.backend, "maxRef"), params.maxRef = cfg.backend.maxRef; end
if isfield(cfg.backend, "maxDif"), params.maxDif = cfg.backend.maxDif; end
end

function value = iGetFieldOrDefault(s, fieldName, defaultValue)
if isfield(s, fieldName)
    value = s.(fieldName);
else
    value = defaultValue;
end
end

function tag = iPropagationTag(params)
tag = sprintf("%dR%dD", params.maxRef, params.maxDif);
end

function tag = iPropagationTagFromConfig(cfg)
maxRef = 5;
maxDif = 2;
if isfield(cfg.backend, "maxRef"), maxRef = cfg.backend.maxRef; end
if isfield(cfg.backend, "maxDif"), maxDif = cfg.backend.maxDif; end
tag = sprintf("%dR%dD", maxRef, maxDif);
end

function sampleSide = iResolveSampleSide(trainCfg, sectorM)
if isfield(trainCfg, "sampleSideByM")
    key = sprintf("M%d", sectorM);
    if isfield(trainCfg.sampleSideByM, key)
        sampleSide = trainCfg.sampleSideByM.(key);
        return;
    end
end
offset = 0;
if isfield(trainCfg, "sampleSideOffset"), offset = trainCfg.sampleSideOffset; end
sampleSide = sectorM + offset;
if isfield(trainCfg, "sampleSideMin"), sampleSide = max(sampleSide, trainCfg.sampleSideMin); end
if isfield(trainCfg, "sampleSideMax"), sampleSide = min(sampleSide, trainCfg.sampleSideMax); end
sampleSide = round(sampleSide);
assert(sampleSide > 0, "[M-SENS] sampleSide must be positive.");
end

function cleanCfg = iCleaningConfig(cfg)
cleanCfg = struct("enabled", false, "method", "fixed_floor", ...
    "floor_dBm", -120.0, "q", 0.017, "eps_min_mW", 1e-12);
if isfield(cfg, "dataCleaning")
    userCfg = cfg.dataCleaning;
    if isfield(userCfg, "enabled"), cleanCfg.enabled = logical(userCfg.enabled); end
    if isfield(userCfg, "method"), cleanCfg.method = string(userCfg.method); end
    if isfield(userCfg, "floor_dBm"), cleanCfg.floor_dBm = userCfg.floor_dBm; end
    if isfield(userCfg, "q"), cleanCfg.q = userCfg.q; end
    if isfield(userCfg, "eps_min_mW"), cleanCfg.eps_min_mW = userCfg.eps_min_mW; end
end
end

function data = iCleanPowerDataSet(data, cleanCfg, label)
if ~cleanCfg.enabled || isempty(data)
    return;
end
p = data(:,3);
if lower(string(cleanCfg.method)) == "fixed_floor" && isfinite(cleanCfg.floor_dBm)
    floorMw = max(10.^(cleanCfg.floor_dBm/10), cleanCfg.eps_min_mW);
else
    positive = p(isfinite(p) & p > 0);
    if isempty(positive)
        floorMw = cleanCfg.eps_min_mW;
    else
        floorMw = max(quantile(positive, cleanCfg.q), cleanCfg.eps_min_mW);
    end
end
rawBad = ~isfinite(p) | p <= 0;
p(rawBad) = floorMw;
clipMask = p < floorMw;
nClipped = nnz(rawBad) + nnz(clipMask);
p(clipMask) = floorMw;
data(:,3) = p;
fprintf("[M-SENS] Cleaning %s: floor=%.3e mW (%.2f dBm), clipped %d/%d.\n", ...
    label, floorMw, 10*log10(floorMw), nClipped, numel(p));
end

function spec = iDataSetSpec(list, name)
for i = 1:numel(list)
    if string(list{i}.name) == string(name)
        spec = list{i};
        return;
    end
end
error("[M-SENS] Dataset spec not found: %s", name);
end

function data = iLoadOrBuildTestSet(envObj, params, spec, dataDir, expRoot, S)
testPath = fullfile(dataDir, string(spec.name) + ".mat");
if ~isfile(testPath) && isfield(S, "testCacheSource") && strlength(string(S.testCacheSource)) > 0
    sourcePath = fullfile(expRoot, string(S.testCacheSource));
    if isfile(sourcePath)
        fprintf("[M-SENS] Reusing external test cache: %s\n", sourcePath);
        copyfile(sourcePath, testPath);
    end
end
dataMode = lower(string(spec.dataMode));
if dataMode == "load" && isfile(testPath)
    [data, cacheOk] = iLoadDatasetWithRtSpec(testPath, iRtSpec(params));
    if ~cacheOk
        warning("[M-SENS] Test cache has no matching RT metadata; using it as an externally supplied fixed test set: %s", testPath);
        data = envObj.loadDataset(testPath);
    end
    return;
end
if dataMode == "load"
    warning("[M-SENS] Test cache missing, generating once: %s", testPath);
    dataMode = "save";
end
[samplingMode, samplingArgs] = iParseSamplingSpec(spec);
if dataMode == "save"
    data = iBuildLocalDataset(envObj, params, spec.Nt_side, spec.Nr_side, samplingMode, samplingArgs, testPath);
else
    error("[M-SENS] Unsupported test dataMode: %s", dataMode);
end
end

function trainSet = iLoadOrBuildTrainSet(envObj, params, trainCfg, sectorM, sampleSide, requestedSamples, trainPath)
if isfile(trainPath)
    [trainSet, cacheOk] = iLoadDatasetWithRtSpec(trainPath, iRtSpec(params));
    if cacheOk && size(trainSet, 1) >= requestedSamples
        trainSet = trainSet(1:requestedSamples, :);
        return;
    end
    if ~cacheOk
        warning("[M-SENS] Ignoring stale train cache without matching RT metadata: %s", trainPath);
    end
    warning("[M-SENS] Cached train set has only %d rows; regenerating: %s", size(trainSet, 1), trainPath);
end

fallbacks = trainCfg.radiusFallbacks;
lastErr = [];
for iRadius = 1:size(fallbacks, 1)
    rMin = fallbacks(iRadius, 1);
    rMax = fallbacks(iRadius, 2);
    try
        args = {"txNumPerSc", sampleSide, "rxNumPerSc", sampleSide, ...
            "radiationMin", rMin, "radiationMax", rMax};
        fprintf("[M-SENS] Generating geom-geom train cache: M=%d, K=%d, radius=[%g,%g], target=%d\n", ...
            sectorM, sampleSide, rMin, rMax, requestedSamples);
        rawSet = iBuildLocalDataset(envObj, params, trainCfg.Nt_side, trainCfg.Nr_side, "geom-geom", args, trainPath);
        [~, ia] = unique(rawSet(:,1:2), "rows", "stable");
        trainSet = rawSet(sort(ia), :);
        if size(trainSet, 1) >= requestedSamples
            trainSet = trainSet(1:requestedSamples, :);
            envObj.saveDataset(trainPath, trainSet);
            return;
        end
        warning("[M-SENS] Radius=[%g,%g] produced only %d/%d unique samples.", ...
            rMin, rMax, size(trainSet, 1), requestedSamples);
    catch ME
        lastErr = ME;
        warning("[M-SENS] Geom train generation failed at M=%d, K=%d, radius=[%g,%g]: %s", ...
            sectorM, sampleSide, rMin, rMax, ME.message);
    end
end
if ~isempty(lastErr), rethrow(lastErr); end
error("[M-SENS] Could not generate enough unique training samples for M=%d, K=%d.", sectorM, sampleSide);
end

function data = iBuildLocalDataset(envObj, params, Nt_side, Nr_side, samplingMode, samplingArgs, outPath)
blocks = envObj.datasetSampling(samplingMode, samplingArgs{:});
data = iTraceBlocksMatlab(params, blocks, Nt_side, Nr_side);
iSaveDatasetWithRtSpec(outPath, data, iRtSpec(params));
end

function rtSpec = iRtSpec(params)
rtSpec = struct("backend", "matlab-local", ...
    "maxRef", params.maxRef, "maxDif", params.maxDif, ...
    "NtNote", "stored per dataset call", "material", "concrete");
end

function iSaveDatasetWithRtSpec(filePath, data, rtSpec)
folder = fileparts(filePath);
if ~isfolder(folder), mkdir(folder); end
Results = data;
save(filePath, "Results", "rtSpec", "-v7.3");
end

function [data, ok] = iLoadDatasetWithRtSpec(filePath, expectedRtSpec)
ok = false;
vars = who("-file", filePath);
if ~any(strcmp(vars, "Results"))
    data = zeros(0, 3);
    return;
end
S = load(filePath, "Results");
data = S.Results;
if any(strcmp(vars, "rtSpec"))
    R = load(filePath, "rtSpec");
    ok = isequaln(R.rtSpec, expectedRtSpec);
end
end

function Results = iTraceBlocksMatlab(params, Blocks, Nt_side, Nr_side)
if isempty(Blocks)
    Results = zeros(0, 3);
    return;
end
state = struct();
Results = zeros(0, 3);
for b = 1:numel(Blocks)
    txSel = Blocks(b).txSel(:);
    rxSel = Blocks(b).rxSel(:);
    if isempty(txSel) || isempty(rxSel), continue; end

    [txPos, rxPos, meta] = iExpandGridSamples(params, txSel, rxSel, Nt_side, Nr_side);
    fprintf("[M-SENS] RT block %d/%d: ref=%d dif=%d, TX=%d grids, RX=%d grids, TXsamp=%d, RXsamp=%d\n", ...
        b, numel(Blocks), params.maxRef, params.maxDif, meta.Ntx, meta.Nrx, meta.Ns_tx, meta.Ns_rx);

    [P_dBm, state] = iRtMatlabLocal(txPos, rxPos, params, state);
    P_mW = 10.^(P_dBm/10).';
    P4 = reshape(P_mW, meta.Ns_rx, meta.Nrx, meta.Ns_tx, meta.Ntx);
    avgGrid = reshape(mean(mean(P4, 1), 3), meta.Nrx, meta.Ntx);
    [Itx, Irx] = ndgrid(1:meta.Ntx, 1:meta.Nrx);
    txList = txSel(Itx(:));
    rxList = rxSel(Irx(:));
    powList = avgGrid(sub2ind([meta.Nrx, meta.Ntx], Irx(:), Itx(:)));
    Results = [Results; [txList, rxList, powList]]; %#ok<AGROW>
end
Results = iAggregatePairs(Results);
end

function [P_dBm, state] = iRtMatlabLocal(txPos, rxPos, params, state)
if ~isfield(state, "viewer") || ~isvalid(state.viewer)
    state.viewer = siteviewer("SceneModel", params.stlFile, "Visible", "off");
end
if ~isfield(state, "pm") || isempty(state.pm)
    state.pm = propagationModel("raytracing", ...
        "Method", "sbr", ...
        "CoordinateSystem", "cartesian", ...
        "MaxNumReflections", params.maxRef, ...
        "MaxNumDiffractions", params.maxDif, ...
        "SurfaceMaterial", "concrete");
end
txSites = txsite("cartesian", ...
    "AntennaPosition", txPos, ...
    "TransmitterFrequency", params.fc, ...
    "TransmitterPower", 10.^((params.Pt_dBm - 30)/10));
rxSites = rxsite("cartesian", "AntennaPosition", rxPos);
P_dBm = sigstrength(rxSites, txSites, state.pm, "Map", state.viewer);
clear txSites rxSites
end

function [tx_pos, rx_pos, meta] = iExpandGridSamples(params, txIdxList, rxIdxList, Nt_side, Nr_side)
areaSize = params.areaSize;
gridSize = params.gridSize;
Kx = floor(areaSize(1) / gridSize);
Ky = floor(areaSize(2) / gridSize);
txIdxList = txIdxList(:);
rxIdxList = rxIdxList(:);
Ntx = numel(txIdxList);
Nrx = numel(rxIdxList);

[ty, tx] = ind2sub([Ky, Kx], txIdxList);
txCenter = [ ...
    (-areaSize(1)/2 + gridSize/2) + gridSize * (tx - 1), ...
    (-areaSize(2)/2 + gridSize/2) + gridSize * (ty - 1)];

[ry, rx] = ind2sub([Ky, Kx], rxIdxList);
rxCenter = [ ...
    (-areaSize(1)/2 + gridSize/2) + gridSize * (rx - 1), ...
    (-areaSize(2)/2 + gridSize/2) + gridSize * (ry - 1)];

txOffsets = ((1:Nt_side) - (Nt_side+1)/2) * (gridSize/Nt_side);
[dxTx, dyTx] = meshgrid(txOffsets, txOffsets);
txDelta = [dxTx(:), dyTx(:)];
Ns_tx = size(txDelta, 1);

rxOffsets = ((1:Nr_side) - (Nr_side+1)/2) * (gridSize/Nr_side);
[dxRx, dyRx] = meshgrid(rxOffsets, rxOffsets);
rxDelta = [dxRx(:), dyRx(:)];
Ns_rx = size(rxDelta, 1);

txSamples = kron(txCenter, ones(Ns_tx, 1)) + repmat(txDelta, Ntx, 1);
rxSamples = kron(rxCenter, ones(Ns_rx, 1)) + repmat(rxDelta, Nrx, 1);
tx_pos = [txSamples, params.tx_pos_z * ones(size(txSamples, 1), 1)].';
rx_pos = [rxSamples, params.rx_pos_z * ones(size(rxSamples, 1), 1)].';
meta = struct("Ntx", Ntx, "Nrx", Nrx, "Ns_tx", Ns_tx, "Ns_rx", Ns_rx);
end

function Results = iAggregatePairs(Results)
if isempty(Results), return; end
Results = Results(Results(:,1) ~= Results(:,2), :);
[pairs, ~, ic] = unique(Results(:,1:2), "rows", "stable");
pow = accumarray(ic, Results(:,3), [], @mean);
Results = [pairs, pow];
end

function modelObj = iCreateVirtualScatter6D(params, hyper, sectorM, ray)
modelObj = model.VirtualScatter6D(params, "VirtualScatter6D", ray, ...
    "NumCenters", sectorM, ...
    "PathLossExp", hyper.PathLossExp, ...
    "RefDistance", hyper.RefDistance, ...
    "EpsDist", hyper.EpsDist, ...
    "Solver", hyper.Solver);
end

function [samplingMode, samplingArgs] = iParseSamplingSpec(ds)
samplingMode = string(ds.samplingMode);
samplingArgs = {};
if ~isfield(ds, "samplingArgs") || isempty(ds.samplingArgs)
    return;
end
names = fieldnames(ds.samplingArgs);
samplingArgs = cell(1, 2*numel(names));
for i = 1:numel(names)
    value = ds.samplingArgs.(names{i});
    if strcmp(names{i}, "rxNum") && value < 0
        value = inf;
    end
    samplingArgs{2*i-1} = names{i};
    samplingArgs{2*i} = value;
end
end

function iRefreshFinal(originalDir, finalDir, metricName, S, rtTag)
files = dir(fullfile(originalDir, sprintf("sector_number_raw_%s_seed*.csv", rtTag)));
if isempty(files)
    error("[M-SENS] Cannot aggregate. No raw CSV files found for %s in %s", rtTag, originalDir);
end
tables = cell(numel(files), 1);
for i = 1:numel(files)
    tables{i} = readtable(fullfile(files(i).folder, files(i).name));
end
rawAll = iVertcatTablesUnion(tables);
summaryTable = iAggregateByM(rawAll, metricName);
summaryCsv = fullfile(finalDir, sprintf("sector_number_summary_%s.csv", rtTag));
writetable(summaryTable, summaryCsv);
save(fullfile(finalDir, sprintf("sector_number_summary_%s.mat", rtTag)), "summaryTable", "rawAll");
iPlotSummary(summaryTable, metricName, fullfile(finalDir, "sector_number_sensitivity_" + metricName + "_" + rtTag), S);
fprintf("[M-SENS] Final outputs refreshed: %s\n", summaryCsv);
end

function T = iVertcatTablesUnion(tables)
allNames = strings(1, 0);
for i = 1:numel(tables)
    allNames = [allNames, string(tables{i}.Properties.VariableNames)]; %#ok<AGROW>
end
allNames = cellstr(unique(allNames, "stable"));
for i = 1:numel(tables)
    T_i = tables{i};
    for j = 1:numel(allNames)
        name = allNames{j};
        if ~ismember(name, T_i.Properties.VariableNames)
            T_i.(name) = iMissingColumnFor(name, height(T_i), tables);
        end
    end
    tables{i} = T_i(:, allNames);
end
T = vertcat(tables{:});
end

function col = iMissingColumnFor(name, nRows, tables)
template = [];
for i = 1:numel(tables)
    if ismember(name, tables{i}.Properties.VariableNames)
        template = tables{i}.(name);
        break;
    end
end
if isnumeric(template) || islogical(template)
    col = NaN(nRows, 1);
elseif isstring(template)
    col = strings(nRows, 1);
elseif iscell(template)
    col = repmat({''}, nRows, 1);
else
    col = strings(nRows, 1);
end
end

function summaryTable = iAggregateByM(rawTable, metricName)
metricKey = char(metricName);
if ~ismember(metricKey, rawTable.Properties.VariableNames)
    error("[M-SENS] Metric column not found in raw table: %s", metricKey);
end
MList = unique(rawTable.M, "stable");
rows = struct([]);
for i = 1:numel(MList)
    m = MList(i);
    mask = rawTable.M == m;
    values = rawTable.(metricKey)(mask);
    rows(i).M = m;
    if ismember("sampleSide", string(rawTable.Properties.VariableNames))
        rows(i).sampleSide = round(mean(rawTable.sampleSide(mask), "omitnan"));
    else
        rows(i).sampleSide = m;
    end
    rows(i).trainSamples = round(mean(rawTable.requestedSamples(mask), "omitnan"));
    rows(i).samplesPerCoefficient = mean(rawTable.samplesPerCoefficient(mask), "omitnan");
    rows(i).meanMetric = mean(values, "omitnan");
    rows(i).stdMetric = std(values, "omitnan");
    rows(i).numRuns = nnz(mask);
    rows(i).semMetric = rows(i).stdMetric / sqrt(max(rows(i).numRuns, 1));
    rows(i).ci95Metric = 1.96 * rows(i).semMetric;
end
summaryTable = sortrows(struct2table(rows), "M");
end

function iPlotSummary(summaryTable, metricName, saveBase, S)
fig = figure("Color", "w", "Visible", "off");
set(fig, "DefaultTextInterpreter", "latex");
set(fig, "DefaultLegendInterpreter", "latex");
hold on; grid on; box on;
plotCfg = iPlotConfig(S);
yerr = iResolveError(summaryTable, plotCfg.errorBar);
e = errorbar(summaryTable.M, summaryTable.meanMetric, yerr, "-o", ...
    "Color", [0.12 0.36 0.70], "LineWidth", 2.6, "MarkerSize", 8, ...
    "MarkerFaceColor", "w", "MarkerEdgeColor", [0.12 0.36 0.70], "CapSize", 8);
e.DisplayName = "Geometry-guided sampling";
for i = 1:height(summaryTable)
    text(summaryTable.M(i), summaryTable.meanMetric(i), ...
        sprintf("  K=%d, n=%d", summaryTable.sampleSide(i), summaryTable.trainSamples(i)), ...
        "VerticalAlignment", "bottom", "FontName", "Times New Roman", ...
        "FontSize", 12, "Interpreter", "latex");
end
xlabel("Number of sectors $M$", "Interpreter", "latex");
ylabel(iMetricDisplayName(metricName, plotCfg.errorBar), "Interpreter", "latex");
xticks(summaryTable.M);
if ~isempty(plotCfg.yLim), ylim(plotCfg.yLim); end
if ~isempty(plotCfg.yTicks), yticks(plotCfg.yTicks); end
legend("Location", "best", "Interpreter", "latex");
ax = gca;
set(ax, "FontName", "Times New Roman", "FontSize", 16, ...
    "LineWidth", 0.9, "TickLabelInterpreter", "latex");
exportgraphics(fig, string(saveBase) + ".png", "Resolution", 300);
exportgraphics(fig, string(saveBase) + ".pdf", "ContentType", "vector");
savefig(fig, string(saveBase) + ".fig");
close(fig);
end

function plotCfg = iPlotConfig(S)
plotCfg = struct("errorBar", "std", "yLim", [], "yTicks", []);
if isfield(S, "plot")
    P = S.plot;
    if isfield(P, "errorBar"), plotCfg.errorBar = lower(string(P.errorBar)); end
    if isfield(P, "yLim") && ~isempty(P.yLim)
        plotCfg.yLim = P.yLim(:).';
        if any(isnan(plotCfg.yLim)), plotCfg.yLim = []; end
    end
    if isfield(P, "yTicks") && ~isempty(P.yTicks), plotCfg.yTicks = P.yTicks(:).'; end
end
end

function yerr = iResolveError(T, errorBar)
switch lower(string(errorBar))
    case "std"
        yerr = T.stdMetric;
    case "sem"
        yerr = T.semMetric;
    case "ci95"
        yerr = T.ci95Metric;
    otherwise
        yerr = zeros(height(T), 1);
end
end

function label = iMetricDisplayName(metricName, errorBar)
switch string(metricName)
    case "mae_dB"
        base = "MAE (dB)";
    case "rmse_dB"
        base = "RMSE (dB)";
    case "p90ae_dB"
        base = "90th-percentile AE (dB)";
    otherwise
        base = char(metricName);
end
if string(errorBar) ~= "none"
    label = sprintf("%s (mean $\\pm$ %s)", base, char(errorBar));
else
    label = base;
end
end
