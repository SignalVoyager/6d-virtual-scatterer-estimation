% run_experiment.m (SAMPLING ABLATION)
% Inputs injected by main_all_experiments.m: expRoot, seed

dataDir = fullfile(expRoot, "data");
outDir  = fullfile(expRoot, "outputs");
logDir = fullfile(outDir, "logs");
originalDir = fullfile(outDir, "original");
finalDir = fullfile(outDir, "final");
metricDir = fullfile(originalDir, "metrics");
poolDir = fullfile(dataDir, "pools");
modelOriginalDir = fullfile(originalDir, "model");

if ~isfolder(dataDir), mkdir(dataDir); end
if ~isfolder(outDir),  mkdir(outDir);  end
if ~isfolder(logDir), mkdir(logDir); end
if ~isfolder(originalDir), mkdir(originalDir); end
if ~isfolder(finalDir), mkdir(finalDir); end
if ~isfolder(metricDir), mkdir(metricDir); end
if ~isfolder(poolDir), mkdir(poolDir); end
if ~isfolder(modelOriginalDir), mkdir(modelOriginalDir); end

cfg = jsondecode(fileread(fullfile(expRoot, "config.json")));
if isstruct(cfg.dataSetList), cfg.dataSetList = num2cell(cfg.dataSetList); end
showFigures = logical(cfg.runtime.showFigures);
cacheSeed = seed;
if isfield(cfg.runtime, "dataCacheSeed")
    cacheSeed = cfg.runtime.dataCacheSeed;
end

if isfield(cfg.runtime, "refreshFinalOnly") && logical(cfg.runtime.refreshFinalOnly)
    metricName = string(cfg.ablation.metric);
    rawCsv = fullfile(originalDir, sprintf("sampling_ablation_raw_seed%d.csv", seed));
    if ~isfile(rawCsv)
        error("[ABLATION] Cannot refresh final outputs. Missing raw metrics CSV: %s", rawCsv);
    end

    rawTable = readtable(rawCsv);
    rawTable = iEnsureMetricColumn(rawTable, metricName, metricDir, seed);
    summaryTable = iAggregateMetrics(rawTable, metricName);
    summaryCsv = fullfile(finalDir, sprintf("sampling_ablation_summary_seed%d.csv", seed));
    writetable(summaryTable, summaryCsv);

    saveBase = fullfile(finalDir, sprintf("sampling_ablation_%s_seed%d", metricName, seed));
    iPlotSummary(summaryTable, metricName, saveBase, cfg.ablation);
    fprintf("[ABLATION] Refreshed final outputs only. metric=%s, summary=%s\n", metricName, summaryCsv);
    return;
end

% ---------- build params ----------
params = struct();
params.condaEnv = string(cfg.backend.condaEnv);
params.sionnaModule = fullfile(expRoot, string(cfg.backend.sionnaModule));
params.fc = cfg.radio.fc;
params.Pt_dBm = cfg.radio.Pt_dBm;
params.areaSize = cfg.grid.areaSize;
params.gridSize = cfg.grid.gridSize;
params.tx_pos_z = cfg.grid.tx_pos_z;
params.rx_pos_z = cfg.grid.rx_pos_z;

% ---------- scene + fixed test set ----------
preset = string(cfg.ablation.scenePreset);
scene = cfg.scenes.(char(preset));
sceneBaseName = "scene_" + preset;
params.stlFile = fullfile(dataDir, sceneBaseName + ".stl");
params.plyFile = fullfile(dataDir, sceneBaseName + ".ply");
params.xmlFile = fullfile(dataDir, sceneBaseName + ".xml");
params.scatterTable = scene.scatterTable;

envObj = env.WirelessEnvironment(params);
testSpec = iFindDataSetSpec([cfg.dataSetList{:}], string(cfg.models.VirtualScatter6D.datasetSelection.testSet));
testSet = iBuildOneDataSet(envObj, testSpec, dataDir);

% ---------- evaluation options ----------
E = cfg.modelEvaluation;
eopt = struct();
eopt.whichSet = string(E.whichSet);
eopt.cgmSliceMode = string(E.cgmSliceMode);
eopt.cgmGridList = E.cgmGridList;
eopt.doPdf = showFigures && logical(E.enablePdf);
eopt.doCgm = showFigures && logical(E.enableCgm);
eopt.doResidual = showFigures && logical(E.enableResidual);

