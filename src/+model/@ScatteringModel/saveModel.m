function saveModel(obj)
% saveModel - persist scatterInfo to the configured response MAT file.
% Throws if scatterInfo is empty.
if isempty(obj.scatterInfo)
    error('[ScatteringModel.save] scatterInfo is empty. Nothing to save.');
end

scatterer = obj.scatterInfo; 
save(obj.ModelSpec.responseFile, 'scatterer');

fprintf('[ScatteringModel.save] scatterInfo saved to %s\n', obj.ModelSpec.responseFile);
end
