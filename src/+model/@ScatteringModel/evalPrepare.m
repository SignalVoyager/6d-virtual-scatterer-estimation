%EVALPREPARE Prepare evaluation metrics and data for model assessment
%   P = EVALPREPARE(OBJ, WHICHSET, OPT) packages evaluation essentials
%   including predictions, residuals, and error metrics in both linear
%   and dB domains with noise floor handling.
%
%   Input Arguments:
%       OBJ         - ScatteringModel instance
%       WHICHSET    - String specifying dataset: "test", "train", or "all"
%       OPT         - Optional struct with configuration parameters:
%           .q          - Quantile for noise floor (default: 0.02)
%           .eps_min    - Minimum threshold for linear domain (default: 1e-12)
%           .eps_mW     - Minimum threshold for dB conversion (default: 1e-12)
%
%   Output Arguments:
%       P           - Struct containing:
%           .data       - Original input data [positions, measurements]
%           .y_mW       - Ground truth power (linear, mW)
%           .yhat_mW    - Predicted power (linear, mW)
%           .res_mW     - Linear domain residuals
%           .valid      - Logical mask for valid measurements
%           .y_dBm      - Ground truth power (dB domain)
%           .yhat_dBm   - Predicted power (dB domain)
%           .err_dB     - dB domain error
%
%   Notes:
%       - Applies noise floor projection before dB conversion
%       - Validates measurements for NaN, Inf, and positivity
%       - Safe dB conversion using eps_mW threshold
%
%   See also: PREDICT, APPLYNOISEFLOOR
function P = evalPrepare(obj, whichSet, opt)
if nargin < 3 || isempty(opt), opt = struct(); end
if ~isfield(opt,"q"), opt.q = 0.017; end
if ~isfield(opt,"eps_min"), opt.eps_min = 1e-12; end
if ~isfield(opt,"eps_mW"), opt.eps_mW = 1e-12; end

whichSet = lower(string(whichSet));
switch whichSet
    case "test"
        data = obj.raytracingResults.testSet;
    case "train"
        data = obj.raytracingResults.trainSet;
    case "all"
        data = [obj.raytracingResults.trainSet; obj.raytracingResults.testSet];
    otherwise
        error('evalPrepare: whichSet must be "test","train","all".');
end
if isempty(data)
    error('evalPrepare: selected dataset "%s" is empty.', whichSet);
end

% predict
[gain_sum, ~, ~] = obj.predict(data(:,1:2));

y_mW_raw    = data(:,3);
yhat_mW_raw = gain_sum(:);

y_mW    = y_mW_raw;
yhat_mW = yhat_mW_raw;

% noise floor projection (linear domain)
% If you use utils package: utils.applyNoiseFloor
[y_mW, yhat_mW] = applyNoiseFloor(y_mW, yhat_mW, opt.q, opt.eps_min);
res_mW  = y_mW - yhat_mW;

% valid mask for dB-domain plots
valid = ~isnan(y_mW) & ~isinf(y_mW) & (y_mW > 0) & ...
        ~isnan(yhat_mW) & ~isinf(yhat_mW) & (yhat_mW > 0);

% dB error (safe)
y_dBm    = 10*log10(max(y_mW,    opt.eps_mW));
yhat_dBm = 10*log10(max(yhat_mW, opt.eps_mW));
err_dB   = y_dBm - yhat_dBm;

P = struct();
P.data    = data;
P.y_mW_raw    = y_mW_raw;
P.yhat_mW_raw = yhat_mW_raw;
P.y_mW    = y_mW;
P.yhat_mW = yhat_mW;
P.res_mW  = res_mW;
P.valid   = valid;
P.y_dBm   = y_dBm;
P.yhat_dBm= yhat_dBm;
P.err_dB  = err_dB;
P.nTotal  = numel(y_mW);
P.nValid  = nnz(valid);
if isfield(opt, "scoreSpec")
    P.scoreSpec = opt.scoreSpec;
end
end
