function [Geometry, Scattering] = TypesSector(obj, pairsTR)
% TypesSector - build geometry weights and one-hot angular features
%
% Outputs:
%   Geometry   : [M x (1+Ns)]  col1=LOS, col(2..)=scatterers  (w >= 0)
%   Scattering : [M x ((1+Ns)*Kfeat)]  block layout:
%                [Phi_LOS, Phi_1, ..., Phi_Ns], each Phi_* is one-hot over Kfeat
% -------------------- parse opt --------------------
Mcent = obj.NumCenters;          % number of angle bins
alpha = obj.PathLossExp;         % path loss exponent
d0    = obj.RefDistance;         % reference distance
epsd  = obj.EpsDist;             % distance epsilon

Mobs = size(pairsTR, 1);
Ns   = size(obj.SceneSpec.scatterTable, 1);
Kfeat = Mcent*Mcent;
binW = 2*pi / Mcent;

omega2bin = @(om) 1 + min(Mcent-1, floor(om / binW )); % omega -> bin index in {1,...,Mcent}
clipBin  = @(b) min(max(b,1), Mcent); % Guard against om == pi after wrap (should be < pi, but numeric issues happen)

% idxUpper(p,q) = k, where 1<=p<=q<=Mcent and k in {1,...,Kfeat}
% idxUpper = zeros(Mcent, Mcent, 'uint32');
% maskU = triu(true(Mcent));
% idxUpper(maskU) = uint32(1:Kfeat);

% -------------------- create geometry --------------------
Geometry   = zeros(Mobs, Ns+1, 'double');
Scattering = zeros(Mobs, (Ns+1)*Kfeat, 'double');  % dense to support reshape in predict
for i = 1:Mobs
    txIdx = pairsTR(i,1);
    rxIdx = pairsTR(i,2);

    [geomInfo, losInfo] = obj.computeGeometry(txIdx, rxIdx);

    % ---------- NLoS geometry ----------
    vis_tx = logical([geomInfo.visibility_tx]).';
    vis_rx = logical([geomInfo.visibility_rx]).';
    d_tx   = max([geomInfo.dist_tx].', epsd);
    d_rx   = max([geomInfo.dist_rx].', epsd);
    om_in  = [geomInfo.omega_in].';
    om_out = [geomInfo.omega_out].';

    g_tx = (d0 ./ d_tx).^alpha;
    g_rx = (d0 ./ d_rx).^alpha;
    w_nlos = (vis_tx & vis_rx) .* (g_tx .* g_rx);     % [Ns x 1], >=0

    % ---------- LOS geometry ----------
    vis_los = logical(losInfo.visibility);
    d_los   = max(double(losInfo.dist), epsd);
    g_los   = (d0 ./ d_los).^alpha;
    w_los   = double(vis_los) * double(g_los);

    Geometry(i,1) = w_los;
    Geometry(i,2:end) = w_nlos(:).';

    % ---------- LOS one-hot block ----------
    om_los_in  = double(losInfo.omega);
    om_los_out = mod(double(losInfo.omega) + pi, 2*pi);

    b_in  = clipBin(omega2bin(om_los_in));
    b_out = clipBin(omega2bin(om_los_out));

    k_los = (b_in-1)*Mcent + b_out;           % uint32 in [1..Kfeat]
    Scattering(i, double(k_los)) = 1.0;

    % ---------- NLoS one-hot blocks (vectorized index computation) ----------
    b_in  = clipBin(omega2bin(om_in));
    b_out = clipBin(omega2bin(om_out));
    
    % k_nlos: [Ns x 1], each in 1..Kfeat
    % Use linear indexing on the numeric idxUpper (safe and fast)
    k_nlos = (b_in-1)*Mcent + b_out;   % uint32
    
    cols = double(Kfeat) + (0:Ns-1)*double(Kfeat) + double(k_nlos(:)).';
    Scattering(i, cols) = 1.0;
end
end
