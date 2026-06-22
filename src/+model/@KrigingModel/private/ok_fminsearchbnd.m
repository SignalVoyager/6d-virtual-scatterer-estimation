% ok_fminsearchbnd - Bounded optimization via variable transform + fminsearch.
%
% SYNTAX:
%   x = ok_fminsearchbnd(fun, x0, lb, ub)
%
% INPUTS:
%   fun - objective function handle, called as fun(x).
%   x0  - initial parameter vector.
%   lb  - lower bounds (same size as x0, use -Inf if none).
%   ub  - upper bounds (same size as x0, use +Inf if none).
%
% OUTPUT:
%   x   - optimized parameter vector in original constrained space.
%
% NOTES:
%   - Uses fminsearch in an unconstrained surrogate space y.
%   - Bound handling by transform:
%       finite [lb,ub]   : logit/sigmoid map
%       lower-bounded    : x = lb + exp(y)
%       upper-bounded    : x = ub - exp(y)
%       unbounded        : identity
%   - This lightweight helper returns only x (no solver diagnostics).
%
% This is a lightweight special-case optimizer wrapper to avoid dependencies.
% It transforms bounded variables into unconstrained space and calls fminsearch.
function x = ok_fminsearchbnd(fun, x0, lb, ub)
x0 = double(x0(:));
lb = double(lb(:));
ub = double(ub(:));
assert(numel(x0)==numel(lb) && numel(x0)==numel(ub), "Dimension mismatch.");

% Transform initial guess x (bounded space) into y (unbounded space).
y0 = x2y(x0);

% Optimize in y-space while evaluating the original objective in x-space.
opts = optimset('Display','off','MaxIter',400,'MaxFunEvals',2000);
y = fminsearch(@(yy) fun(y2x(yy)), y0, opts);

% Map optimized y back to bounded x-space.
x = y2x(y);

function y = x2y(x)
    % x -> y transform for fminsearch (unconstrained domain).
    y = zeros(size(x));
    for k = 1:numel(x)
        if isfinite(lb(k)) && isfinite(ub(k))
            % two-sided bound: x in [lb,ub] -> t in (0,1) -> y in R via logit
            t = (x(k)-lb(k)) / max(ub(k)-lb(k), 1e-12);
            t = min(max(t, 1e-9), 1-1e-9);
            y(k) = log(t/(1-t));
        elseif isfinite(lb(k)) && ~isfinite(ub(k))
            % lower-bound only: x = lb + exp(y)
            y(k) = log(max(x(k)-lb(k), 1e-12));
        elseif ~isfinite(lb(k)) && isfinite(ub(k))
            % upper-bound only: x = ub - exp(y)
            y(k) = log(max(ub(k)-x(k), 1e-12));
        else
            % unbounded: identity
            y(k) = x(k);
        end
    end
end

function x = y2x(y)
    % y -> x inverse transform to enforce bounds.
    x = zeros(size(y));
    for k = 1:numel(y)
        if isfinite(lb(k)) && isfinite(ub(k))
            % inverse of logit mapping.
            t = 1/(1+exp(-y(k)));
            x(k) = lb(k) + (ub(k)-lb(k))*t;
        elseif isfinite(lb(k)) && ~isfinite(ub(k))
            x(k) = lb(k) + exp(y(k));
        elseif ~isfinite(lb(k)) && isfinite(ub(k))
            x(k) = ub(k) - exp(y(k));
        else
            x(k) = y(k);
        end
    end
end
end
