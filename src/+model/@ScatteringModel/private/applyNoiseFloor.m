function [y_proj, yhat_proj, eps_floor] = applyNoiseFloor(y, yhat, q, eps_min)
% applyNoiseFloor  Project y and yhat onto a noise floor estimated from y>0 samples.
%
%   [y_proj, yhat_proj] = applyNoiseFloor(y, yhat)
%   [y_proj, yhat_proj, eps_floor] = applyNoiseFloor(y, yhat, q, eps_min)
%
% Inputs:
%   y      : ground truth power (linear, e.g., mW), vector/matrix
%   yhat   : predicted power (linear), same size as y
%   q      : quantile for noise floor, default 0.01 (1% quantile)
%   eps_min: absolute minimum floor, default 1e-12
%
% Outputs:
%   y_proj     : max(y, eps_floor)
%   yhat_proj  : max(yhat, eps_floor)
%   eps_floor  : estimated noise floor used
%
% Notes:
%   - Noise floor is estimated ONLY from positive entries of y.
%   - If y has no positive entries, eps_floor falls back to eps_min.
if nargin < 3 || isempty(q), q = 0.01; end
if nargin < 4 || isempty(eps_min), eps_min = 1e-12; end

if ~isequal(size(y), size(yhat))
    error('applyNoiseFloor:SizeMismatch', 'y and yhat must have the same size.');
end
if ~(q > 0 && q < 1)
    error('applyNoiseFloor:BadQuantile', 'q must be in (0,1).');
end

ypos = y(y > 0);
if isempty(ypos)
    eps_floor = eps_min;
else
    eps_floor = quantile(ypos(:), q);
    eps_floor = max(eps_floor, eps_min);
end

y_proj    = max(y, eps_floor);
yhat_proj = max(yhat, eps_floor);
end