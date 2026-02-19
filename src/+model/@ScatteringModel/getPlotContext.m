%% getPlotContext
% Build common grid/scene context for plotting routines.
%
% This function generates a structured output containing grid coordinates,
% axis centers, and a mask identifying grid cells that overlap with any
% scatterers in the scene. The invalid mask marks cells that intersect with
% scatterer bounding boxes (including a buffer zone of half grid size).
%
% Syntax:
%   C = getPlotContext(obj)
%
% Output:
%   C (struct) - Plot context structure with fields:
%       .scatterTable   - Copy of scene specification scatter table
%       .gridSize       - Grid cell size (scalar)
%       .areaSize       - Total area dimensions [width, height]
%       .Kx             - Number of grid cells in x-direction
%       .Ky             - Number of grid cells in y-direction
%       .K              - Total number of grid cells (Kx * Ky)
%       .xCenters       - X-axis coordinates of grid cell centers (1 x Kx)
%       .yCenters       - Y-axis coordinates of grid cell centers (1 x Ky)
%       .invalidMask    - Boolean mask marking cells overlapping scatterers (Ky x Kx)
%
% Notes:
%   - Grid is centered at origin with cells aligned to gridSize intervals
%   - Invalid mask accounts for scatterer size and applies gridSize/2 buffer
%   - Mask is reshaped to 2D grid coordinates (Ky x Kx)
function C = getPlotContext(obj)
scatterTable = obj.SceneSpec.scatterTable;
gridSize = obj.GridSpec.gridSize;
areaSize = obj.GridSpec.areaSize;

Kx = floor(areaSize(1) / gridSize);
Ky = floor(areaSize(2) / gridSize);
K  = Kx * Ky;

xCenters = (-areaSize(1)/2 + gridSize/2) : gridSize : (areaSize(1)/2 - gridSize/2);
yCenters = (-areaSize(2)/2 + gridSize/2) : gridSize : (areaSize(2)/2 - gridSize/2);

[iy, ix] = ndgrid(1:Ky, 1:Kx);
x = xCenters(ix); y = yCenters(iy);

xL = scatterTable(:,1).' - gridSize/2;
yB = scatterTable(:,2).' - gridSize/2;
xR = (scatterTable(:,1)+scatterTable(:,4)).' + gridSize/2;
yT = (scatterTable(:,2)+scatterTable(:,5)).' + gridSize/2;

xg = x(:); yg = y(:);
inRect = (xg >= xL) & (xg <= xR) & (yg >= yB) & (yg <= yT);
inAny  = any(inRect, 2);
invalidMask = reshape(inAny, Ky, Kx);

C = struct();
C.scatterTable = scatterTable;
C.gridSize = gridSize;
C.areaSize = areaSize;
C.Kx = Kx; C.Ky = Ky; C.K = K;
C.xCenters = xCenters;
C.yCenters = yCenters;
C.invalidMask = invalidMask;
end
