%% validateExperimentConfig
%
% Validates experiment config.json structure and cross-reference consistency.
%
% SYNTAX:
%   validateExperimentConfig(cfg)
%
% INPUTS:
%   cfg - struct
%       Decoded config.json.
%
function validateExperimentConfig(cfg)
iRequireFields(cfg, ["backend","radio","grid","scenes","dataSetList","models","runtime"], "cfg");
iRequireFields(cfg.runtime, ["outputMode"], "cfg.runtime");
iRequireOneOf(lower(string(cfg.runtime.outputMode)), ["log","console","both"], "cfg.runtime.outputMode");

modelList = iResolveModelList(cfg.models);
dataSetList = iResolveDataSetList(cfg.dataSetList);
dsPresetMap = iBuildDataSetPresetMap(dataSetList);
scenePresets = iValidateSelectedModels(cfg.models, modelList, dsPresetMap);
iValidateResolvedScene(cfg.scenes, scenePresets);
end

function iRequireFields(s, requiredFields, context)
for i = 1:numel(requiredFields)
    f = char(requiredFields(i));
    if ~isfield(s, f)
        error("validateExperimentConfig: Missing required field %s.%s", context, f);
    end
end
end

function iRequireOneOf(value, allowedValues, context)
if ~isscalar(value) || ~any(value == allowedValues)
    rawValue = strjoin(string(value), ",");
    error("validateExperimentConfig: Unsupported %s=%s", context, rawValue);
end
end

function modelList = iResolveModelList(modelsCfg)
if isfield(modelsCfg, "activeModel")
    modelList = string(modelsCfg.activeModel);
elseif isfield(modelsCfg, "modelList")
    modelList = string(modelsCfg.modelList);
else
    error("validateExperimentConfig: Missing cfg.models.activeModel/modelList.");
end
if isempty(modelList)
    error("validateExperimentConfig: cfg.models.activeModel/modelList must be non-empty.");
end
end

function dataSetList = iResolveDataSetList(rawDataSetList)
if ~iscell(rawDataSetList)
    error("validateExperimentConfig: cfg.dataSetList must be a cell array.");
end
if isempty(rawDataSetList)
    error("validateExperimentConfig: cfg.dataSetList must be non-empty.");
end
dataSetList = [rawDataSetList{:}];
end

function dsPresetMap = iBuildDataSetPresetMap(dataSetList)
dsPresetMap = struct();
for i = 1:numel(dataSetList)
    ds = dataSetList(i);
    iRequireFields(ds, ["name","activeScenePreset","Nt_side","Nr_side","dataMode","samplingMode"], ...
        sprintf("cfg.dataSetList(%d)", i));

    dsName = char(string(ds.name));
    if isfield(dsPresetMap, dsName)
        error("validateExperimentConfig: Duplicate dataset name: %s", dsName);
    end
    dsPresetMap.(dsName) = string(ds.activeScenePreset);
end
end

function scenePresets = iValidateSelectedModels(modelsCfg, modelList, dsPresetMap)
scenePresets = strings(size(modelList));
for iModel = 1:numel(modelList)
    modelKey = char(modelList(iModel));
    modelContext = sprintf("cfg.models.%s", modelKey);
    if ~isfield(modelsCfg, modelKey)
        error("validateExperimentConfig: Missing model config: %s", modelKey);
    end

    mCfg = modelsCfg.(modelKey);
    iRequireFields(mCfg, ["responseFile","datasetSelection","hyper"], modelContext);
    iRequireFields(mCfg.datasetSelection, ["trainSet","testSet"], sprintf("%s.datasetSelection", modelContext));

    requiredHyperFields = iRequiredHyperFieldsForModel(string(modelKey));
    if ~isempty(requiredHyperFields)
        iRequireFields(mCfg.hyper, requiredHyperFields, sprintf("%s.hyper", modelContext));
    end

    trainKeys = iStringList(mCfg.datasetSelection.trainSet);
    testKeys = iStringList(mCfg.datasetSelection.testSet);
    if numel(testKeys) ~= 1
        error("validateExperimentConfig: testSet must contain exactly one dataset.");
    end
    testKey = char(testKeys(1));
    trainPresets = strings(size(trainKeys));
    for iTrain = 1:numel(trainKeys)
        trainKey = char(trainKeys(iTrain));
        if ~isfield(dsPresetMap, trainKey)
            error("validateExperimentConfig: trainSet %s not found in dataSetList", trainKey);
        end
        trainPresets(iTrain) = dsPresetMap.(trainKey);
    end
    if ~isfield(dsPresetMap, testKey)
        error("validateExperimentConfig: testSet %s not found in dataSetList", testKey);
    end

    testPreset = dsPresetMap.(testKey);
    if any(trainPresets ~= testPreset)
        error("validateExperimentConfig: Model %s has inconsistent train/test activeScenePreset.", modelKey);
    end
    scenePresets(iModel) = testPreset;
end
end

function keys = iStringList(raw)
if iscell(raw)
    keys = string(raw);
else
    keys = string(raw);
end
keys = keys(:).';
if isempty(keys) || any(strlength(keys) == 0)
    error("validateExperimentConfig: dataset selection must be a non-empty string or string list.");
end
end

function requiredFields = iRequiredHyperFieldsForModel(modelKey)
switch modelKey
    case {"VirtualScatter6D","VirtualScatter3D"}
        requiredFields = ["NumCenters","PathLossExp","RefDistance","EpsDist","Solver"];
    case "KrigingModel"
        requiredFields = ["MaxDistance","NumBins","StableAlpha"];
    otherwise
        error("validateExperimentConfig: Unknown model key in modelList: %s", modelKey);
end
end

function iValidateResolvedScene(scenesCfg, scenePresets)
if numel(unique(scenePresets)) ~= 1
    error("validateExperimentConfig: Selected models must share one activeScenePreset.");
end

preset = scenePresets(1);
if ~isfield(scenesCfg, char(preset))
    error("validateExperimentConfig: Resolved preset %s missing in cfg.scenes.", char(preset));
end

sceneCfg = scenesCfg.(char(preset));
if ~isfield(sceneCfg, "scatterTable")
    error("validateExperimentConfig: cfg.scenes.%s.scatterTable is required.", char(preset));
end
end