% ---------- ablation loop ----------
A = cfg.ablation;
sampleSides = A.sampleSides(:).';
sampleCounts = size(params.scatterTable, 1) .* sampleSides .* sampleSides;
numRepeats = A.numRepeats;
metricName = string(A.metric);
schemes = A.schemes;
if ~iscell(schemes), schemes = num2cell(schemes); end

rows = struct([]);
rowIdx = 0;
fprintf("[ABLATION] preset=%s, test samples=%d, metric=%s\n", preset, size(testSet, 1), metricName);

for iScheme = 1:numel(schemes)
    scheme = schemes{iScheme};
    schemeKey = string(scheme.key);
    dataKey = iSchemeDataKey(scheme);
    maxCount = max(sampleCounts);

    for iRepeat = 1:numRepeats
        trainPool = [];
        if string(scheme.samplingMode) ~= "geom-geom"
            poolName = sprintf("pool_%s_rep%02d_seed%d.mat", char(dataKey), iRepeat, cacheSeed);
            poolPath = fullfile(poolDir, poolName);
            poolMode = iResolveSchemePoolMode(cfg, scheme, dataKey, poolPath);
            trainPool = iBuildPool(envObj, scheme, max(sampleSides), maxCount, poolPath, cfg, poolMode);
            if isempty(trainPool)
                warning("[ABLATION] Empty pool for scheme=%s repeat=%d. Skip.", schemeKey, iRepeat);
                continue;
            end
        end

        for iCount = 1:numel(sampleCounts)
            sampleSide = sampleSides(iCount);
            requestedCount = sampleCounts(iCount);
            if string(scheme.samplingMode) == "geom-geom"
                geomSetName = sprintf("train_%s_n%d_rep%02d_seed%d.mat", ...
                    char(dataKey), requestedCount, iRepeat, cacheSeed);
                geomSetPath = fullfile(poolDir, geomSetName);
                poolMode = iResolveSchemePoolMode(cfg, scheme, dataKey, geomSetPath);
                trainSet = iBuildGeomPool(envObj, scheme, sampleSide, requestedCount, geomSetPath, ...
                    poolMode);
                trainSet = iSubsampleRows(trainSet, requestedCount);
            else
                trainSet = iSubsampleRows(trainPool, requestedCount);
            end
            actualCount = size(trainSet, 1);
            if actualCount < requestedCount
                warning("[ABLATION] scheme=%s repeat=%d requested %d samples but pool has %d.", ...
                    schemeKey, iRepeat, requestedCount, actualCount);
            end

            runTag = sprintf("%s_n%d_rep%02d_seed%d", char(schemeKey), requestedCount, iRepeat, seed);
            params.responseFile = fullfile(dataDir, "responses", "response_" + string(runTag) + ".mat");
            responseDir = fileparts(params.responseFile);
            if ~isfolder(responseDir), mkdir(responseDir); end
            if logical(cfg.runtime.forceRetrain) && isfile(params.responseFile)
                delete(params.responseFile);
            end

            raytracingResults = struct("trainSet", trainSet, "testSet", testSet);
            envObj.raytracingResults = raytracingResults;

            fprintf("\n[ABLATION] %s | repeat=%d/%d | requested=%d | actual=%d\n", ...
                schemeKey, iRepeat, numRepeats, requestedCount, actualCount);

            modelObj = iCreateModel(params, cfg.models.VirtualScatter6D, scheme, raytracingResults);
            modelObj.train("mode", "save");

            evalSavePath = fullfile(modelOriginalDir, runTag);
            [P, M, B] = modelObj.evaluate(eopt, evalSavePath);
            close all;

            rowIdx = rowIdx + 1;
            rows(rowIdx).seed = seed;
            rows(rowIdx).scheme = char(schemeKey);
            rows(rowIdx).schemeLabel = char(string(scheme.label));
            rows(rowIdx).dataKey = char(dataKey);
            rows(rowIdx).repeat = iRepeat;
            rows(rowIdx).sampleSide = sampleSide;
            rows(rowIdx).requestedSamples = requestedCount;
            rows(rowIdx).actualSamples = actualCount;
            rows(rowIdx).NumCenters = iResolveModelHyper(cfg.models.VirtualScatter6D, scheme).NumCenters;
            rows(rowIdx).rmse_dB = M.rmse_dB;
            rows(rowIdx).mae_dB = M.mae_dB;
            rows(rowIdx).p90ae_dB = M.p90ae_dB;
            rows(rowIdx).bias_dB = M.bias_dB;
            rows(rowIdx).nmse = M.nmse;
            rows(rowIdx).nmae = M.nmae;
            rows(rowIdx).relRMSE = M.relRMSE;
            rows(rowIdx).rho_y_yhat = M.rho_y_yhat;
            rows(rowIdx).nValid = M.nValid;

            save(fullfile(metricDir, "metrics_" + string(runTag) + ".mat"), ...
                "P", "M", "B", "scheme", "sampleSide", "requestedCount", "actualCount", "seed");
        end
    end
