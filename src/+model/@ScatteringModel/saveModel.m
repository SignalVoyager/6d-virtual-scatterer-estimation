% SAVEMODEL Save the scattering model information to a file
%   SAVEMODEL(OBJ) saves the scatterInfo property of the ScatteringModel
%   object to a MAT file specified by OBJ.ModelSpec.responseFile.
%
%   The method performs the following operations:
%   1. Validates that scatterInfo is not empty
%   2. Extracts scatterInfo into a local variable
%   3. Saves the scatterer data to the specified response file
%   4. Displays a confirmation message to the command window
%
%   Errors:
%   - Throws an error if scatterInfo is empty, preventing save with no data
%
%   Example:
%   model = ScatteringModel();
%   model.scatterInfo = [...];  % populate scatterInfo
%   model.saveModel();          % save to file
%
%   See also: LOAD, SAVE
function saveModel(obj)
if isempty(obj.scatterInfo)
    error('[ScatteringModel.save] scatterInfo is empty. Nothing to save.');
end

scatterer = obj.scatterInfo; 
save(obj.ModelSpec.responseFile, 'scatterer');

fprintf('[ScatteringModel.save] scatterInfo saved to %s\n', obj.ModelSpec.responseFile);
end
