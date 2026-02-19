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

preset = string(cfg.activeScenePreset);
scene  = cfg.scenePresets.(preset);
params.scatterTable = scene.scatterTable;

% model response file inside experiment
modelKey = string(cfg.models.activeModel);        % "VirtualScatter6D"
mCfg = cfg.models.(modelKey);
params.responseFile = fullfile(expRoot, mCfg.responseFile);

% ---------- dataset files ----------
Nt_side = cfg.dataset.Nt_side;
Nr_side = cfg.dataset.Nr_side;
trainFile = fullfile(expRoot, cfg.dataset.trainFile);
testFile  = fullfile(expRoot, cfg.dataset.testFile);

% ---------- Step 1) Environment + dataset ----------
envObj = env.WirelessEnvironment(params);

envObj.generateDataset(Nt_side, Nr_side, cfg.dataset.dataMode, cfg.dataset.sceneMode, trainFile, "isTrain", true);
envObj.generateDataset(Nt_side, Nr_side, cfg.dataset.dataMode, cfg.dataset.sceneMode, testFile,  "isTrain", false);

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
raytracingResults = envObj.raytracingResults;

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

opt = struct();
opt.whichSet   = "test";
opt.doPdf      = true;
opt.doCgm      = true;
opt.doResidual = true;

if isfield(cfg.plots, "diagTxGridList")
    txGridList = cfg.plots.diagTxGridList;
    if iscell(txGridList)
        txGridList = cell2mat(txGridList);
    end
    opt.txGridList = txGridList;
else
    opt.txGridList = [30 20];
end

modelObj.evaluate(opt);

% ---------- Save all figures produced so far ----------
if isfield(cfg.plots, "saveFigures") && cfg.plots.saveFigures
    figs = findall(0, 'Type', 'figure');
    for i = 1:numel(figs)
        saveas(figs(i), fullfile(outDir, sprintf("showcase_fig_%02d_seed%d.png", i, seed)));
    end
end

fprintf("[SHOWCASE] Done. preset=%s, outputs=%s\n", preset, outDir);


