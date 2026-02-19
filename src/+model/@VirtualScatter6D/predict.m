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
%   gain_path  - [Npairs x Ns + 1] per-path gains where columns represent
%                LOS path and individual scatterer contributions
%   gamma_path - [Npairs x Ns + 1] basis feature coefficient values per path
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
Kfeat = Mcent*Mcent; % physical-scatterer feature count
Mobs = size(pairsTR,1);

% ---- get geometry weights and basis features ----------------
% W:   [Npairs x (Ns+1)]
% Phi: [Npairs x ((Ns+1)*Kfeat)]  blocks = [LOS | S1 | ... | SNs]
[Geometry, Scattering] = obj.TypesSector(pairsTR);

% ---------------- compute per-path gamma and gains ----------------
beta_all = obj.scatterInfo.beta_all(:);

% - TX path has one scalar gain parameter
% - Each physical scatterer keeps Kfeat angular parameters
beta_tx = beta_all(1);
beta_sc = reshape(beta_all(2:end), Kfeat, Ns); % [Kfeat x Ns]

PhiSc = Scattering(:, Kfeat+1:end);            % [Mobs x Ns*Kfeat]
Phi3s = reshape(PhiSc.', Kfeat, Ns, Mobs);     % [Kfeat x Ns x Mobs]
Phi3s = permute(Phi3s, [3 2 1]);               % [Mobs x Ns x Kfeat]
g_sc = sum(Phi3s .* permute(beta_sc, [3 2 1]), 3); % [Mobs x Ns]

gamma_path = zeros(Mobs, Ns+1);
gamma_path(:,1) = beta_tx;
gamma_path(:,2:end) = g_sc;

% Per-path gain: gain_path = W .* gamma_path
gain_path = Geometry .* gamma_path; % [Mobs x (Ns+1)]
% Total gain:
gain_sum  = sum(gain_path, 2); % [Mobs x 1]
end

