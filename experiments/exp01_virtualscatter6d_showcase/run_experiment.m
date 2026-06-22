% run_experiment.m (SHOWCASE)
% Inputs injected by main_all_experiments.m:

dataDir = fullfile(expRoot, "data");
outDir  = fullfile(expRoot, "outputs");
logDir = fullfile(outDir, "logs");
originalDir = fullfile(outDir, "original");
finalDir = fullfile(outDir, "final");
envOriginalDir = fullfile(originalDir, "env");
modelOriginalDir = fullfile(originalDir, "model");
if ~isfolder(dataDir), mkdir(dataDir); end
if ~isfolder(outDir),  mkdir(outDir);  end
if ~isfolder(logDir), mkdir(logDir); end
if ~isfolder(originalDir), mkdir(originalDir); end
if ~isfolder(finalDir), mkdir(finalDir); end
if ~isfolder(envOriginalDir), mkdir(envOriginalDir); end
if ~isfolder(modelOriginalDir), mkdir(modelOriginalDir); end

cfg = jsondecode(fileread(fullfile(expRoot, "config.json")));
if isstruct(cfg.dataSetList), cfg.dataSetList = num2cell(cfg.dataSetList); end
showFigures = logical(cfg.runtime.showFigures);

if isfield(cfg.runtime, "refreshFinalOnly") && logical(cfg.runtime.refreshFinalOnly)
    E = cfg.modelEvaluation;
    modelKey = string(cfg.models.activeModel);
    params = struct();
    params.areaSize = cfg.grid.areaSize;
    params.gridSize = cfg.grid.gridSize;
    params.tx_pos_z = cfg.grid.tx_pos_z;
    composeIntuitivePanel(originalDir, finalDir, modelKey, seed, E.cgmSliceMode, ...
        E.cgmGridList, params);
    fprintf("[SHOWCASE] Refreshed final panel only: %s\n", finalDir);
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

% ---------- active model + scene ----------
modelKey = string(cfg.models.activeModel);
mCfg = cfg.models.(modelKey);
sel = mCfg.datasetSelection;
trainKeys = iStringList(sel.trainSet);
testKey  = char(iStringList(sel.testSet));

dataSetListCell = cfg.dataSetList;
dataSetList = [dataSetListCell{:}];
dsPresetMap = struct();
for i = 1:numel(dataSetList)
    dsPresetMap.(char(string(dataSetList(i).name))) = string(dataSetList(i).activeScenePreset);
end
trainPresets = strings(size(trainKeys));
for i = 1:numel(trainKeys)
    trainPresets(i) = dsPresetMap.(char(trainKeys(i)));
end
presetList = [trainPresets, dsPresetMap.(testKey)];
if numel(unique(presetList)) ~= 1
    error("[SHOWCASE] train/test datasets must share one activeScenePreset.");
end
preset = presetList(1);
scene = cfg.scenes.(preset);
sceneBaseName = "scene_" + preset;
params.stlFile = fullfile(dataDir, sceneBaseName + ".stl");
params.plyFile = fullfile(dataDir, sceneBaseName + ".ply");
params.xmlFile = fullfile(dataDir, sceneBaseName + ".xml");
params.scatterTable = scene.scatterTable;
params.responseFile = fullfile(expRoot, mCfg.responseFile);

% ---------- Step 1) Environment + datasets ----------
envObj = env.WirelessEnvironment(params);
dataSetCache = utils.buildDataSetCache(envObj, dataSetListCell, dataDir);

raytracingResults = struct( ...
    "trainSet", iConcatDataSets(dataSetCache, trainKeys), ...
    "testSet",  dataSetCache.(testKey));
envObj.raytracingResults = raytracingResults;

