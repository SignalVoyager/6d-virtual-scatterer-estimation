% run_experiment.m (COMPARISON)
% Inputs injected: expRoot, seed

dataDir = fullfile(expRoot, "data");
outDir  = fullfile(expRoot, "outputs");
if ~isfolder(dataDir), mkdir(dataDir); end
if ~isfolder(outDir),  mkdir(outDir);  end

cfg = jsondecode(fileread(fullfile(expRoot, "config.json")));

% ---------- params ----------
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
        ds.dataMode, sceneModeCfg, dsPath, ...
        "samplingMode", samplingMode, ...
        "samplingArgs", samplingArgs);
end

% ---------- Step 2) Environment plots (optional) ----------
if isfield(cfg, "plots")
    try
        if isfield(cfg.plots, "envTxHeatmapOrders")
            orders = cfg.plots.envTxHeatmapOrders;
            for kk = 1:numel(orders)
                envObj.evaluate("test", "txHeatmap", orders(kk));
                saveas(gcf, fullfile(outDir, sprintf("env_test_txHeatmap_order%d_seed%d.png", orders(kk), seed)));
            end
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
        warning(ME.identifier, '[COMPARISON] env plots failed: %s', ME.message);
    end
end

% Per-model dataset selection only.
% Each model entry must define:
%   cfg.models.<modelKey>.datasetSelection.trainSet
%   cfg.models.<modelKey>.datasetSelection.testSet

% ---------- evaluation opt ----------
eopt = struct();
if isfield(cfg, "evaluation")
    E = cfg.evaluation;
    if isfield(E,"whichSet"),   eopt.whichSet = string(E.whichSet); else, eopt.whichSet="test"; end
    if isfield(E,"doPdf"),      eopt.doPdf = E.doPdf; else, eopt.doPdf=true; end
    if isfield(E,"doCgm"),      eopt.doCgm = E.doCgm; else, eopt.doCgm=true; end
    if isfield(E,"doResidual"), eopt.doResidual = E.doResidual; else, eopt.doResidual=true; end
    if isfield(E,"txGridList"), eopt.txGridList = E.txGridList; end
else
    eopt.whichSet="test"; eopt.doPdf=true; eopt.doCgm=true; eopt.doResidual=true;
end

% ---------- loop models ----------
modelList = string(cfg.models.modelList);
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
    figsBefore = findall(0, 'Type', 'figure');
    modelObj.train("mode","save");
    modelObj.evaluate(eopt);

    % ---- save figures created by this model run only ----
    saveFigs = true;
    if isfield(cfg, "plots") && isfield(cfg.plots, "saveFigures")
        saveFigs = logical(cfg.plots.saveFigures);
    end
    if saveFigs
        figsAfter = findall(0, 'Type', 'figure');
        figs = setdiff(figsAfter, figsBefore);
        for i = 1:numel(figs)
            saveas(figs(i), fullfile(outDir, sprintf("%s_fig_%02d_seed%d.png", modelKey, i, seed)));
        end
    end
    close all;

    % ---- store a lightweight record (you can extend later) ----
    resultsSummary.models.(modelKey) = struct( ...
        "responseFile", string(mCfg.responseFile), ...
        "trainSet", string(trainKey), ...
        "testSet", string(testKey), ...
        "status", "done" ...
    );
end

save(fullfile(outDir, sprintf("comparison_summary_seed%d.mat", seed)), "resultsSummary");
fprintf("[COMPARISON] Done. preset=%s, outputs=%s\n", preset, outDir);





