% TypesSectorTx  Compute geometry and scattering features for sector-based TX beamforming
%
%   [Geometry, Scattering] = TypesSectorTx(obj, pairsTR)
%
%   This method computes geometric path loss and one-hot encoded scattering
%   features for a set of TX-RX receiver pairs in a 6D virtual scatterer model.
%   It quantizes azimuth angles into discrete sector bins and produces:
%   - A geometry matrix capturing LOS and NLoS path loss weights
%   - A scattering matrix with one-hot encoded angle-of-arrival bins
%
%   INPUTS:
%       obj             - VirtualScatter3D model object
%       pairsTR         - [Mobs x 2] array of [txIdx, rxIdx] pairs
%
%   OUTPUTS:
%       Geometry        - [Mobs x (Ns+1)] matrix of path loss gains
%                         Column 1: LOS path gain
%                         Columns 2:end: NLoS path gains to Ns scatterers
%
%       Scattering      - [Mobs x (Ns+1)*Kfeat] sparse one-hot matrix
%                         Each row encodes azimuth sector bins for LOS and NLoS paths
%                         Kfeat = number of angle bins (Mcent)
%
%   DETAILS:
%       - Azimuth angles ω ∈ [0,2π) are quantized into Mcent bins
%       - Path loss follows (d0/d)^α model with reference distance d0
%       - NLoS paths require mutual visibility (TX→scatterer→RX)
%       - Distance floor (epsd) prevents division by zero
%       - Angle wrapping and numeric clipping ensure valid bin indices
%
%   SEE ALSO: computeGeometry
function [Geometry, Scattering] = TypesSectorTx(obj, pairsTR)
Mcent = obj.NumCenters;          % number of angle bins
alpha = obj.PathLossExp;         % path loss exponent
d0    = obj.RefDistance;         % reference distance
epsd  = obj.EpsDist;             % distance epsilon

Mobs  = size(pairsTR, 1);
Ns    = size(obj.SceneSpec.scatterTable, 1);
Kfeat = Mcent;
binW  = 2*pi / Mcent;

omega2bin = @(om) 1 + min(Mcent-1, floor(om / binW )); % omega -> bin index in {1,...,Mcent}
clipBin  = @(b) min(max(b,1), Mcent); % Guard against om == pi after wrap (should be < pi, but numeric issues happen)

Geometry   = zeros(Mobs, Ns+1, 'double');
Scattering = zeros(Mobs, (Ns+1)*Kfeat, 'double'); % dense for reshape math

for i = 1:Mobs
    txIdx = pairsTR(i,1);
    rxIdx = pairsTR(i,2);

    [geomInfo, losInfo] = obj.computeGeometry(txIdx, rxIdx);

    % -------- NLoS geometry --------
    vis_tx = logical([geomInfo.visibility_tx]).';
    vis_rx = logical([geomInfo.visibility_rx]).';
    d_tx   = max([geomInfo.dist_tx].', epsd);
    d_rx   = max([geomInfo.dist_rx].', epsd);
    om_out = [geomInfo.omega_out].';

    g_tx = (d0 ./ d_tx).^alpha;
    g_rx = (d0 ./ d_rx).^alpha;
    w_nlos = (vis_tx & vis_rx) .* (g_tx .* g_rx);  % [Ns x 1]

    % -------- LOS geometry --------
    vis_los = logical(losInfo.visibility);
    d_los   = max(double(losInfo.dist), epsd);
    g_los   = (d0 ./ d_los).^alpha;
    w_los   = double(vis_los) * double(g_los);

    Geometry(i,1)     = w_los;
    Geometry(i,2:end) = w_nlos(:).';

    % -------- LOS one-hot on omega (TX->RX) --------
    om_los = double(losInfo.omega);            % already wrapped by base computeGeometry
    b = clipBin(omega2bin(om_los));
    Scattering(i, double(b)) = 1.0;

    % -------- NLoS one-hot blocks on omega_out (scatterer->RX) --------
    b_out = clipBin(omega2bin(om_out));        % [Ns x 1], in 1..Mcent
    cols = double(Kfeat) + (0:Ns-1)*double(Kfeat) + double(b_out(:)).';
    Scattering(i, cols) = 1.0;
end
end
