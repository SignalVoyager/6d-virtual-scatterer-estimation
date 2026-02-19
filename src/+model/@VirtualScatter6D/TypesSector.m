% TypesSector - Build geometry weights and one-hot angular features for virtual scatterers
%
% This function computes geometry-based weights and angular feature encodings for
% line-of-sight (LOS) and non-line-of-sight (NLoS) propagation paths in a 6D virtual
% scatterer estimation model.
%
% SYNTAX:
%   [Geometry, Scattering] = TypesSector(obj, pairsTR)
%
% INPUTS:
%   obj       : VirtualScatter6D object
%               Properties used:
%               - NumCenters (Mcent)     : Number of angular bins
%               - PathLossExp (alpha)    : Path loss exponent
%               - RefDistance (d0)       : Reference distance for path loss
%               - EpsDist (epsd)         : Distance epsilon for numerical stability
%               - SceneSpec.scatterTable : Table of scatterer positions [Ns x ...]
%
%   pairsTR   : [M x 2] indices of transmitter-receiver pairs
%               pairsTR(i,1) = transmitter index
%               pairsTR(i,2) = receiver index
%
% OUTPUTS:
%   Geometry   : [M x (1+Ns)] double
%               Column 1: LOS path geometric weight w_los >= 0
%               Columns 2 to (1+Ns): NLoS geometric weights for each scatterer
%               Weights incorporate path loss and visibility
%
%   Scattering : [M x ((1+Ns)*Kfeat)] double
%               Block-wise layout: [Phi_LOS, Phi_1, ..., Phi_Ns]
%               Each Phi_* is one-hot encoding over Kfeat = Mcent^2 angular features
%               Encodes incoming and outgoing angles as 2D bin indices
%
% ALGORITHM:
%   For each TX-RX pair:
%   1. Compute geometry (distances, angles, visibility) via computeGeometry()
%   2. Calculate path loss weights using distance and alpha exponent
%   3. Mask weights by visibility constraints
%   4. Encode LOS and NLoS angles as one-hot vectors over 2D angular grid
%   5. Place one-hot vectors in block-diagonal structure of Scattering matrix
%
% NOTES:
%   - Kfeat = Mcent^2 (2D angular discretization: Mcent bins for incoming,
%     Mcent bins for outgoing angle)
%   - Angular wrapping: incoming angles in [0, 2π), outgoing = (incoming + π) mod 2π
%   - Distances clipped to minimum epsd to prevent numerical issues
%   - One-hot encoding uses linear indexing: k = (b_in-1)*Mcent + b_out
function [Geometry, Scattering] = TypesSector(obj, pairsTR)
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
    w_nlos = (vis_tx & vis_rx) .* (g_tx .* g_rx); % [Ns x 1]

    % ---------- LOS geometry ----------
    vis_los = logical(losInfo.visibility);
    d_los   = max(double(losInfo.dist), epsd);
    g_los   = (d0 ./ d_los).^alpha;
    w_los   = double(vis_los) * double(g_los);

    Geometry(i,1)     = w_los;
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
    
    k_nlos = (b_in-1)*Mcent + b_out;   % [Ns x 1], each in 1..Kfeat
    
    cols = double(Kfeat) + (0:Ns-1)*double(Kfeat) + double(k_nlos(:)).';
    Scattering(i, cols) = 1.0;
end
end
