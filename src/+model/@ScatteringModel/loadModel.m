function loadModel(obj)
% loadModel - load scatterInfo from ModelSpec.responseFile.
% Only scatterInfo is restored; other specs are not overwritten.

S = load(obj.ModelSpec.responseFile, 'scatterer');
if ~isfield(S, 'scatterer')
    error('[ScatteringModel.load] scatterInfo not found in file.');
end

obj.scatterInfo = S.scatterer;

fprintf('[ScatteringModel.load] scatterInfo loaded from %s\n', obj.ModelSpec.responseFile);
end
