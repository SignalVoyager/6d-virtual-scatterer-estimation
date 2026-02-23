% run_experiment.m (COMPARISON)
% Inputs injected: expRoot, seed

dataDir = fullfile(expRoot, "data");
outDir  = fullfile(expRoot, "outputs");
if ~isfolder(dataDir), mkdir(dataDir); end
if ~isfolder(outDir),  mkdir(outDir);  end

cfg = jsondecode(fileread(fullfile(expRoot, "config.json")));

% ---------- params ----------
params = struct();

params.condaEnv = string(cfg.backend.condaEnv);
params.sionnaModule = fullfile(expRoot, string(cfg.backend.sionnaModule));

params.fc     = cfg.radio.fc;
params.Pt_dBm = cfg.radio.Pt_dBm;

params.areaSize = cfg.grid.areaSize;
params.gridSize = cfg.grid.gridSize;
params.tx_pos_z = cfg.grid.tx_pos_z;
params.rx_pos_z = cfg.grid.rx_pos_z;

modelList = string(cfg.models.modelList);
scenePresets = strings(size(modelList));
for iModel = 1:numel(modelList)
    mk = modelList(iModel);
    scenePresets(iModel) = string(cfg.models.(mk).activeScenePreset);
end
if numel(unique(scenePresets)) ~= 1
    error("All models must share the same activeScenePreset in this experiment.");
end
preset = scenePresets(1);
scene  = cfg.scenes.(preset);
sceneBaseName = "scene_" + preset;
params.stlFile = fullfile(dataDir, sceneBaseName + ".stl");
params.plyFile = fullfile(dataDir, sceneBaseName + ".ply");
params.xmlFile = fullfile(dataDir, sceneBaseName + ".xml");
params.scatterTable = scene.scatterTable;

% ---------- dataset build + selection ----------
envObj = env.WirelessEnvironment(params);

% Build all datasets from config.dataSetList
dataSetList = cfg.dataSetList;
dataSetCache = struct();
for i = 1:numel(dataSetList)
    ds = dataSetList(i);
    dsName = char(string(ds.name));

    [samplingMode, samplingArgs] = utils.parseSamplingSpec(ds);
    dsPath = fullfile(expRoot, string(ds.path));

    dataSetCache.(dsName) = envObj.generateDataset( ...
        ds.Nt_side, ds.Nr_side, ...
        ds.dataMode, "save", dsPath, ...
        "samplingMode", samplingMode, ...
        "samplingArgs", samplingArgs);
end

% ---------- Step 2) Environment plots ----------
try
    EP = cfg.envEvaluation;
    orders = EP.txHeatmapOrders;
    for kk = 1:numel(orders)
        savePath = fullfile(outDir, sprintf("env_test_txHeatmap_order%d_seed%d", orders(kk), seed));
        envObj.evaluate("test", "txHeatmap", savePath, orders(kk));
    end

    if EP.enableRxCount
        savePath = fullfile(outDir, sprintf("env_train_rxCount_seed%d", seed));
        envObj.evaluate("train", "rxCount", savePath);
    end

    if EP.enableTxCount
        savePath = fullfile(outDir, sprintf("env_train_txCount_seed%d", seed));
        envObj.evaluate("train", "txCount", savePath);
    end
catch ME
    warning(ME.identifier, '[COMPARISON] env plots failed: %s', ME.message);
end

% Per-model dataset selection only.
% Each model entry must define:
%   cfg.models.<modelKey>.datasetSelection.trainSet
%   cfg.models.<modelKey>.datasetSelection.testSet

% ---------- evaluation opt ----------
E = cfg.modelEvaluation;
eopt = struct();
eopt.whichSet = string(E.whichSet);
eopt.cgmSliceMode = string(E.cgmSliceMode);
eopt.cgmGridList = E.cgmGridList;
eopt.doPdf = E.enablePdf;
eopt.doCgm = E.enableCgm;
eopt.doResidual = E.enableResidual;

% ---------- loop models ----------
resultsSummary = struct();
resultsSummary.meta = cfg.meta;
resultsSummary.activeScenePreset = preset;
resultsSummary.seed = seed;
resultsSummary.models = struct();

for k = 1:numel(modelList)
    modelKey = modelList(k);
    mCfg = cfg.models.(modelKey);

    sel = mCfg.datasetSelection;

    trainKey = char(string(sel.trainSet));
    testKey  = char(string(sel.testSet));

    modelRaytracingResults = struct( ...
        "trainSet", dataSetCache.(trainKey), ...
        "testSet",  dataSetCache.(testKey));
    envObj.raytracingResults = modelRaytracingResults;

    % response file per model
    params.responseFile = fullfile(expRoot, mCfg.responseFile);

    fprintf("\n[COMPARISON] Running model: %s (train=%s, test=%s)\n", ...
        modelKey, trainKey, testKey);

    % ---- instantiate model ----
    switch modelKey
        case "VirtualScatter6D"
            h = mCfg.hyper;
            modelObj = model.VirtualScatter6D(params, "VirtualScatter6D", modelRaytracingResults, ...
                "NumCenters",  h.NumCenters, ...
                "PathLossExp", h.PathLossExp, ...
                "RefDistance", h.RefDistance, ...
                "EpsDist",     h.EpsDist, ...
                "Solver",      h.Solver);
        
        case "VirtualScatter3D"
            h = mCfg.hyper;
            modelObj = model.VirtualScatter3D(params, "VirtualScatter3D", modelRaytracingResults, ...
                "NumCenters",  h.NumCenters, ...
                "PathLossExp", h.PathLossExp, ...
                "RefDistance", h.RefDistance, ...
                "EpsDist",     h.EpsDist, ...
                "Solver",      h.Solver);

        otherwise
            warning("[COMPARISON] Unknown modelKey=%s. Skip.", modelKey);
            continue;
    end

    % ---- train & evaluate ----
    modelObj.train("mode","save");
    evalSavePath = fullfile(outDir, sprintf("%s_seed%d", char(modelKey), seed));
    modelObj.evaluate(eopt, evalSavePath);
    close all;
end
fprintf("[COMPARISON] Done. preset=%s, outputs=%s\n", preset, outDir);
