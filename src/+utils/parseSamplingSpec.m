%% parseSamplingSpec
%
% Parses a sampling specification structure and extracts the sampling mode
% and normalized arguments.
%
% SYNTAX:
%   [mode, args] = parseSamplingSpec(spec)
%
% INPUTS:
%   spec - struct
%       A structure containing sampling configuration with the following fields:
%       - samplingMode (required): string specifying the sampling mode
%       - samplingArgs (optional): struct containing sampling arguments
%
% OUTPUTS:
%   mode - string
%       The sampling mode extracted from spec.samplingMode.
%       Supported modes: "geom-geom", "list-rand", "list-geom", "rand-rand", "randblock-randblock"
%
%   args - cell array
%       A key-value paired cell array of normalized arguments in the form
%       {key1, val1, key2, val2, ...}. Arguments are ordered by mode-specific
%       preference, followed by any remaining arguments.
%
% NOTES:
%   - Throws an error if "samplingMode" field is missing.
%   - Arguments are normalized via iNormalizeJsonValue, which converts cell
%     arrays to matrices when possible.
%   - Special handling for 'rxNum': negative scalar values are converted to inf.
%   - Argument order is determined by iPreferredOrder for each sampling mode.
%
% SEE ALSO:
%   iPreferredOrder, iNormalizeJsonValue
function [mode, args] = parseSamplingSpec(spec)
if ~isfield(spec, "samplingMode")
    error('parseSamplingSpec: Missing required field "samplingMode".');
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
        args(end+1:end+2) = {key, val};
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
    args(end+1:end+2) = {key, val};
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
            % keep original cell structure when conversion is invalid
        end
    end

    out = in;
    return;
end

out = in;
end