end

if isempty(rows)
    warning("[ABLATION] No successful runs. Nothing to aggregate.");
    return;
end

rawTable = struct2table(rows);
rawTable = iEnsureMetricColumn(rawTable, metricName, metricDir, seed);
rawCsv = fullfile(originalDir, sprintf("sampling_ablation_raw_seed%d.csv", seed));
writetable(rawTable, rawCsv);

summaryTable = iAggregateMetrics(rawTable, metricName);
summaryCsv = fullfile(finalDir, sprintf("sampling_ablation_summary_seed%d.csv", seed));
writetable(summaryTable, summaryCsv);

iPlotSummary(summaryTable, metricName, fullfile(finalDir, sprintf("sampling_ablation_%s_seed%d", metricName, seed)), cfg.ablation);

fprintf("[ABLATION] Done. raw=%s, summary=%s\n", rawCsv, summaryCsv);

function data = iBuildOneDataSet(envObj, ds, dataDir)
[samplingMode, samplingArgs] = iParseSamplingSpec(ds);
dsPath = fullfile(dataDir, string(ds.name) + ".mat");
dataMode = lower(string(ds.dataMode));
if dataMode == "load" && ~isfile(dsPath)
    warning("[ABLATION] Dataset cache missing, generating once: %s", dsPath);
    dataMode = "save";
end
data = envObj.generateDataset(ds.Nt_side, ds.Nr_side, dataMode, "save", dsPath, ...
    "samplingMode", samplingMode, "samplingArgs", samplingArgs);
end

function pool = iBuildPool(envObj, scheme, maxSide, maxCount, poolPath, cfg, poolMode)
if nargin < 7 || strlength(string(poolMode)) == 0
    poolMode = lower(string(cfg.ablation.poolDataMode));
end
if poolMode == "load" && ~isfile(poolPath)
    warning("[ABLATION] Pool cache missing, generating once: %s", poolPath);
    poolMode = "save";
end

switch string(scheme.samplingMode)
    case "geom-geom"
        pool = iBuildGeomPool(envObj, scheme, maxSide, maxCount, poolPath, poolMode);
        return;

    case "list-rand"
        txCount = scheme.txCount;
        rxNum = ceil(maxCount / max(txCount, 1));
        txGridList = iRandomFreeGridList(cfg.grid, cfg.scenes.(char(string(cfg.ablation.scenePreset))), txCount);
        samplingArgs = {"txGridList", txGridList, "rxNum", rxNum};

    otherwise
        error("[ABLATION] Unsupported samplingMode=%s", string(scheme.samplingMode));
end

pool = envObj.generateDataset(scheme.Nt_side, scheme.Nr_side, poolMode, "save", poolPath, ...
    "samplingMode", string(scheme.samplingMode), "samplingArgs", samplingArgs);
end

function pool = iBuildGeomPool(envObj, scheme, maxSide, maxCount, poolPath, poolMode)
if poolMode == "load" && isfile(poolPath)
    pool = envObj.loadDataset(poolPath);
    return;
end
if poolMode == "load" && ~isfile(poolPath)
    warning("[ABLATION] Geom pool cache missing, generating once: %s", poolPath);
end

batchSide = min(maxSide, 7);
if isfield(scheme, "maxBinSide")
    batchSide = min(maxSide, scheme.maxBinSide);
end

pool = zeros(0, 3);
batchIdx = 0;
while size(pool, 1) < maxCount
    batchIdx = batchIdx + 1;
    batchData = iGenerateGeomBatch(envObj, scheme, batchSide, poolPath, batchIdx);
    pool = [pool; batchData]; %#ok<AGROW>
    [~, ia] = unique(pool(:,1:2), "rows", "stable");
    pool = pool(ia, :);
    fprintf("[ABLATION] geom pool batch=%d, unique samples=%d/%d\n", batchIdx, size(pool, 1), maxCount);
end

envObj.saveDataset(poolPath, pool);
end

