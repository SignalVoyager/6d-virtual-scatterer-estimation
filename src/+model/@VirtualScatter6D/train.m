function train(obj, varargin)
% train - fit the model parameters and update obj.scatterInfo
%
% Optional name-value:
%   "mode" : "fit"|"save"|"load" (default "fit")
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
Kfeat = Mcent*Mcent;
% ---------------- parse options ----------------
[Geometry, Scattering] = obj.TypesSector(trainSet(:,1:2));
A = Scattering .* repelem(Geometry, 1, Kfeat);
y = trainSet(:,3);

% Phi_LoS  = Phi(:, 1:Kfeat);                 % [Mobs x Kfeat]
% Phi_NLoS = Phi(:, Kfeat+1:end);             % [Mobs x (Ns*Kfeat)]
% A_LoS = Phi_LoS .* W(:,1);                  % 隐式扩展: [Mobs x Kfeat]
% A_NLoS = Phi_NLoS .* repelem(W(:,2:end), 1, Kfeat);   % [Mobs x (Ns*Kfeat)]
% A = [A_LoS, A_NLoS];

fprintf('[VirtualScatter6D.train] Solving NNLS...\n');
% ---------- (0) 数值稳定性缩放 ----------
s = rms(y); A_w = A / s; y_w = y / s;
% ---------- (1) 求解 ----------
switch obj.Solver
    case "LS-Ridge"
        AtA = A_w.' * A_w;
        Aty = A_w.' * y_w;
        lambda = 1e-8 * trace(AtA) / size(AtA,1);
        beta = (AtA + lambda * speye(size(AtA,1))) \ Aty;   % beta in scaled system
    case "LS"
        beta=A_w\y_w;
    case "NNLS"
        beta = lsqnonneg(A_w, y_w); 
    otherwise
        error("We do not have such solver.");
end

% beta_post = beta;                % 复制一份，避免污染原beta（可选）
% for n = 0:Ns
%     idx = n*Kfeat + (1:Kfeat);   % 物理散射体n的beta段（与你现有切片一致）
%     Gamma = reshape(beta_post(idx), Mcent, Mcent);    % 默认列向量化：Gamma(:)
% 
%     Gamma_sym = 0.5 * (Gamma + Gamma.');      % 互易性：对称化
%     beta_post(idx) = Gamma_sym(:);            % 写回
% end
% beta = beta_post;    

% ---------------- write scatterInfo ----------------  
scatterers = repmat(struct('id',[], 'sourceType',"", 'beta',[]), 1, Ns+1);
scatterers(1).id = 0; scatterers(1).sourceType = "tx"; scatterers(1).beta = beta(1:Kfeat);

% scatterer #1..Ns: physical scatterers / NLoS
for n = 1:Ns
    scatterers(n+1).id = n;
    scatterers(n+1).sourceType = "physical";
    scatterers(n+1).beta = beta(Kfeat + (n-1)*Kfeat + (1:Kfeat));
end

obj.scatterInfo = struct( ...
    'scatterers', scatterers, ...
    'beta_all',   beta(:) ...
);

if mode == "save"
    obj.saveModel();
end
end