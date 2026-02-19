function [gain_sum, gain_path, gamma_path] = predict(obj, pairsTR)
% predict - predict linear power gain (mW) for TX/RX grid pairs
if isempty(obj.scatterInfo)
    error('[predict] scatterInfo is empty. Call train() first.');
end
if isempty(pairsTR) || size(pairsTR,2) ~= 2
    error('[predict] pairsTR must be [Npairs x 2].');
end

% Ns scatterers (not counting LOS)
Mobs = size(pairsTR,1);
Ns = size(obj.SceneSpec.scatterTable, 1);
Mcent = obj.NumCenters;
Kfeat = Mcent*Mcent;

% ---------------- get geometry weights and basis features ----------------
% W:   [Npairs x (Ns+1)]
% Phi: [Npairs x ((Ns+1)*Kfeat)]  blocks = [LOS | S1 | ... | SNs]
[Geometry, Scattering] = obj.TypesSector(pairsTR);

% ---------------- compute per-path gamma and gains ----------------
% gamma per path: gamma_path(i,p) = Phi_block(i,p,:) * beta_p
% Vectorized via reshaping:
beta_mat = reshape(obj.scatterInfo.beta_all, Kfeat, (Ns+1));
Phi3 = reshape(Scattering.', Kfeat, (Ns+1), Mobs);
Phi3 = permute(Phi3, [3 2 1]);

% % Multiply along Kfeat:
% % gamma_path = sum_k Phi3(:,:,k) * Beta2(k,:)  (broadcast)
gamma_path = sum(Phi3 .* permute(beta_mat, [3 2 1]), 3);
gamma_path = reshape(gamma_path, Mobs, Ns+1);
% % Per-path gain: gain_path = W .* gamma_path
gain_path = Geometry .* gamma_path;          % [Mobs x (Ns+1)]
% % Total gain:
gain_sum  = sum(gain_path, 2);        % [Mobs x 1]
end

