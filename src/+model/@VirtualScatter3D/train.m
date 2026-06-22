% TRAIN Trains the 3D virtual scatterer model using raytracing results
%
% SYNTAX:
%   train(obj)
%   train(obj, Name, Value)
%
% DESCRIPTION:
%   Performs per-transmitter training of the virtual scatterer model using
%   least squares regression. The method fits coefficients for transmitter
%   and physical scatterer contributions to match observed raytracing data.
%
% INPUT PARAMETERS:
%   obj          - VirtualScatter3D object
%   mode         - (Name-Value) Training mode, one of:
%                  "fit"   - Train and store model in memory (default)
%                  "load"  - Load previously trained model from disk
%                  "save"  - Train and save model to disk
%
% ALGORITHM:
%   For each unique transmitter in the training set:
%   1. Extract TX-specific training pairs (TX-RX indices and observations)
%   2. Construct geometry and scattering matrices
%   3. Normalize by RMS of observations
%   4. Solve regularized least squares problem using specified solver
%   5. Pack computed coefficients into per-scatterer structure
%
% SOLVER OPTIONS:
%   "LS-Ridge" - Ridge regression with automatic lambda scaling
%   "LS-Ridge-Old" - Ridge regression with fixed lambda (legacy)
%   "LS"       - Standard least squares (backslash operator)
%   "NNLS"     - Non-negative least squares
%
% OUTPUT:
%   Populates obj.scatterInfo with:
%   - txModels: Array of per-TX training results with coefficients
%   - meta:     Metadata (number of centers, features, scatterers, solver)
%
% NOTES:
%   - Requires obj.raytracingResults.trainSet to be populated
%   - SceneSpec.scatterTable must contain physical scatterer definitions
%   - Output metrics printed to console for each TX
%
% SEE ALSO:
%   loadModel, saveModel, TypesSectorTx
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
Ns    = size(obj.SceneSpec.scatterTable, 1);
Mcent = obj.NumCenters;
Kfeat = Mcent; % 3D baseline: omega_out only (for physical scatterers)

txList = unique(trainSet(:,1), 'stable');
txModels = repmat(struct('txIdx',[], 'beta_all',[], 'scatterers',[]), numel(txList), 1);

fprintf('[VirtualScatter3D.train] Per-TX training: %d TX(s)\n', numel(txList));

for k = 1:numel(txList)
    txIdx = txList(k);
    subSet = trainSet((trainSet(:,1) == txIdx),:);

    pairsTR = subSet(:,1:2);
    y       = subSet(:,3);

    [Geometry, Scattering] = obj.TypesSectorTx(pairsTR);

    % Parameterization:
    % - TX (LOS) path: single scalar (no sector expansion)
    % - Physical scatterers: Kfeat sectors per scatterer
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
            error('[VirtualScatter3D.train] Unknown solver: %s', obj.Solver);
    end

    % ---- pack scatterers (optional convenience, matches 6D style) ----
    scatterers = repmat(struct('id',[], 'sourceType',"", 'beta',[]), 1, Ns+1);
    scatterers(1).id = 0; scatterers(1).sourceType = "tx"; scatterers(1).beta = beta(1);
    for n = 1:Ns
        scatterers(n+1).id = n;
        scatterers(n+1).sourceType = "physical";
        scatterers(n+1).beta = beta(1 + (n-1)*Kfeat + (1:Kfeat));
    end

    txModels(k).txIdx      = txIdx;
    txModels(k).beta_all   = beta(:);
    txModels(k).scatterers = scatterers;

    fprintf('[VirtualScatter3D.train] TX=%d: obs=%d, betaDim=%d\n', txIdx, size(subSet,1), numel(beta));
end

obj.scatterInfo = struct( ...
    'txModels', txModels, ...
    'meta', struct( ...
        'NumCenters',Mcent, ...
        'KfeatTx',1, ...
        'KfeatSc',Kfeat, ...
        'Ns',Ns, ...
        'Solver',obj.Solver));

if mode == "save"
    obj.saveModel();
end
end
