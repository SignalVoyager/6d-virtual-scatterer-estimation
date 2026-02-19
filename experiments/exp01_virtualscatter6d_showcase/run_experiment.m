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

params.stlFile      = fullfile(dataDir, "scene.stl");
params.plyFile      = fullfile(dataDir, "scene.ply");
params.xmlFile  = fullfile(dataDir, "scene.xml");

params.condaEnv = string(cfg.backend.condaEnv);
params.sionnaModule = fullfile(expRoot, string(cfg.backend.sionnaModule));

params.fc     = cfg.radio.fc;
params.Pt_dBm = cfg.radio.Pt_dBm;

params.areaSize = cfg.grid.areaSize;
params.gridSize = cfg.grid.gridSize;
params.tx_pos_z = cfg.grid.tx_pos_z;
params.rx_pos_z = cfg.grid.rx_pos_z;

preset = string(cfg.scenes.activeScenePreset);
scene  = cfg.scenes.(preset);
params.scatterTable = scene.scatterTable;
sceneModeCfg = string(scene.sceneMode);

% model response file inside experiment
modelKey = string(cfg.models.activeModel);        % "VirtualScatter6D"
mCfg = cfg.models.(modelKey);
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
        ds.dataMode, sceneModeCfg, dsPath, ...
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

% Track figure handles created during this script run only
figsBefore = findall(0, 'Type', 'figure');

% ---------- Step 2) Environment plots (save to outputs) ----------
try
    orders = cfg.plots.envTxHeatmapOrders;
    for k = 1:numel(orders)
        envObj.evaluate("test", "txHeatmap", orders(k));
        saveas(gcf, fullfile(outDir, sprintf("env_test_txHeatmap_order%d_seed%d.png", orders(k), seed)));
    end

    if isfield(cfg.plots, "doRxCount") && cfg.plots.doRxCount
        envObj.evaluate("train", "rxCount");
        saveas(gcf, fullfile(outDir, sprintf("env_train_rxCount_seed%d.png", seed)));
    end
    if isfield(cfg.plots, "doTxCount") && cfg.plots.doTxCount
        envObj.evaluate("train", "txCount");
        saveas(gcf, fullfile(outDir, sprintf("env_train_txCount_seed%d.png", seed)));
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

% ---------- Step 4) evaluation options (aligned with exp02 schema) ----------
eopt = struct();
if isfield(cfg, "evaluation")
    E = cfg.evaluation;
    if isfield(E, "whichSet"),   eopt.whichSet = string(E.whichSet); else, eopt.whichSet = "test"; end
    if isfield(E, "doPdf"),      eopt.doPdf = E.doPdf; else, eopt.doPdf = true; end
    if isfield(E, "doCgm"),      eopt.doCgm = E.doCgm; else, eopt.doCgm = true; end
    if isfield(E, "doResidual"), eopt.doResidual = E.doResidual; else, eopt.doResidual = true; end
    if isfield(E, "txGridList")
        eopt.txGridList = E.txGridList;
    elseif isfield(cfg, "plots") && isfield(cfg.plots, "diagTxGridList")
        eopt.txGridList = cfg.plots.diagTxGridList; % backward compatibility
    end
else
    eopt.whichSet = "test"; eopt.doPdf = true; eopt.doCgm = true; eopt.doResidual = true;
    if isfield(cfg, "plots") && isfield(cfg.plots, "diagTxGridList")
        eopt.txGridList = cfg.plots.diagTxGridList; % backward compatibility
    end
end

modelObj.evaluate(eopt);

% ---------- Save figures created by this script run only ----------
if isfield(cfg.plots, "saveFigures") && cfg.plots.saveFigures
    figsAfter = findall(0, 'Type', 'figure');
    figs = setdiff(figsAfter, figsBefore);
    for i = 1:numel(figs)
        saveas(figs(i), fullfile(outDir, sprintf("showcase_fig_%02d_seed%d.png", i, seed)));
    end
end

fprintf("[SHOWCASE] Done. preset=%s, outputs=%s\n", preset, outDir);

