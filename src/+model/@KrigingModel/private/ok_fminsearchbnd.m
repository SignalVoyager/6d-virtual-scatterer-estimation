function x = ok_fminsearchbnd(fun, x0, lb, ub)
% ok_fminsearchbnd - bounded fminsearch via variable transform
%
% This is a lightweight special-case optimizer wrapper to avoid dependencies.
% It transforms bounded variables into unconstrained space and calls fminsearch.

x0 = double(x0(:));
lb = double(lb(:));
ub = double(ub(:));
assert(numel(x0)==numel(lb) && numel(x0)==numel(ub), "Dimension mismatch.");

% transform x in [lb,ub] to y in R
y0 = x2y(x0);

opts = optimset('Display','off','MaxIter',400,'MaxFunEvals',2000);
y = fminsearch(@(yy) fun(y2x(yy)), y0, opts);
x = y2x(y);

function y = x2y(x)
    y = zeros(size(x));
    for k = 1:numel(x)
        if isfinite(lb(k)) && isfinite(ub(k))
            % logistic
            t = (x(k)-lb(k)) / max(ub(k)-lb(k), 1e-12);
            t = min(max(t, 1e-9), 1-1e-9);
            y(k) = log(t/(1-t));
        elseif isfinite(lb(k)) && ~isfinite(ub(k))
            % lower-bounded: x = lb + exp(y)
            y(k) = log(max(x(k)-lb(k), 1e-12));
        elseif ~isfinite(lb(k)) && isfinite(ub(k))
            % upper-bounded: x = ub - exp(y)
            y(k) = log(max(ub(k)-x(k), 1e-12));
        else
            y(k) = x(k);
        end
    end
end

function x = y2x(y)
    x = zeros(size(y));
    for k = 1:numel(y)
        if isfinite(lb(k)) && isfinite(ub(k))
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