% ---------- Step 2) Environment plots ----------
if showFigures
    try
        EP = cfg.envEvaluation;
        orders = EP.txHeatmapOrders;
        heatmapDir = fullfile(envOriginalDir, "test_heatmaps");
        if ~isfolder(heatmapDir), mkdir(heatmapDir); end
        for k = 1:numel(orders)
            savePath = fullfile(heatmapDir, sprintf("env_test_txHeatmap_order%d_seed%d", orders(k), seed));
            envObj.evaluate("test", "txHeatmap", savePath, orders(k));
        end

        if EP.enableRxCount
            countDir = fullfile(envOriginalDir, "sampling_counts");
            if ~isfolder(countDir), mkdir(countDir); end
            savePath = fullfile(countDir, sprintf("env_train_rxCount_seed%d", seed));
            envObj.evaluate("train", "rxCount", savePath);
        end

        if EP.enableTxCount
            countDir = fullfile(envOriginalDir, "sampling_counts");
            if ~isfolder(countDir), mkdir(countDir); end
            savePath = fullfile(countDir, sprintf("env_train_txCount_seed%d", seed));
            envObj.evaluate("train", "txCount", savePath);
        end

        if isfield(EP, "enableCgmRaytrace") && logical(EP.enableCgmRaytrace)
            E = cfg.modelEvaluation;
            rtDataMode = "save";
            if isfield(EP, "cgmRaytraceDataMode")
                rtDataMode = string(EP.cgmRaytraceDataMode);
            end

            cgmRtName = sprintf("cgm_raytrace_%s_%s", char(E.cgmSliceMode), char(preset));
            cgmRtPath = fullfile(dataDir, string(cgmRtName) + ".mat");
            if rtDataMode == "load" && ~isfile(cgmRtPath)
                warning("[SHOWCASE] CGM raytrace cache missing, generating once: %s", cgmRtPath);
                rtDataMode = "save";
            end
            testSpec = iFindDataSetSpec(dataSetList, testKey);
            cgmRtData = envObj.generateDataset( ...
                testSpec.Nt_side, testSpec.Nr_side, ...
                rtDataMode, "save", cgmRtPath, ...
                "samplingMode", "list-rand", ...
                "samplingArgs", {"txGridList", E.cgmGridList, "rxNum", inf});

            oldRaytracingResults = envObj.raytracingResults;
            envObj.raytracingResults = struct("trainSet", oldRaytracingResults.trainSet, "testSet", cgmRtData);
            cgmTruthDir = fullfile(envOriginalDir, "cgm_raytrace");
            if ~isfolder(cgmTruthDir), mkdir(cgmTruthDir); end
            for k = 1:size(E.cgmGridList, 1)
                savePath = fullfile(cgmTruthDir, sprintf("env_cgmRaytrace_%s_grid%d_seed%d", char(E.cgmSliceMode), k, seed));
                envObj.evaluate("test", "txHeatmap", savePath, k);
            end
            envObj.raytracingResults = oldRaytracingResults;
        end
    catch ME
        warning(ME.identifier, "[SHOWCASE] env plots failed: %s", ME.message);
    end
end

% ---------- Step 3) Instantiate + train model ----------
switch modelKey
    case "VirtualScatter6D"
        h = mCfg.hyper;
        modelObj = model.VirtualScatter6D(params, "VirtualScatter6D", raytracingResults, ...
            "NumCenters",  h.NumCenters, ...
            "PathLossExp", h.PathLossExp, ...
            "RefDistance", h.RefDistance, ...
            "EpsDist",     h.EpsDist, ...
            "Solver",      h.Solver);
    otherwise
        error("Unknown modelKey: %s", modelKey);
end

modelObj.train("mode", "save");

% ---------- Step 4) Evaluate ----------
E = cfg.modelEvaluation;
eopt = struct();
eopt.whichSet = string(E.whichSet);
eopt.cgmGridList = E.cgmGridList;
eopt.doPdf = showFigures && E.enablePdf;
eopt.doCgm = showFigures && E.enableCgm;
eopt.doResidual = showFigures && E.enableResidual;

