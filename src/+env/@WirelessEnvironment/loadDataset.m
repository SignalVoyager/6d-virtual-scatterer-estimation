%% loadDataset
%   Loads dataset from a .mat file containing a 'Results' variable.
%
%   Syntax:
%       data = loadDataset(obj, file)
%
%   Input Arguments:
%       obj   - WirelessEnvironment object (unused, ~)
%       file  - (string or char) Path to the .mat file containing Results
%
%   Output Arguments:
%       data  - Structure array loaded from the 'Results' variable
%
%   Description:
%       This method loads a MATLAB .mat file and extracts the 'Results'
%       variable. It performs validation to ensure the file path is not
%       empty, the file exists, and the 'Results' variable is present and
%       non-empty before returning the data.
%
%   Error Handling:
%       - Throws error if file path is empty
%       - Throws error if file does not exist
%       - Throws error if 'Results' variable is missing or empty in file
%
%   Example:
%       env = env.WirelessEnvironment();
%       data = loadDataset(env, 'dataset.mat');
function data = loadDataset(~, file)
file = string(file);
if strlength(file)==0
    error('[WirelessEnvironment] loadDataset: empty file path.');
end
if ~isfile(file)
    error('[WirelessEnvironment] loadDataset: File not found: %s', file);
end
S = load(file, 'Results');
if ~isfield(S,'Results') || isempty(S.Results)
    error('[WirelessEnvironment] loadDataset: "Results" missing/empty in %s', file);
end
data = S.Results;
fprintf('[WirelessEnvironment] Loaded Results from %s\n', file);
end
