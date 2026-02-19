%   saveDataset Save dataset to a file
%
%   Syntax:
%       saveDataset(obj, file, data)
%
%   Description:
%       Saves the provided data structure to a MATLAB binary file (.mat) 
%       in version 7.3 format. The data is stored under the variable name 
%       'Results'. If the file already exists, it will be overwritten.
%
%   Input Arguments:
%       file    - (string or char) File path where the dataset will be saved.
%                 Must not be empty.
%       data    - Structure containing the results to be saved.
%                 Must not be empty.
%
%   Errors:
%       Throws an error if:
%       - file path is empty
%       - data structure is empty
%
%   Notes:
%       - Uses MATLAB format version 7.3 for compatibility with large files
%       - Automatically overwrites existing files without confirmation
%       - Displays a confirmation message to the command window upon success
%
%   Example:
%       obj.saveDataset('results.mat', myData);
function saveDataset(~, file, data)
file = string(file);
if strlength(file)==0
    error('[WirelessEnvironment] saveDataset: empty file path.');
end
if isempty(data)
    error('[WirelessEnvironment] saveDataset: data is empty. Nothing to save.');
end
Results = data;
save(file, 'Results', '-v7.3');
fprintf('[WirelessEnvironment] Saved Results to %s (overwrite)\n', file);
end
