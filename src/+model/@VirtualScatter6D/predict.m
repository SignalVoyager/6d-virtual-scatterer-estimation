% PREDICT Compute gains and path contributions for virtual scatterers
%
% SYNTAX:
%   [gain_sum, gain_path, gamma_path] = predict(obj, pairsTR)
%
% DESCRIPTION:
%   Predicts the total gain and per-path gains for transmitter-receiver pairs
%   using the trained virtual scatterer model. Computes path-specific gamma
%   values (basis feature coefficients) and combines them with geometry weights
%   to obtain final gains for each scattering path including line-of-sight.
%
% INPUTS:
%   obj      - VirtualScatter6D model object with trained scatterInfo
%   pairsTR  - [Npairs x 2] array of transmitter-receiver pair indices
%
% OUTPUTS:
%   gain_sum   - [Npairs x 1] total gain summed across all paths (LOS + scatterers)
%   gain_path  - [Npairs x (Ns+1)] per-path gains where columns represent
%                LOS path and individual scatterer contributions
%   gamma_path - [Npairs x (Ns+1)] basis feature coefficient values per path
%
% NOTES:
%   - Requires obj.scatterInfo to be populated via train() method
%   - Processes Ns scatterers (not counting LOS path)
%   - Uses geometry weights and basis features from TypesSector()
%   - Computation vectorized using reshape and permute operations
%
% ERROR HANDLING:
%   - Error if scatterInfo is empty (model not trained)
%   - Error if pairsTR is empty or not [Npairs x 2] dimensioned
function [gain_sum, gain_path, gamma_path] = predict(obj, pairsTR)
if isempty(obj.scatterInfo)
    error('[VirtualScatter6D.predict] scatterInfo is empty. Call train() first.');
end
if isempty(pairsTR) || size(pairsTR,2) ~= 2
    error('[VirtualScatter6D.predict] pairsTR must be [Npairs x 2].');
end

Ns = size(obj.SceneSpec.scatterTable, 1);
Mcent = obj.NumCenters;
Kfeat = Mcent*Mcent;
Mobs = size(pairsTR,1);

% ---- get geometry weights and basis features ----------------
% W:   [Npairs x (Ns+1)]
% Phi: [Npairs x ((Ns+1)*Kfeat)]  blocks = [LOS | S1 | ... | SNs]
[Geometry, Scattering] = obj.TypesSector(pairsTR);

% ---------------- compute per-path gamma and gains ----------------
% gamma per path: gamma_path(i,p) = Phi_block(i,p,:) * beta_p
% Vectorized via reshaping:
beta_mat = reshape(obj.scatterInfo.beta_all, Kfeat, (Ns+1)); % [Kfeat x (Ns+1)]
Phi3 = reshape(Scattering.', Kfeat, (Ns+1), Mobs); % [Kfeat x (Ns+1) x Mobs]
Phi3 = permute(Phi3, [3 2 1]); % [Mobs x (Ns+1) x Kfeat]

% Multiply along Kfeat:
% gamma_path = sum_k Phi3(:,:,k) * Beta2(k,:)  (broadcast)
gamma_path = sum(Phi3 .* permute(beta_mat, [3 2 1]), 3);
gamma_path = reshape(gamma_path, Mobs, Ns+1);
% Per-path gain: gain_path = W .* gamma_path
gain_path = Geometry .* gamma_path; % [Mobs x (Ns+1)]
% Total gain:
gain_sum  = sum(gain_path, 2); % [Mobs x 1]
end

