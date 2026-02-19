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