% predict - Estimate virtual scatterer gains and path contributions
%
% SYNTAX:
%   [gain_sum, gain_path, gamma_path] = predict(obj, pairsTR)
%
% DESCRIPTION:
%   Predicts the total gain, per-path gains, and per-path gamma values for
%   given transmitter-receiver pairs using trained virtual scatterer models.
%   The prediction is computed by combining geometry weights with learned
%   basis features through linear regression coefficients.
%
% INPUT:
%   obj     - VirtualScatter3D object with trained scatterInfo.txModels
%   pairsTR - [Npairs x 2] array of [txIdx, rxIdx] pairs for prediction
%
% OUTPUT:
%   gain_sum  - [Npairs x 1] total gain per observation pair (sum across all paths)
%   gain_path - [Npairs x (Ns+1)] per-path gains including LOS and Ns scatter paths
%   gamma_path- [Npairs x (Ns+1)] per-path gamma coefficients (basis feature projections)
%
% NOTES:
%   - Requires obj.train() to be called first to populate txModels
%   - Processes pairs grouped by unique transmitter indices for efficiency
%   - Computation uses vectorized matrix operations over feature dimensions
%   - Paths are ordered as [LOS | S1 | S2 | ... | SNs]
%
% ERRORS:
%   - Raises error if scatterInfo.txModels is empty
%   - Raises error if pairsTR is empty or not [Npairs x 2]
%   - Raises error if no trained sub-model exists for a given txIdx
function [gain_sum, gain_path, gamma_path] = predict(obj, pairsTR)
if isempty(obj.scatterInfo) || ~isfield(obj.scatterInfo,'txModels') || isempty(obj.scatterInfo.txModels)
    error('[VirtualScatter3D.predict] scatterInfo.txModels is empty. Call train() first.');
end
if isempty(pairsTR) || size(pairsTR,2) ~= 2
    error('[VirtualScatter3D.predict] pairsTR must be [Npairs x 2].');
end

Ns    = size(obj.SceneSpec.scatterTable, 1);
Mcent = obj.NumCenters;
Kfeat = Mcent;

Mobs = size(pairsTR,1);
gain_sum  = zeros(Mobs,1);
gain_path = zeros(Mobs, Ns+1);
gamma_path= zeros(Mobs, Ns+1);

txIdxAll = pairsTR(:,1);
uniqTx = unique(txIdxAll, 'stable');

% build lookup
txModels = obj.scatterInfo.txModels;

for u = 1:numel(uniqTx)
    txIdx = uniqTx(u);
    mask  = (txIdxAll == txIdx);

    % find model
    j = find([txModels.txIdx] == txIdx, 1, 'first');
    if isempty(j)
        error('[VirtualScatter3D.predict] No trained sub-model for txIdx=%d.', txIdx);
    end

    % ---- get geometry weights and basis features ----------------
    % W:   [Npairs x (Ns+1)]
    % Phi: [Npairs x ((Ns+1)*Kfeat)]  blocks = [LOS | S1 | ... | SNs]
    [Geometry, Scattering] = obj.TypesSectorTx(pairsTR(mask,:));

    % ---------------- compute per-path gamma and gains ----------------
    % gamma per path: gamma_path(i,p) = Phi_block(i,p,:) * beta_p
    % Vectorized via reshaping:
    beta_mat = reshape(txModels(j).beta_all, Kfeat, (Ns+1));                 % [Kfeat x (Ns+1)]
    Phi3 = reshape(Scattering.', Kfeat, (Ns+1), sum(mask));      % [Kfeat x (Ns+1) x Msub]
    Phi3 = permute(Phi3, [3 2 1]);                               % [Msub x (Ns+1) x Kfeat]

    % Multiply along Kfeat:
    % gamma_path = sum_k Phi3(:,:,k) * Beta2(k,:)  (broadcast)
    gpath = sum(Phi3 .* permute(beta_mat, [3 2 1]), 3);          % [Msub x (Ns+1)]
    gpath = reshape(gpath, sum(mask), Ns+1);
    gamma_path(mask,:) = gpath; %[Msub x (Ns+1)]
    % Per-path gain: gain_path = W .* gamma_path
    gain_path(mask,:)  = Geometry .* gpath; % [Msub x (Ns+1)]
    % Total gain:
    gain_sum(mask)     = sum(gain_path(mask,:), 2); % [Msub x 1]
end
end