% Evaluate for fixTx
evalSavePath = fullfile(modelOriginalDir, sprintf("%s_%s_seed%d", char(modelKey), char(E.cgmSliceMode), seed));
modelObj.evaluate(eopt, evalSavePath);
deleteFlatModelFigureCopies(evalSavePath);

if isfield(cfg.runtime, "composeIntuitivePanel") && logical(cfg.runtime.composeIntuitivePanel)
    if isfolder(originalDir) && isfolder(finalDir)
        composeIntuitivePanel(originalDir, finalDir, modelKey, seed, E.cgmSliceMode, ...
            E.cgmGridList, params);
    else
        warning("[SHOWCASE] output directories missing: original=%s, final=%s", originalDir, finalDir);
    end
end

fprintf("[SHOWCASE] Done. preset=%s, outputs=%s\n", preset, outDir);

function keys = iStringList(raw)
keys = string(raw);
keys = keys(:).';
if isempty(keys) || any(strlength(keys) == 0)
    error("[SHOWCASE] Dataset selection must be a non-empty string or string list.");
end
end

function data = iConcatDataSets(dataSetCache, keys)
data = zeros(0,3);
for i = 1:numel(keys)
    key = char(keys(i));
    if ~isfield(dataSetCache, key)
        error("[SHOWCASE] Dataset %s not found in dataSetCache.", key);
    end
    data = [data; dataSetCache.(key)]; %#ok<AGROW>
end
[~, ia] = unique(data(:,1:2), 'rows', 'stable');
data = data(ia,:);
end

function spec = iFindDataSetSpec(dataSetList, key)
for i = 1:numel(dataSetList)
    if string(dataSetList(i).name) == string(key)
        spec = dataSetList(i);
        return;
    end
end
error("[SHOWCASE] Dataset spec %s not found.", string(key));
end

function composeIntuitivePanel(originalDir, finalDir, modelKey, seed, cgmSliceMode, cgmGridList, params)
[figFiles, panelTitles] = collectIntuitiveSourceFigures( ...
    originalDir, modelKey, seed, cgmSliceMode, cgmGridList, params);
if numel(figFiles) ~= 8
    error("[SHOWCASE] Expected 8 intuitive panel source figures, got %d.", numel(figFiles));
end
if ~isfolder(finalDir)
    mkdir(finalDir);
end
delete(fullfile(finalDir, "panel_composed_2x4.*"));
delete(fullfile(finalDir, "*.fig"));
delete(fullfile(finalDir, "*.png"));
globalClim = [-125, -35];

panelFig = figure("Color", "w", "Units", "pixels", ...
    "Position", [100, 100, 2800, 1380], "Visible", "off");
set(panelFig, "DefaultTextInterpreter", "latex");
set(panelFig, "DefaultLegendInterpreter", "latex");
tileAxes = gobjects(numel(figFiles), 1);
left = 0.070;
gapX = 0.022;
axW = 0.185;
axH = 0.330;
topY = 0.555;
botY = 0.150;

for i = 1:numel(figFiles)
    srcPath = figFiles(i);
    if ~isfile(srcPath)
        error("[SHOWCASE] Missing figure: %s", srcPath);
    end

    srcFig = openfig(srcPath, "invisible");
    srcAx = findDataAxis(srcFig);
    if isempty(srcAx)
        close(srcFig);
        error("[SHOWCASE] No axes found in %s", srcPath);
    end

    col = mod(i - 1, 4);
    rowY = topY;
    if i > 4, rowY = botY; end
    dstAx = axes("Parent", panelFig, "Units", "normalized", ...
        "Position", [left + col * (axW + gapX), rowY, axW, axH]);
    tileAxes(i) = dstAx;
    copyobj(allchild(srcAx), dstAx);
    copyAxisProperties(srcAx, dstAx);
    dstAx.CLim = globalClim;
    styleCopiedAnnotations(dstAx);

    title(dstAx, panelTitles(i), "Interpreter", "latex", ...
        "FontWeight", "normal", "FontSize", 28);
    if i <= 4
        xlabel(dstAx, "");
        dstAx.XTickLabel = [];
    else
        xlabel(dstAx, "$x$ (m)", "Interpreter", "latex", "FontSize", 28);
    end
    if mod(i - 1, 4) == 0
        ylabel(dstAx, "$y$ (m)", "Interpreter", "latex", "FontSize", 28);
    else
        ylabel(dstAx, "");
        dstAx.YTickLabel = [];
    end
    set(dstAx, "FontName", "Times New Roman", "FontSize", 24);
    dstAx.TickLabelInterpreter = "latex";
    dstAx.XTickLabelRotation = 0;
    dstAx.YTickLabelRotation = 0;
    colorbar(dstAx, "off");

    close(srcFig);