function batchData = iGenerateGeomBatch(envObj, scheme, batchSide, poolPath, batchIdx)
lastErr = [];
radiusList = iResolveRadiusFallbacks(scheme);
for iRadius = 1:size(radiusList, 1)
    rMin = radiusList(iRadius, 1);
    rMax = radiusList(iRadius, 2);
    for side = batchSide:-1:3
        [poolFolder, poolBase, ~] = fileparts(poolPath);
        batchPath = fullfile(poolFolder, sprintf("%s_batch%02d_r%g_%g_side%d.mat", ...
            poolBase, batchIdx, rMin, rMax, side));
        samplingArgs = {"txNumPerSc", side, "rxNumPerSc", side, ...
            "radiationMin", rMin, "radiationMax", rMax};
        try
            batchData = envObj.generateDataset(scheme.Nt_side, scheme.Nr_side, "save", "save", batchPath, ...
                "samplingMode", "geom-geom", "samplingArgs", samplingArgs);
            fprintf("[ABLATION] geom batch accepted: radius=[%g,%g], side=%d\n", rMin, rMax, side);
            return;
        catch ME
            lastErr = ME;
            warning("[ABLATION] geom batch failed at radius=[%g,%g], side=%d: %s", ...
                rMin, rMax, side, ME.message);
        end
    end
end
rethrow(lastErr);
end

function radiusList = iResolveRadiusFallbacks(scheme)
if isfield(scheme, "radiusFallbacks")
    radiusList = scheme.radiusFallbacks;
else
    radiusList = [
        scheme.radiationMin, scheme.radiationMax
        max(0, scheme.radiationMin - 5), scheme.radiationMax + 5
        max(0, scheme.radiationMin - 5), scheme.radiationMax + 15
        max(0, scheme.radiationMin - 10), scheme.radiationMax + 25
    ];
end
end

function modelObj = iCreateModel(params, mCfg, scheme, raytracingResults)
h = iResolveModelHyper(mCfg, scheme);
modelObj = model.VirtualScatter6D(params, "VirtualScatter6D", raytracingResults, ...
    "NumCenters",  h.NumCenters, ...
    "PathLossExp", h.PathLossExp, ...
    "RefDistance", h.RefDistance, ...
    "EpsDist",     h.EpsDist, ...
    "Solver",      h.Solver);
end

function h = iResolveModelHyper(mCfg, scheme)
h = mCfg.hyper;
if isfield(scheme, "hyper")
    override = scheme.hyper;
    names = fieldnames(override);
    for i = 1:numel(names)
        h.(names{i}) = override.(names{i});
    end
end
end

function dataKey = iSchemeDataKey(scheme)
if isfield(scheme, "dataKey")
    dataKey = string(scheme.dataKey);
else
    dataKey = string(scheme.key);
end
end

function poolMode = iResolveSchemePoolMode(cfg, scheme, dataKey, cachePath)
poolMode = lower(string(cfg.ablation.poolDataMode));
if dataKey ~= string(scheme.key) && isfile(cachePath)
    poolMode = "load";
end
end

function data = iSubsampleRows(pool, requestedCount)
pool = pool(:,:);
n = min(requestedCount, size(pool, 1));
idx = randperm(size(pool, 1), n);
data = pool(idx, :);
[~, ia] = unique(data(:,1:2), "rows", "stable");
data = data(ia, :);
end

function txGridList = iRandomFreeGridList(gridCfg, sceneCfg, txCount)
gridSize = gridCfg.gridSize;
areaSize = gridCfg.areaSize;
scatterTable = sceneCfg.scatterTable;
Kx = floor(areaSize(1) / gridSize);
Ky = floor(areaSize(2) / gridSize);
[xg, yg] = meshgrid(((1:Kx) - (Kx + 1) / 2) * gridSize, ((1:Ky) - (Ky + 1) / 2) * gridSize);
gridPos = [xg(:), yg(:)];

xL = scatterTable(:,1) - gridSize/2;
yB = scatterTable(:,2) - gridSize/2;
xR = scatterTable(:,1) + scatterTable(:,4) + gridSize/2;
yT = scatterTable(:,2) + scatterTable(:,5) + gridSize/2;
inRect = (gridPos(:,1) >= xL.') & (gridPos(:,1) <= xR.') & ...
    (gridPos(:,2) >= yB.') & (gridPos(:,2) <= yT.');
freeIdx = find(~any(inRect, 2));

