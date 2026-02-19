function data = loadDataset(~, file)
% loadDataset - load the variable "Results" from a MAT file.
% Returns the loaded matrix/struct without mutating object state.
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