end

cbAx = axes("Parent", panelFig, "Units", "normalized", ...
    "Position", [0.896, 0.150, 0.010, 0.735], "Visible", "off");
colormap(cbAx, colormap(tileAxes(end)));
clim(cbAx, globalClim);
cb = colorbar(cbAx, "eastoutside");
cb.Units = "normalized";
cb.Position = [0.901, 0.150, 0.012, 0.735];
cb.FontSize = 24;
cb.FontName = "Times New Roman";
cb.TickLabelInterpreter = "latex";
cb.Label.String = "Received power (dBm)";
cb.Label.Interpreter = "latex";
cb.Label.FontSize = 28;
cb.Label.FontName = "Times New Roman";

outBase = fullfile(finalDir, "panel_composed_2x4");
exportgraphics(panelFig, outBase + ".png", "Resolution", 300);
savefig(panelFig, outBase + ".fig");
set(panelFig, "Visible", "on");

fprintf("[SHOWCASE] saved intuitive panel: %s.[png|fig]\n", outBase);
end

function styleCopiedAnnotations(ax)
annotationColor = [0.80, 0.22, 0.17];
txt = findobj(ax, "Type", "text");
if ~isempty(txt)
    set(txt, "FontSize", 14, "Color", annotationColor, "FontWeight", "bold");
end
end

function clim = resolveGlobalClim(figFiles)
clim = [inf, -inf];
for i = 1:numel(figFiles)
    srcFig = openfig(figFiles(i), "invisible");
    srcAx = findDataAxis(srcFig);
    if isempty(srcAx)
        close(srcFig);
        continue;
    end
    srcClim = srcAx.CLim;
    if any(~isfinite(srcClim)) || srcClim(1) >= srcClim(2)
        srcClim = finiteImageClim(srcAx);
    end
    clim(1) = min(clim(1), srcClim(1));
    clim(2) = max(clim(2), srcClim(2));
    close(srcFig);
end
if any(~isfinite(clim)) || clim(1) >= clim(2)
    error("[SHOWCASE] Cannot resolve a valid global color range.");
end
fprintf("[SHOWCASE] intuitive panel color range = [%.3f, %.3f] dBm\n", clim(1), clim(2));
end

function dataClim = finiteImageClim(ax)
imgs = findobj(ax, "Type", "image");
vals = [];
for i = 1:numel(imgs)
    c = imgs(i).CData;
    vals = [vals; c(isfinite(c))]; %#ok<AGROW>
end
if isempty(vals)
    error("[SHOWCASE] Cannot resolve finite image color range.");
end
dataClim = [min(vals), max(vals)];
if dataClim(1) >= dataClim(2)
    dataClim = dataClim + [-0.5, 0.5];
end
end

function ax = findDataAxis(figHandle)
axesList = findobj(figHandle, "Type", "axes");
ax = gobjects(0);
bestArea = -inf;
for k = 1:numel(axesList)
    hasImage = ~isempty(findobj(axesList(k), "Type", "image"));
    hasSurface = ~isempty(findobj(axesList(k), "Type", "surface"));
    if hasImage || hasSurface
        pos = axesList(k).Position;
        area = pos(3) * pos(4);
        if area > bestArea
            bestArea = area;
            ax = axesList(k);
        end
    end
