% regenerate_model_cgm_sources - Rebuild exp01 model CGM source figures from caches.
%
% This loads cached datasets and the saved model response; it does not retrain or
% rerun ray tracing.

function regenerate_model_cgm_sources(seed)
if nargin < 1 || isempty(seed), seed = 521; end

expRoot = fileparts(mfilename('fullpath'));
dataDir = fullfile(expRoot, "data");
outDir = fullfile(expRoot, "outputs");
modelOriginalDir = fullfile(outDir, "original", "model");

cfg = jsondecode(fileread(fullfile(expRoot, "config.json")));
if isstruct(cfg.dataSetList), cfg.dataSetList = num2cell(cfg.dataSetList); end

params = struct();
params.condaEnv = string(cfg.backend.condaEnv);
params.sionnaModule = fullfile(expRoot, string(cfg.backend.sionnaModule));
params.fc = cfg.radio.fc;
params.Pt_dBm = cfg.radio.Pt_dBm;
params.areaSize = cfg.grid.areaSize;
params.gridSize = cfg.grid.gridSize;
params.tx_pos_z = cfg.grid.tx_pos_z;
params.rx_pos_z = cfg.grid.rx_pos_z;

modelKey = string(cfg.models.activeModel);
mCfg = cfg.models.(modelKey);
sel = mCfg.datasetSelection;
trainKeys = iStringList(sel.trainSet);
testKey = char(iStringList(sel.testSet));

dataSetList = [cfg.dataSetList{:}];
dsPresetMap = struct();
for i = 1:numel(dataSetList)
    dsPresetMap.(char(string(dataSetList(i).name))) = string(dataSetList(i).activeScenePreset);
end
preset = dsPresetMap.(testKey);
scene = cfg.scenes.(preset);
sceneBaseName = "scene_" + preset;
params.stlFile = fullfile(dataDir, sceneBaseName + ".stl");
params.plyFile = fullfile(dataDir, sceneBaseName + ".ply");
params.xmlFile = fullfile(dataDir, sceneBaseName + ".xml");
params.scatterTable = scene.scatterTable;
params.responseFile = fullfile(expRoot, mCfg.responseFile);

envObj = env.WirelessEnvironment(params);
dataSetCache = utils.buildDataSetCache(envObj, cfg.dataSetList, dataDir);
raytracingResults = struct( ...
    "trainSet", iConcatDataSets(dataSetCache, trainKeys), ...
    "testSet", dataSetCache.(testKey));

h = mCfg.hyper;
modelObj = model.VirtualScatter6D(params, "VirtualScatter6D", raytracingResults, ...
    "NumCenters", h.NumCenters, ...
    "PathLossExp", h.PathLossExp, ...
    "RefDistance", h.RefDistance, ...
    "EpsDist", h.EpsDist, ...
    "Solver", h.Solver);
modelObj.train("mode", "load");

E = cfg.modelEvaluation;
saveDir = fullfile(modelOriginalDir, sprintf("%s_%s_seed%d", char(modelKey), char(E.cgmSliceMode), seed));
if ~isfolder(saveDir), mkdir(saveDir); end
eopt = struct();
eopt.whichSet = string(E.whichSet);
eopt.cgmSliceMode = string(E.cgmSliceMode);
eopt.cgmGridList = E.cgmGridList;
eopt.doPdf = false;
eopt.doCgm = true;
eopt.doResidual = false;
modelObj.evaluate(eopt, saveDir);
close all;
fprintf("[SHOWCASE] regenerated model CGM sources: %s\n", saveDir);
end

function keys = iStringList(raw)
keys = string(raw);
keys = keys(:).';
end

function data = iConcatDataSets(dataSetCache, keys)
data = zeros(0,3);
for i = 1:numel(keys)
    data = [data; dataSetCache.(char(keys(i)))]; %#ok<AGROW>
end
[~, ia] = unique(data(:,1:2), "rows", "stable");
data = data(ia,:);
end