pick = freeIdx(randperm(numel(freeIdx), txCount));
[row, col] = ind2sub([Ky, Kx], pick);
txGridList = [col(:), row(:)];
end

function summaryTable = iAggregateMetrics(rawTable, metricName)
schemeList = unique(rawTable.scheme, "stable");
rows = struct([]);
idx = 0;
for i = 1:numel(schemeList)
    scheme = schemeList{i};
    maskScheme = strcmp(rawTable.scheme, scheme);
    counts = unique(rawTable.requestedSamples(maskScheme), "stable");
    label = rawTable.schemeLabel{find(maskScheme, 1, "first")};
    for j = 1:numel(counts)
        count = counts(j);
        mask = maskScheme & rawTable.requestedSamples == count;
        values = rawTable.(char(metricName))(mask);
        idx = idx + 1;
        rows(idx).scheme = scheme;
        rows(idx).schemeLabel = label;
        rows(idx).requestedSamples = count;
        rows(idx).meanMetric = mean(values, "omitnan");
        rows(idx).stdMetric = std(values, "omitnan");
        rows(idx).numRuns = sum(mask);
        rows(idx).semMetric = rows(idx).stdMetric / sqrt(max(rows(idx).numRuns, 1));
        rows(idx).ci95Metric = 1.96 * rows(idx).semMetric;
    end
end
summaryTable = struct2table(rows);
end

function rawTable = iEnsureMetricColumn(rawTable, metricName, metricDir, seed)
metricKey = char(string(metricName));
if ismember(metricKey, rawTable.Properties.VariableNames)
    return;
end

values = NaN(height(rawTable), 1);
for i = 1:height(rawTable)
    scheme = char(string(rawTable.scheme(i)));
    count = rawTable.requestedSamples(i);
    repeat = rawTable.repeat(i);
    metricsPath = fullfile(metricDir, sprintf("metrics_%s_n%d_rep%02d_seed%d.mat", ...
        scheme, round(count), round(repeat), seed));
    if ~isfile(metricsPath)
        continue;
    end
    S = load(metricsPath, "M");
    if isfield(S, "M") && isfield(S.M, metricKey)
        values(i) = S.M.(metricKey);
    end
end

if all(isnan(values))
    error("[ABLATION] Metric %s is not in raw CSV and could not be recovered from metric MAT files.", metricKey);
end
rawTable.(metricKey) = values;
fprintf("[ABLATION] Recovered metric column from MAT files: %s\n", metricKey);
end

function iPlotSummary(summaryTable, metricName, saveBase, ablationCfg)
plotCfg = iResolvePlotConfig(ablationCfg);
summaryTable = iApplyPlotEnvelopes(summaryTable, plotCfg);
summaryTable = iApplyPaperPlotOrder(summaryTable);
fig = figure("Color", "w", "Visible", "off");
set(fig, "DefaultTextInterpreter", "latex");
set(fig, "DefaultLegendInterpreter", "latex");
hold on; grid on; box on;
schemes = unique(string(summaryTable.scheme), "stable");
nSchemes = numel(schemes);
lineHandles = gobjects(numel(schemes), 1);
for i = 1:numel(schemes)
    scheme = schemes(i);
    mask = string(summaryTable.scheme) == scheme;
    T = sortrows(summaryTable(mask, :), "requestedSamples");
    x = T.requestedSamples;
    if plotCfg.xJitter && height(T) > 1
        dx = median(diff(sort(unique(T.requestedSamples))));
        if isfinite(dx) && dx > 0
            x = x + (i - (nSchemes + 1) / 2) * plotCfg.xJitterFrac * dx;
        end
    end
    yerr = iResolveErrorValues(T, plotCfg.errorBar);
    if plotCfg.style == "shaded"
        [color, marker] = iStyleForScheme(scheme, i);
        yLower = T.meanMetric - yerr;
        yUpper = T.meanMetric + yerr;
        fill([x; flipud(x)], [yLower; flipud(yUpper)], color, ...
            "FaceAlpha", plotCfg.bandAlpha, "EdgeColor", "none", "HandleVisibility", "off");
        lineHandles(i) = plot(x, T.meanMetric, "-" + marker, ...
            "Color", color, "LineWidth", plotCfg.lineWidth, "MarkerSize", plotCfg.markerSize, ...
            "MarkerFaceColor", "w", "MarkerEdgeColor", color, ...
            "DisplayName", T.schemeLabel{1});
    elseif plotCfg.style == "localband"
        [color, marker] = iStyleForScheme(scheme, i);
        iDrawLocalBands(x, T.meanMetric, yerr, color, plotCfg);
        lineHandles(i) = plot(x, T.meanMetric, "-" + marker, ...
            "Color", color, "LineWidth", plotCfg.lineWidth, "MarkerSize", plotCfg.markerSize, ...
            "MarkerFaceColor", "w", "MarkerEdgeColor", color, ...
            "DisplayName", T.schemeLabel{1});
    else
        [color, marker] = iStyleForScheme(scheme, i);
        e = errorbar(x, T.meanMetric, yerr, "-" + marker, ...
            "Color", color, "LineWidth", plotCfg.lineWidth, ...
            "MarkerSize", plotCfg.markerSize, "CapSize", 7, ...
            "DisplayName", T.schemeLabel{1});
        e.MarkerFaceColor = "w";
        e.MarkerEdgeColor = color;
        lineHandles(i) = e;
    end
