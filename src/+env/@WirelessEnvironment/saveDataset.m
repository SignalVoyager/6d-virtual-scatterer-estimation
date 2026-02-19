function saveDataset(~, file, data)
% saveDataset - save input data into a MAT file as variable "Results".
% The file is overwritten using -v7.3 format.
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
