% generateDataset - generate or load one dataset only
%
%   Results = generateDataset(obj, Nt_side, Nr_side, dataMode, sceneMode, filePath)
%   Results = generateDataset(obj, Nt_side, Nr_side, dataMode, sceneMode, filePath, ...)
%
% Input Parameters:
%   obj         - WirelessEnvironment object
%   Nt_side     - Number of TX sub-samples per grid side
%   Nr_side     - Number of RX sub-samples per grid side
%   dataMode    - "load" or "save"
%   sceneMode   - "load" or "save" (used when dataMode="save")
%   filePath    - MAT file path used for load/save
%
% Name-Value Pairs:
%   "samplingMode" - datasetSampling mode used when dataMode="save"
%                    (default: "geom-geom")
%   "samplingArgs" - cell array of name-value args passed to datasetSampling
%                    (default: {})
%
% Output:
%   Results     - numeric matrix [N x 3] = [tx_idx, rx_idx, power_mW]
%
% Behavior:
%   - "load": Results = loadDataset(filePath)
%   - "save":
%       1) datasetScene(sceneMode)
%       2) datasetSampling(samplingMode, samplingArgs{:})
%       3) datasetRayTracing(...)
%       4) saveDataset(filePath, Results)
function Results = generateDataset(obj, Nt_side, Nr_side, dataMode, sceneMode, filePath, varargin)
p = inputParser;
p.addParameter("samplingMode", "geom-geom");
p.addParameter("samplingArgs", {}, @(x) iscell(x));
p.parse(varargin{:});
opt = p.Results;

dataMode = lower(string(dataMode));
sceneMode = lower(string(sceneMode));
samplingMode = string(opt.samplingMode);
samplingArgs = opt.samplingArgs;

switch dataMode
    case "load"
        Results = obj.loadDataset(filePath);

    case "save"
        fprintf('[WirelessEnvironment] Preparing scene geometry (sceneMode=%s) ...\n', sceneMode);
        obj.datasetScene(sceneMode);

        fprintf('[WirelessEnvironment] Calling ray tracing model (samplingMode=%s) ...\n', samplingMode);
        samplingPlans = obj.datasetSampling(samplingMode, samplingArgs{:});

        Results = obj.datasetRayTracing(samplingPlans, Nt_side, Nr_side, "sionna");
        obj.saveDataset(filePath, Results);

    otherwise
        error('generateDataset: Unknown dataMode "%s". Use "load" or "save".', dataMode);
end
end