end
xlabel("The number of training samples", "Interpreter", "latex");
yLabel = iMetricDisplayName(metricName);
if plotCfg.errorBar ~= "none"
    yLabel = sprintf("%s (mean $\\pm$ %s)", yLabel, char(plotCfg.errorBar));
end
ylabel(yLabel, "Interpreter", "latex");
iApplyYLim(plotCfg, metricName);
lg = legend(lineHandles(isgraphics(lineHandles)), "Location", "northeast", "Interpreter", "latex");
set(lg, "FontName", "Times New Roman", "FontSize", plotCfg.legendFontSize, "Box", "on", "LineWidth", 0.8);
ax = gca;
set(ax, "FontName", "Times New Roman", "FontSize", plotCfg.axisFontSize, ...
    "LineWidth", 0.9, "TickLabelInterpreter", "latex");
if ~isempty(plotCfg.xLim), xlim(plotCfg.xLim); end
if ~isempty(plotCfg.xTicks), xticks(plotCfg.xTicks); end
if ~isempty(plotCfg.yTicks), yticks(plotCfg.yTicks); end
exportgraphics(fig, string(saveBase) + ".png", "Resolution", 300);
savefig(fig, string(saveBase) + ".fig");
set(fig, "Visible", "on");
end

function plotCfg = iResolvePlotConfig(ablationCfg)
plotCfg = struct("style", "errorbar", "errorBar", "std", "xJitter", false, ...
    "xJitterFrac", 0.08, "bandAlpha", 0.12, "localBandHalfWidthFrac", 0.16, ...
    "localBandEdge", true, "localBandEdgeAlpha", 0.45, ...
    "lineWidth", 3.0, "markerSize", 8, "axisFontSize", 18, ...
    "legendFontSize", 18, "xLim", [0, 3600], "xTicks", 0:600:3600, ...
    "yLim", [4.55, 5.2], "yTicks", 4.6:0.1:5.2);
if isfield(ablationCfg, "plot")
    raw = ablationCfg.plot;
    if isfield(raw, "style"), plotCfg.style = lower(string(raw.style)); end
    if isfield(raw, "errorBar"), plotCfg.errorBar = lower(string(raw.errorBar)); end
    if isfield(raw, "xJitter"), plotCfg.xJitter = logical(raw.xJitter); end
    if isfield(raw, "xJitterFrac"), plotCfg.xJitterFrac = raw.xJitterFrac; end
    if isfield(raw, "bandAlpha"), plotCfg.bandAlpha = raw.bandAlpha; end
    if isfield(raw, "localBandHalfWidthFrac"), plotCfg.localBandHalfWidthFrac = raw.localBandHalfWidthFrac; end
    if isfield(raw, "localBandEdge"), plotCfg.localBandEdge = logical(raw.localBandEdge); end
    if isfield(raw, "localBandEdgeAlpha"), plotCfg.localBandEdgeAlpha = raw.localBandEdgeAlpha; end
    if isfield(raw, "envelopes"), plotCfg.envelopes = raw.envelopes; else, plotCfg.envelopes = []; end
    if isfield(raw, "yLim"), plotCfg.yLim = raw.yLim; end
    if isfield(raw, "metricYLim"), plotCfg.metricYLim = raw.metricYLim; else, plotCfg.metricYLim = struct(); end
else
    plotCfg.envelopes = [];
    plotCfg.metricYLim = struct();
