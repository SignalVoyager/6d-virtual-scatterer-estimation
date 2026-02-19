function generateDataset(obj, Nt_side, Nr_side, dataMode, sceneMode, filePath, varargin)
% generateDataset - orchestrate dataset loading or generation and persistence.
% dataMode controls dataset file workflow; sceneMode controls scene file workflow.
%   dataMode: "load" | "save"
%   sceneMode: "load" | "save" (used when dataMode = "save")

if nargin < 6
    % Backward compatibility with old signature:
    % generateDataset(obj, Nt_side, Nr_side, dataMode, filePath, ...)
    filePath = sceneMode;
    sceneMode = "save";
end

p = inputParser;
p.addParameter("isTrain", true);
p.parse(varargin{:});
opt = p.Results;

dataMode = lower(string(dataMode));
sceneMode = lower(string(sceneMode));

if isempty(obj.raytracingResults) || ~isstruct(obj.raytracingResults)
    obj.raytracingResults = struct();
end

switch dataMode
    case "load"
        if opt.isTrain
            obj.raytracingResults.trainSet = obj.loadDataset(filePath);
        else
            obj.raytracingResults.testSet = obj.loadDataset(filePath);
        end

    case "save"
        fprintf('[WirelessEnvironment] Preparing scene geometry (sceneMode=%s) ...\n', sceneMode);
        obj.datasetScene(sceneMode);

        fprintf('[WirelessEnvironment] Calling ray tracing model ...\n');
        if opt.isTrain
            trainBlocks = obj.datasetSampling("geom-geom", "txNumPerSc",4, "rxNumPerSc",4, 'radiationMin', 2*obj.GridSpec.gridSize, 'radiationMax', 4*obj.GridSpec.gridSize);
            obj.raytracingResults.trainSet = obj.datasetRayTracing(trainBlocks, Nt_side, Nr_side, "sionna");
            obj.saveDataset(filePath, obj.raytracingResults.trainSet);
        else
            testBlocks = obj.datasetSampling("list-rand", 'txGridList',[30,30;4,4;56,4;56,56;4,56], 'rxNum', inf);
            obj.raytracingResults.testSet = obj.datasetRayTracing(testBlocks, Nt_side, Nr_side, "sionna");
            obj.saveDataset(filePath, obj.raytracingResults.testSet);
        end

    otherwise
        error('generateDataset: Unknown dataMode "%s". Use "load" or "save".', dataMode);
end
end
