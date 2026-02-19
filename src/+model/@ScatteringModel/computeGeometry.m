% COMPUTEGEOMETRY Computes geometric and line-of-sight information for scattering paths
%
% SYNTAX:
%   [geomInfo, losInfo] = computeGeometry(obj, tx_idx, rx_idx)
%
% DESCRIPTION:
%   Calculates 3D geometric parameters for all virtual scatterers relative to 
%   transmitter (TX) and receiver (RX) positions, including distances, angles, 
%   and visibility information. Also computes direct TX-RX line-of-sight path.
%
% INPUT ARGUMENTS:
%   obj      - ScatteringModel object containing scene and grid specifications
%   tx_idx   - Linear index of transmitter position in grid [scalar]
%   rx_idx   - Linear index of receiver position in grid [scalar]
%
% OUTPUT ARGUMENTS:
%   geomInfo - Structure array [N x 1] containing geometric info for each scatterer:
%       .position      - Scatterer 3D position [x, y, z] [1 x 3]
%       .dist_tx       - 3D distance from TX to scatterer [scalar]
%       .dist_rx       - 3D distance from scatterer to RX [scalar]
%       .visibility_tx - Visibility of TX->scatterer path [logical]
%       .visibility_rx - Visibility of scatterer->RX path [logical]
%       .omega_in      - Incident angle from TX to scatterer [rad, 0 to 2π]
%       .omega_out     - Outgoing angle from scatterer to RX [rad, 0 to 2π]
%
%   losInfo - Structure containing direct TX-RX line-of-sight path information:
%       .position_tx - Transmitter position [x, y, z] [1 x 3]
%       .position_rx - Receiver position [x, y, z] [1 x 3]
%       .dist        - 3D direct distance between TX and RX [scalar]
%       .visibility  - LOS path visibility flag [logical]
%       .omega       - TX to RX direction angle [rad, 0 to 2π]
%
% NOTES:
%   - Scatterer positions are at the center of boxes defined in scatterTable
%   - All angles are in radians, normalized to range [0, 2π]
%   - Visibility computed using 3D segment-obstacle intersection
%   - Grid is centered at origin with TX/RX at fixed height (tx_pos_z, rx_pos_z)
%
% SEE ALSO:
%   segmentVisibility3D, ind2sub, atan2
function [geomInfo, losInfo] = computeGeometry(obj, tx_idx, rx_idx)
% load scene
scatterTable = obj.SceneSpec.scatterTable;
gridSize = obj.GridSpec.gridSize;
areaSize = obj.GridSpec.areaSize;
tx_pos_z = obj.GridSpec.tx_pos_z;
rx_pos_z = obj.GridSpec.rx_pos_z;

% Grid dimensions
Kx = floor(areaSize(1) / gridSize);  % horizontal grid count
Ky = floor(areaSize(2) / gridSize);  % vertical grid count
wrapTo2Pi = @(ang) mod(ang, 2*pi);

% tx positions
[ty, tx] = ind2sub([Ky, Kx], tx_idx);
tx_pos_xy = [ -areaSize(1)/2 + gridSize/2 + gridSize*(tx-1);
              -areaSize(2)/2 + gridSize/2 + gridSize*(ty-1) ];
tx_pos = [tx_pos_xy; tx_pos_z];

% rx positions
[ry, rx] = ind2sub([Ky, Kx], rx_idx);
rx_pos_xy = [ -areaSize(1)/2 + gridSize/2 + gridSize*(rx-1);
              -areaSize(2)/2 + gridSize/2 + gridSize*(ry-1) ];
rx_pos = [rx_pos_xy; rx_pos_z];

% Virtual scatterer position: center of each box (2D)
% scatterTable(:,1:2) = (x,y) bottom-left reference; width along x, depth along y            
s_pos = scatterTable(:,1:3) + 0.5 * scatterTable(:,4:6);

% Distances in 3D for TX->scatterer and scatterer->RX
dist_tx_s = sqrt( (s_pos(:,1) - tx_pos(1)).^2 + (s_pos(:,2) - tx_pos(2)).^2 + (s_pos(:,3) - tx_pos(3)).^2 );
dist_rx_s = sqrt( (s_pos(:,1) - rx_pos(1)).^2 + (s_pos(:,2) - rx_pos(2)).^2 + (s_pos(:,3) - rx_pos(3)).^2 );

% 角度：入射(从tx指向s)，出射(从s指向rx)，范围[-pi, pi]
omegaIn_tx_s  = wrapTo2Pi(atan2( s_pos(:,2) - tx_pos(2), s_pos(:,1) - tx_pos(1) ));      % [N x 1]
omegaOut_tx_s = wrapTo2Pi(atan2( rx_pos(2) - s_pos(:,2), rx_pos(1) - s_pos(:,1) ));      % [N x 1]

% visibility_tx_s = segmentVisibility2D(tx_pos(:).', s_pos, scatterTable,"nlos",1e-3 * gridSize);  % s_pos [N x 2]
% visibility_rx_s = segmentVisibility2D(s_pos, rx_pos(:).', scatterTable,"nlos",1e-3 * gridSize);
visibility_tx_s = segmentVisibility3D(tx_pos(:).', s_pos, scatterTable, "nlos", 1e-3 * gridSize);
visibility_rx_s = segmentVisibility3D(s_pos, rx_pos(:).', scatterTable, "nlos", 1e-3 * gridSize);

geomInfo = struct( ...
    'position',      num2cell(s_pos, 2), ...
    'dist_tx',       num2cell(dist_tx_s), ...
    'dist_rx',       num2cell(dist_rx_s), ...
    'visibility_tx', num2cell(visibility_tx_s), ...
    'visibility_rx', num2cell(visibility_rx_s), ...
    'omega_in',      num2cell(omegaIn_tx_s), ...
    'omega_out',     num2cell(omegaOut_tx_s) ...
);

% los_dist = sqrt( (rx_pos(1) - tx_pos(1)).^2 + (rx_pos(2) - tx_pos(2)).^2 );
dist_tx_rx = sqrt( (rx_pos(1)-tx_pos(1)).^2 + (rx_pos(2)-tx_pos(2)).^2 + (rx_pos(3)-tx_pos(3)).^2 );
omega_tx_rx = wrapTo2Pi(atan2(rx_pos(2)-tx_pos(2), rx_pos(1)-tx_pos(1)));   % Tx->Rx 方向角
visibility_tx_rx  = segmentVisibility3D(tx_pos(:).', rx_pos(:).', scatterTable,"los",1e-3 * gridSize);

losInfo = struct( ...
    'position_tx', tx_pos(:).', ...
    'position_rx', rx_pos(:).', ...
    'dist',        dist_tx_rx, ...
    'visibility',  logical(visibility_tx_rx), ...
    'omega',       omega_tx_rx ...
);       
end