end
allowed = ["std", "sem", "ci95", "none"];
if ~any(plotCfg.errorBar == allowed)
    error("[ABLATION] Unsupported plot.errorBar=%s. Use one of: %s", ...
        plotCfg.errorBar, strjoin(allowed, ", "));
end
allowedStyles = ["errorbar", "shaded", "localband"];
if ~any(plotCfg.style == allowedStyles)
    error("[ABLATION] Unsupported plot.style=%s. Use one of: %s", ...
        plotCfg.style, strjoin(allowedStyles, ", "));
end
end

function outTable = iApplyPaperPlotOrder(summaryTable)
preferred = ["envelope_1", "rand_4tx", "rand_2tx", "rand_1tx"];
schemeList = unique(string(summaryTable.scheme), "stable");
ordered = preferred(ismember(preferred, schemeList));
ordered = [ordered, schemeList(~ismember(schemeList, ordered))]; %#ok<AGROW>
outTable = summaryTable([], :);
for i = 1:numel(ordered)
    outTable = [outTable; summaryTable(string(summaryTable.scheme) == ordered(i), :)]; %#ok<AGROW>
end
end

function [color, marker] = iStyleForScheme(scheme, idx)
switch string(scheme)
    case "envelope_1"
        color = [0.00, 0.45, 0.70];
        marker = "o";
    case "rand_4tx"
        color = [0.84, 0.37, 0.00];
        marker = "s";
    case "rand_2tx"
        color = [0.00, 0.62, 0.45];
        marker = "^";
    case "rand_1tx"
        color = [0.55, 0.55, 0.55];
        marker = "d";
    otherwise
        color = iColorForIndex(idx);
        marker = "o";
end
end

function iApplyYLim(plotCfg, metricName)
if isfield(plotCfg, "metricYLim") && isfield(plotCfg.metricYLim, char(string(metricName)))
    plotCfg.yLim = plotCfg.metricYLim.(char(string(metricName)));
end
if ~isfield(plotCfg, "yLim") || isempty(plotCfg.yLim)
    return;
end
yl = ylim;
raw = plotCfg.yLim;
if iscell(raw), raw = cell2mat(raw); end
if numel(raw) ~= 2
    error("[ABLATION] plot.yLim must be [ymin, ymax].");
end
if isnumeric(raw)
    if isfinite(raw(1)), yl(1) = raw(1); end
    if isfinite(raw(2)), yl(2) = raw(2); end
else
    vals = string(raw);
    for i = 1:2
        if strlength(vals(i)) > 0 && vals(i) ~= "null"
            yl(i) = str2double(vals(i));
        end
    end
end
if yl(1) >= yl(2)
    warning("[ABLATION] Skip plot.yLim because requested limits are invalid for current data: [%.3g, %.3g].", yl(1), yl(2));
    return;
end
ylim(yl);
end

function outTable = iApplyPlotEnvelopes(summaryTable, plotCfg)
outTable = summaryTable;
if ~isfield(plotCfg, "envelopes") || isempty(plotCfg.envelopes)
    return;
end

envelopes = plotCfg.envelopes;
if ~iscell(envelopes), envelopes = num2cell(envelopes); end

for iEnv = 1:numel(envelopes)
    envCfg = envelopes{iEnv};
    memberSchemes = string(envCfg.schemes);
    if isempty(memberSchemes)
        continue;
    end

    memberMask = ismember(string(outTable.scheme), memberSchemes);
    if ~any(memberMask)
        continue;
    end

    memberTable = outTable(memberMask, :);
    counts = unique(memberTable.requestedSamples, "stable");
    envRows = memberTable([], :);

    for iCount = 1:numel(counts)
        count = counts(iCount);
        candidates = memberTable(memberTable.requestedSamples == count, :);
        if isempty(candidates)
            continue;
        end
        [~, bestIdx] = min(candidates.meanMetric);
        bestRow = candidates(bestIdx, :);
        bestRow.scheme = {sprintf("envelope_%d", iEnv)};
        if isfield(envCfg, "displayLabel")
            bestRow.schemeLabel = {char(string(envCfg.displayLabel))};
        elseif isfield(envCfg, "label")
            bestRow.schemeLabel = {char(string(envCfg.label))};
        else
            bestRow.schemeLabel = {"envelope"};
        end
        envRows = [envRows; bestRow]; %#ok<AGROW>
    end

    schemeOrder = string(outTable.scheme);
    firstMemberIdx = find(ismember(schemeOrder, memberSchemes), 1, "first");
    keepMask = ~ismember(schemeOrder, memberSchemes);
    beforeMask = false(height(outTable), 1);
    afterMask = false(height(outTable), 1);
    beforeMask(1:firstMemberIdx-1) = keepMask(1:firstMemberIdx-1);
    afterMask(firstMemberIdx:end) = keepMask(firstMemberIdx:end);
    outTable = [outTable(beforeMask, :); envRows; outTable(afterMask, :)];
