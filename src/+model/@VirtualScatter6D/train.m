%% TRAIN Trains the 6D virtual scatterer model using regression
%
% SYNTAX:
%   train(obj)
%   train(obj, Name=Value)
%
% DESCRIPTION:
%   Trains the virtual scatterer model by solving a least-squares regression problem
%   to estimate scattering coefficients (beta) from raytracing data. Supports multiple
%   solvers (LS, LS-Ridge, NNLS, LS-Ridge-Old) and can load/save trained models.
%
% INPUT ARGUMENTS:
%   obj       - VirtualScatter6D object to train
%
% NAME-VALUE PARAMETERS:
%   mode      - (string) Operation mode: "fit" (default), "load", or "save"
%               • "fit"  - Train the model on raytracing data
%               • "load" - Load pre-trained model from disk
%               • "save" - Save trained model to disk
%
% ALGORITHM:
%   1. Parses input parameters and checks for model loading
%   2. Extracts training data from raytracing results
%   3. Constructs design matrix A by combining geometry and scattering features
%   4. Applies numerical scaling (RMS normalization) for stability
%   5. Solves regularized least-squares regression using specified solver:
%      • LS-Ridge: Ridge regression with automatic lambda selection
%      • LS: Standard least-squares (backslash operator)
%      • NNLS: Non-negative least-squares
%   6. Organizes estimated beta coefficients into scatterer structures
%   7. Saves model if mode="save"
%
% OUTPUT:
%   Updates obj.scatterInfo with:
%   • scatterers - Array of structures containing id, sourceType, and beta coefficients
%   • beta_all   - Complete coefficient vector for all scatterers
%
% REMARKS:
%   - Supports both LoS (transmitter) and NLoS (physical) scatterers
%   - Commented code includes reciprocity enforcement (symmetrization)
%   - Numerical scaling improves solver conditioning for ill-posed problems
%
% SEE ALSO:
%   loadModel, saveModel, TypesSector
function train(obj, varargin)
p = inputParser;
p.addParameter("mode", "fit");
p.parse(varargin{:});
mode = lower(string(p.Results.mode));

if mode == "load"
    obj.loadModel();
    return;
end

trainSet = obj.raytracingResults.trainSet;
Ns = size(obj.SceneSpec.scatterTable, 1);
Mcent = obj.NumCenters;
Kfeat = Mcent*Mcent; % physical-scatterer feature count

fprintf('[VirtualScatter6D.train] Training with %d samples, %d scatterers, %d features per physical scatterer\n', size(trainSet,1), Ns, Kfeat);

pairsTR = trainSet(:,1:2);
y = trainSet(:,3);

[Geometry, Scattering] = obj.TypesSector(pairsTR);

% Parameterization:
% - TX (LOS) path: single scalar (no sector x sector expansion)
% - Physical scatterers: Kfeat=(Mcent^2) sectors per scatterer
PhiSc = Scattering(:, Kfeat+1:end);                    % [Mobs x Ns*Kfeat]
A_tx = Geometry(:,1);                                  % [Mobs x 1]
A_sc = PhiSc .* repelem(Geometry(:,2:end), 1, Kfeat); % [Mobs x Ns*Kfeat]
A = [A_tx, A_sc];                                      % [Mobs x (1+Ns*Kfeat)]

% ---- numeric scaling ----
s = rms(y); 
if s <= 0 || ~isfinite(s), s = 1.0; end
A_w = A / s; y_w = y / s;

% ---- solve ----
switch obj.Solver
    case "LS-Ridge"
        % Stable ridge via augmented least squares.
        % Keep TX scalar (first coefficient) unregularized.
        pdim = size(A_w, 2);
        AtA = A_w.' * A_w;
        lambda = max(1e-10, 1e-4 * trace(AtA) / max(pdim,1));
        regW = ones(pdim,1);
        regW(1) = 0;
        L = spdiags(sqrt(lambda) * regW, 0, pdim, pdim);
        beta = [A_w; L] \ [y_w; zeros(pdim,1)];
    case "LS-Ridge-Old"
        AtA = A_w.' * A_w;
        Aty = A_w.' * y_w;
        lambda = 1e-8 * trace(AtA) / max(size(AtA,1),1);
        beta = (AtA + lambda * speye(size(AtA,1))) \ Aty;
    case "LS"
        beta = A_w \ y_w;
    case "NNLS"
        beta = lsqnonneg(A_w, y_w); 
    otherwise
        error('[VirtualScatter6D.train] Unknown solver: %s', obj.Solver);
end

% ---- pack scatterers ----
scatterers = repmat(struct('id',[], 'sourceType',"", 'beta',[]), 1, Ns+1);
scatterers(1).id = 0; scatterers(1).sourceType = "tx"; scatterers(1).beta = beta(1);
for n = 1:Ns
    scatterers(n+1).id = n;
    scatterers(n+1).sourceType = "physical";
    scatterers(n+1).beta = beta(1 + (n-1)*Kfeat + (1:Kfeat));
end

obj.scatterInfo = struct( ...
    'scatterers', scatterers, ...
    'beta_all',   beta(:), ...
    'meta', struct('NumCenters',Mcent,'KfeatTx',1,'KfeatSc',Kfeat,'Ns',Ns,'Solver',obj.Solver) ...
);

if mode == "save"
    obj.saveModel();
end
end
