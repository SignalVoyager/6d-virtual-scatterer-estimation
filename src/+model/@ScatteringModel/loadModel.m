% loadModel Load scatterer information from the model specification file
%
%   loadModel(obj) loads the scatterer information from the .mat file
%   specified in obj.ModelSpec.responseFile and assigns it to
%   obj.scatterInfo. Only the scatterer data is restored; other model
%   specifications are not modified.
%
%   The method expects the .mat file to contain a variable named 'scatterer'.
%   If the variable is not found, an error is raised.
%
%   Inputs:
%       obj - ScatteringModel object
%
%   Output:
%       None
%
%   Errors:
%       Throws an error if 'scatterer' variable is not found in the
%       specified response file.
%
%   Example:
%       model.loadModel();
%
%   See also: ScatteringModel, ModelSpec
function loadModel(obj)
S = load(obj.ModelSpec.responseFile, 'scatterer');
if ~isfield(S, 'scatterer')
    error('[ScatteringModel.load] scatterInfo not found in file.');
end

obj.scatterInfo = S.scatterer;

fprintf('[ScatteringModel.load] scatterInfo loaded from %s\n', obj.ModelSpec.responseFile);
end