end
end

function yerr = iResolveErrorValues(T, errorBarMode)
switch errorBarMode
    case "std"
        yerr = T.stdMetric;
    case "sem"
        yerr = T.semMetric;
    case "ci95"
        yerr = T.ci95Metric;
    case "none"
        yerr = zeros(height(T), 1);
    otherwise
        error("[ABLATION] Unsupported error bar mode: %s", errorBarMode);
end
end

function label = iMetricDisplayName(metricName)
switch string(metricName)
    case "rmse_dB"
        label = "RMSE (dB)";
    case "mae_dB"
        label = "MAE (dB)";
    case "p90ae_dB"
        label = "P90 AE (dB)";
    case "bias_dB"
        label = "Bias (dB)";
    case "relRMSE"
        label = "Relative RMSE";
    case "nmse"
        label = "NMSE";
    case "nmae"
        label = "NMAE";
    case "rho_y_yhat"
        label = "Correlation";
    otherwise
        label = strrep(char(metricName), "_", " ");
end
end

function color = iColorForIndex(idx)
palette = [
    0.00, 0.45, 0.70
    0.84, 0.37, 0.00
    0.00, 0.62, 0.45
    0.80, 0.47, 0.65
    0.90, 0.62, 0.00
    0.35, 0.70, 0.90
    0.80, 0.22, 0.17
];
color = palette(mod(idx - 1, size(palette, 1)) + 1, :);
end

function iDrawLocalBands(x, y, yerr, color, plotCfg)
x = x(:);
y = y(:);
yerr = yerr(:);
uniqueX = sort(unique(x));
if numel(uniqueX) > 1
    dx = median(diff(uniqueX));
else
    dx = max(abs(x(1)) * 0.05, 1);
end
halfWidth = max(dx * plotCfg.localBandHalfWidthFrac, eps);
for k = 1:numel(x)
    if ~isfinite(yerr(k)) || yerr(k) <= 0
        continue;
    end
    xPatch = [x(k)-halfWidth; x(k)+halfWidth; x(k)+halfWidth; x(k)-halfWidth];
    yPatch = [y(k)-yerr(k); y(k)-yerr(k); y(k)+yerr(k); y(k)+yerr(k)];
    fill(xPatch, yPatch, color, ...
        "FaceAlpha", plotCfg.bandAlpha, "EdgeColor", "none", "HandleVisibility", "off");
    if plotCfg.localBandEdge
        edgeColor = color .* plotCfg.localBandEdgeAlpha + [1, 1, 1] .* (1 - plotCfg.localBandEdgeAlpha);
        plot([x(k)-halfWidth, x(k)+halfWidth], [y(k)-yerr(k), y(k)-yerr(k)], ...
            "-", "Color", edgeColor, "LineWidth", 0.8, "HandleVisibility", "off");
        plot([x(k)-halfWidth, x(k)+halfWidth], [y(k)+yerr(k), y(k)+yerr(k)], ...
            "-", "Color", edgeColor, "LineWidth", 0.8, "HandleVisibility", "off");
    end
end
end

function spec = iFindDataSetSpec(dataSetList, key)
for i = 1:numel(dataSetList)
    if string(dataSetList(i).name) == string(key)
        spec = dataSetList(i);
        return;
    end
end
error("[ABLATION] Dataset spec %s not found.", key);
end

function [mode, args] = iParseSamplingSpec(spec)
mode = string(spec.samplingMode);
rawArgs = spec.samplingArgs;
orderedKeys = {'txGridList', 'rxNum', 'txNumPerSc', 'rxNumPerSc', 'radiationMin', 'radiationMax'};
args = {};
for i = 1:numel(orderedKeys)
    key = orderedKeys{i};
    if isfield(rawArgs, key)
        val = rawArgs.(key);
        if iscell(val), val = cell2mat(val); end
        if strcmp(key, "rxNum") && isnumeric(val) && isscalar(val) && val < 0
            val = inf;
        end
        args(end+1:end+2) = {key, val};
    end
end
end
