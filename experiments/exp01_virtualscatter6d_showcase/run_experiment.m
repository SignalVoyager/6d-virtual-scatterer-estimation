% run_experiment.m (SHOWCASE)
% Inputs injected by main_all_experiments.m:
%   expRoot, seed

dataDir = fullfile(expRoot, "data");
outDir  = fullfile(expRoot, "outputs");
if ~isfolder(dataDir), mkdir(dataDir); end
if ~isfolder(outDir),  mkdir(outDir);  end

cfg = jsondecode(fileread(fullfile(expRoot, "config.json")));

% ---------- build params (strictly inside this experiment) ----------
params = struct();

params.condaEnv = string(cfg.backend.condaEnv);
params.sionnaModule = fullfile(expRoot, string(cfg.backend.sionnaModule));

params.fc     = cfg.radio.fc;
params.Pt_dBm = cfg.radio.Pt_dBm;

params.areaSize = cfg.grid.areaSize;
params.gridSize = cfg.grid.gridSize;
params.tx_pos_z = cfg.grid.tx_pos_z;
params.rx_pos_z = cfg.grid.rx_pos_z;

modelKey = string(cfg.models.activeModel);        % "VirtualScatter6D"
mCfg = cfg.models.(modelKey);
preset = string(mCfg.activeScenePreset);
scene  = cfg.scenes.(preset);
sceneBaseName = "scene_" + preset;
params.stlFile = fullfile(dataDir, sceneBaseName + ".stl");
params.plyFile = fullfile(dataDir, sceneBaseName + ".ply");
params.xmlFile = fullfile(dataDir, sceneBaseName + ".xml");
params.scatterTable = scene.scatterTable;

% model response file inside experiment
params.responseFile = fullfile(expRoot, mCfg.responseFile);

% ---------- Step 1) Environment + dataset ----------
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

% Select train/test datasets by active model mapping
sel = mCfg.datasetSelection;
trainKey = char(string(sel.trainSet));
testKey  = char(string(sel.testSet));

trainSet = dataSetCache.(trainKey);
testSet  = dataSetCache.(testKey);
raytracingResults = struct("trainSet", trainSet, "testSet", testSet);
envObj.raytracingResults = raytracingResults;

% ---------- Step 2) Environment plots (save to outputs) ----------
try
    EP = cfg.envEvaluation;
    orders = EP.txHeatmapOrders;
    for k = 1:numel(orders)
        savePath = fullfile(outDir, sprintf("env_test_txHeatmap_order%d_seed%d", orders(k), seed));
        envObj.evaluate("test", "txHeatmap", savePath, orders(k));
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
    warning(ME.identifier, '[SHOWCASE] env plots failed: %s', ME.message);
end

% ---------- Step 3) Train + evaluate VirtualScatter6D ----------
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
        error("Unknown activeModel: %s", modelKey);
end

modelObj.train("mode","save");

% ---------- Step 4) evaluation options ----------
E = cfg.modelEvaluation;
eopt = struct();
eopt.whichSet = string(E.whichSet);
eopt.cgmSliceMode = string(E.cgmSliceMode);
eopt.cgmGridList = E.cgmGridList;
eopt.doPdf = E.enablePdf;
eopt.doCgm = E.enableCgm;
eopt.doResidual = E.enableResidual;

evalSavePath = fullfile(outDir, sprintf("%s_seed%d", char(modelKey), seed));
modelObj.evaluate(eopt, evalSavePath);

fprintf("[SHOWCASE] Done. preset=%s, outputs=%s\n", preset, outDir);