end
if ~isempty(axesList)
    ax = axesList(end);
end
end

function [figFiles, titles] = collectIntuitiveSourceFigures( ...
    originalDir, modelKey, seed, cgmSliceMode, cgmGridList, params)
numPanels = 4;
figFiles = strings(numPanels * 2, 1);
titles = strings(numPanels * 2, 1);
modelDir = fullfile(originalDir, "model", sprintf("%s_%s_seed%d", char(modelKey), char(cgmSliceMode), seed));
truthDir = fullfile(originalDir, "env", "cgm_raytrace");

for k = 1:numPanels
    proposedPath = fullfile(modelDir, sprintf("cgm_%s_grid%d.fig", char(cgmSliceMode), k));
    truthPath = fullfile(truthDir, sprintf("env_cgmRaytrace_%s_grid%d_seed%d.fig", ...
        char(cgmSliceMode), k, seed));

    if ~isfile(proposedPath)
        error("[SHOWCASE] Missing proposed source figure: %s", proposedPath);
    end
    if ~isfile(truthPath)
        error("[SHOWCASE] Missing ground-truth source figure: %s", truthPath);
    end

    txTitle = formatTxTitle(cgmGridList(k, :), params);
    figFiles(k) = proposedPath;
    titles(k) = sprintf("(%s) Proposed X2X CGM\n%s", alphabeticalLabel(k), txTitle);
    figFiles(k + numPanels) = truthPath;
    titles(k + numPanels) = sprintf("(%s) Ground truth\n%s", alphabeticalLabel(k + numPanels), txTitle);
end
end

function label = alphabeticalLabel(idx)
letters = 'abcdefghijklmnopqrstuvwxyz';
label = letters(idx);
end

function txTitle = formatTxTitle(gridCR, params)
areaSize = params.areaSize;
gridSize = params.gridSize;
Kx = floor(areaSize(1) / gridSize);
Ky = floor(areaSize(2) / gridSize);
x = ((gridCR(1) - (Kx + 1) / 2) * gridSize);
y = ((gridCR(2) - (Ky + 1) / 2) * gridSize);
z = params.tx_pos_z;
txTitle = sprintf("TX (%.1f, %.1f, %.1f) m", x, y, z);
end

function copyAxisProperties(srcAx, dstAx)
dstAx.XLim = srcAx.XLim;
dstAx.YLim = srcAx.YLim;
dstAx.CLim = srcAx.CLim;
dstAx.YDir = srcAx.YDir;
dstAx.Box = srcAx.Box;
dstAx.Layer = srcAx.Layer;
dstAx.XTick = srcAx.XTick;
dstAx.YTick = srcAx.YTick;

colormap(dstAx, iSoftRygbColormap(256));
axis(dstAx, "equal");
axis(dstAx, "tight");
end

function cmap = iSoftRygbColormap(n)
anchors = [
    0.30, 0.55, 0.78
    0.42, 0.72, 0.72
    0.70, 0.84, 0.60
    0.96, 0.88, 0.58
    0.93, 0.66, 0.42
    0.77, 0.33, 0.30
];
x = linspace(0, 1, size(anchors, 1));
xi = linspace(0, 1, n);
cmap = interp1(x, anchors, xi, "linear");
cmap = 0.88 * cmap + 0.12;
cmap = min(max(cmap, 0), 1);
end

function deleteFlatModelFigureCopies(evalSavePath)
evalSavePath = char(string(evalSavePath));
[parentDir, baseName, ~] = fileparts(evalSavePath);
flatFiles = [dir(fullfile(parentDir, sprintf("%s_*.fig", baseName))); ...
    dir(fullfile(parentDir, sprintf("%s_*.png", baseName)))];
for i = 1:numel(flatFiles)
    src = fullfile(flatFiles(i).folder, flatFiles(i).name);
    delete(src);
end
end
