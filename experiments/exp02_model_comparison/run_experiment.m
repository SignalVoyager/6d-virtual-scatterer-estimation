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

preset = string(cfg.activeScenePreset);
scene  = cfg.scenePresets.(preset);
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
        ds.dataMode, ds.sceneMode, dsPath, ...
        "samplingMode", samplingMode, ...
        "samplingArgs", samplingArgs);
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
    if isfield(E,"doPdf"),      eopt.doPdf = E.doPdf; else, eopt.doPdf=false; end
    if isfield(E,"doCgm"),      eopt.doCgm = E.doCgm; else, eopt.doCgm=false; end
    if isfield(E,"doResidual"), eopt.doResidual = E.doResidual; else, eopt.doResidual=false; end
    if isfield(E,"txGridList"), eopt.txGridList = E.txGridList; end
else
    eopt.whichSet="test"; eopt.doPdf=false; eopt.doCgm=false; eopt.doResidual=false;
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
    modelObj.train("mode","save");
    modelObj.evaluate(eopt);

    % ---- save figures per model (optional, but controlled) ----
    figs = findall(0, 'Type', 'figure');
    for i = 1:numel(figs)
        saveas(figs(i), fullfile(outDir, sprintf("%s_fig_%02d_seed%d.png", modelKey, i, seed)));
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
