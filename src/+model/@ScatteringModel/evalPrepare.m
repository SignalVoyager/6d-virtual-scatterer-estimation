function P = evalPrepare(obj, whichSet, opt)
% P: struct packing evaluation essentials

if nargin < 3 || isempty(opt), opt = struct(); end
if ~isfield(opt,"q"), opt.q = 0.02; end
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

% predict
[gain_sum, ~, ~] = obj.predict(data(:,1:2));

y_mW    = data(:,3);
yhat_mW = gain_sum(:);
res_mW  = y_mW - yhat_mW;

% noise floor projection (linear domain)
% If you use utils package: utils.applyNoiseFloor
[y_mW, yhat_mW] = applyNoiseFloor(y_mW, yhat_mW, opt.q, opt.eps_min);

% valid mask for dB-domain plots
valid = ~isnan(y_mW) & ~isinf(y_mW) & (y_mW > 0) & ...
        ~isnan(yhat_mW) & ~isinf(yhat_mW) & (yhat_mW > 0);

% dB error (safe)
y_dBm    = 10*log10(max(y_mW,    opt.eps_mW));
yhat_dBm = 10*log10(max(yhat_mW, opt.eps_mW));
err_dB   = y_dBm - yhat_dBm;

P = struct();
P.data    = data;
P.y_mW    = y_mW;
P.yhat_mW = yhat_mW;
P.res_mW  = res_mW;
P.valid   = valid;
P.y_dBm   = y_dBm;
P.yhat_dBm= yhat_dBm;
P.err_dB  = err_dB;
end
