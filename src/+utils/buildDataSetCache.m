%% buildDataSetCache
%
% Builds all datasets described in config.dataSetList and returns them as a
% name-indexed struct cache.
%
% SYNTAX:
%   dataSetCache = buildDataSetCache(envObj, dataSetList, dataDir)
%
% INPUTS:
%   envObj - env.WirelessEnvironment
%       Environment object that provides generateDataset().
%
%   dataSetList - struct array
%       Dataset entries from config.dataSetList.
%
%   dataDir - string/char
%       Directory where dataset MAT files are saved/loaded as data/<name>.mat.
%
% OUTPUTS:
%   dataSetCache - struct
%       Struct with fields keyed by dataset name.
%
% SEE ALSO:
%   env.WirelessEnvironment/generateDataset
function dataSetCache = buildDataSetCache(envObj, dataSetList, dataDir)
dataSetList = [dataSetList{:}];
dataSetCache = struct();

for i = 1:numel(dataSetList)
    ds = dataSetList(i);
    dsName = char(string(ds.name));
    [samplingMode, samplingArgs] = iParseSamplingSpec(ds);
    dsPath = fullfile(dataDir, string(ds.name) + ".mat");

    dataSetCache.(dsName) = envObj.generateDataset( ...
        ds.Nt_side, ds.Nr_side, ...
        ds.dataMode, "save", dsPath, ...
        "samplingMode", samplingMode, ...
        "samplingArgs", samplingArgs);
end
end

function [mode, args] = iParseSamplingSpec(spec)
if ~isfield(spec, "samplingMode")
    error('buildDataSetCache: Missing required field "samplingMode".');
end
mode = string(spec.samplingMode);

if isfield(spec, "samplingArgs")
    rawArgs = spec.samplingArgs;
else
    rawArgs = struct();
end

args = {};
if isempty(rawArgs)
    return;
end

orderedKeys = iPreferredOrder(mode);
for i = 1:numel(orderedKeys)
    key = orderedKeys{i};
    if isstring(key)
        key = char(key);
    end
    if isfield(rawArgs, key)
        val = iNormalizeJsonValue(rawArgs.(key));
        if strcmp(key, 'rxNum') && isnumeric(val) && isscalar(val) && val < 0
            val = inf;
        end
        args(end+1:end+2) = {key, val}; %#ok<AGROW>
    end
end

allKeys = fieldnames(rawArgs);
remaining = setdiff(allKeys, orderedKeys, 'stable');
for i = 1:numel(remaining)
    key = remaining{i};
    if isstring(key)
        key = char(key);
    end
    val = iNormalizeJsonValue(rawArgs.(key));
    if strcmp(key, 'rxNum') && isnumeric(val) && isscalar(val) && val < 0
        val = inf;
    end
    args(end+1:end+2) = {key, val}; %#ok<AGROW>
end
end

function orderedKeys = iPreferredOrder(mode)
switch lower(mode)
    case "geom-geom"
        orderedKeys = {'txNumPerSc', 'rxNumPerSc', 'radiationMin', 'radiationMax'};
    case "list-rand"
        orderedKeys = {'txGridList', 'rxNum'};
    case "list-geom"
        orderedKeys = {'txGridList', 'rxNumPerSc', 'radiationMin', 'radiationMax', 'dedupRx', 'oneBlockPerTx'};
    case "rand-rand"
        orderedKeys = {'txNum', 'rxNum'};
    case "randblock-randblock"
        orderedKeys = {'txNumPerBlock', 'rxNumPerBlock', 'numBlocks'};
    otherwise
        orderedKeys = {};
end
end

function out = iNormalizeJsonValue(in)
if iscell(in)
    if isempty(in)
        out = [];
        return;
    end

    if all(cellfun(@isnumeric, in))
        try
            out = cell2mat(in);
            return;
        catch
            % Keep original cell structure when conversion is invalid.
        end
    end

    out = in;
    return;
end

out = in;
end
