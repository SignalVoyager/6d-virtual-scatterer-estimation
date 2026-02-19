%% expandGridSamples
% Expands selected TX/RX grid indices into dense sub-grid sample points.
%
% SYNTAX:
%   [tx_pos, rx_pos, meta] = expandGridSamples(areaSize, gridSize, tx_z, rx_z, ...
%                                               txIdxList, rxIdxList, Nt_side, Nr_side)
%
% DESCRIPTION:
%   Given a grid of TX and RX positions defined by linear indices, this function
%   expands each grid cell into a dense set of sample points. TX and RX positions
%   are independently sampled within their respective grid cells according to
%   Nt_side and Nr_side parameters. The function returns 3D coordinates with
%   specified heights and metadata describing the sampling structure.
%
% INPUT ARGUMENTS:
%   areaSize      [1x2] double  - Area dimensions [width, height] in meters
%   gridSize      scalar double - Grid cell size in meters
%   tx_z          scalar double - TX height (z-coordinate) in meters
%   rx_z          scalar double - RX height (z-coordinate) in meters
%   txIdxList     [Ntx x 1] double - Linear grid indices for TX positions
%   rxIdxList     [Nrx x 1] double - Linear grid indices for RX positions
%   Nt_side       scalar int    - Number of TX samples per side of grid cell
%   Nr_side       scalar int    - Number of RX samples per side of grid cell
%
% OUTPUT ARGUMENTS:
%   tx_pos        [3 x (Ntx*Ns_tx)] double - TX sample positions [x; y; z]
%   rx_pos        [3 x (Nrx*Ns_rx)] double - RX sample positions [x; y; z]
%   meta          struct - Metadata containing:
%                   .Ntx   - Number of TX grid cells
%                   .Nrx   - Number of RX grid cells
%                   .Ns_tx - Number of samples per TX grid cell (Nt_side^2)
%                   .Ns_rx - Number of samples per RX grid cell (Nr_side^2)
%
% NOTES:
%   - Positions are calculated relative to grid centers
%   - Area origin is centered at (0, 0)
%   - Samples within each grid cell are uniformly distributed
%
% SEE ALSO:
%   ind2sub, meshgrid, kron
function [tx_pos, rx_pos, meta] = expandGridSamples(areaSize,gridSize,tx_z,rx_z, txIdxList, rxIdxList, Nt_side, Nr_side) 
Kx = floor(areaSize(1) / gridSize);  % 横向网格数
Ky = floor(areaSize(2) / gridSize);  % 纵向网格数

txIdxList = txIdxList(:);
rxIdxList = rxIdxList(:);

Ntx = numel(txIdxList);
Nrx = numel(rxIdxList);

% Grid centers
[ty, tx] = ind2sub([Ky, Kx], txIdxList);
txCenter = [ ...
    (-areaSize(1)/2 + gridSize/2) + gridSize * (tx - 1), ...
    (-areaSize(2)/2 + gridSize/2) + gridSize * (ty - 1) ...
];

[ry, rx] = ind2sub([Ky, Kx], rxIdxList); % each is Mr×1
rxCenter = [ ...
    (-areaSize(1)/2 + gridSize/2) + gridSize * (rx - 1), ...
    (-areaSize(2)/2 + gridSize/2) + gridSize * (ry - 1) ...
];

% Offsets inside each grid
rxOffsets = ((1:Nr_side) - (Nr_side+1)/2) * (gridSize/Nr_side);
[dxRx, dyRx] = meshgrid(rxOffsets, rxOffsets);
rxDelta = [dxRx(:), dyRx(:)];     % Ns_rx×2
Ns_rx = size(rxDelta, 1);

txOffsets = ((1:Nt_side) - (Nt_side+1)/2) * (gridSize/Nt_side);
[dxTx, dyTx] = meshgrid(txOffsets, txOffsets);
txDelta = [dxTx(:), dyTx(:)];     % Ns_tx×2
Ns_tx = size(txDelta, 1);

% Pack RX samples: [Nrx*Ns_rx x 2]
txSamples = kron(txCenter, ones(Ns_tx,1)) + repmat(txDelta, Ntx,1);
tx_pos = [txSamples, tx_z*ones(size(txSamples,1),1)].'; % 3 x (Ntx*Ns_tx)

% Pack RX samples: [Nrx*Ns_rx x 2]
rxSamples = kron(rxCenter, ones(Ns_rx,1)) + repmat(rxDelta, Nrx,1);
rx_pos = [rxSamples, rx_z*ones(size(rxSamples,1),1)].'; % 3 x (Nrx*Ns_rx)

meta = struct('Ntx', Ntx, 'Nrx', Nrx, 'Ns_tx', Ns_tx, 'Ns_rx', Ns_rx);
end
        
