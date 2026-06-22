%% getPlotContext
% Build common grid/scene context for plotting routines.
%
% This function generates a structured output containing grid coordinates,
% axis centers, and a mask identifying grid cells that overlap with any
% scatterers in the scene. The invalid mask marks cells that intersect with
% scatterer bounding boxes. Two masks are provided:
% invalidMask keeps the conservative half-grid buffer used by diagnostics,
% while plotMask only hides building interiors for smoother CGM rendering.
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
%       .invalidMask    - Conservative mask with half-grid buffer (Ky x Kx)
%       .plotMask       - Building-footprint mask without buffer (Ky x Kx)
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

xL0 = scatterTable(:,1).';
yB0 = scatterTable(:,2).';
xR0 = (scatterTable(:,1)+scatterTable(:,4)).';
yT0 = (scatterTable(:,2)+scatterTable(:,5)).';
inRectPlot = (xg >= xL0) & (xg <= xR0) & (yg >= yB0) & (yg <= yT0);
plotMask = reshape(any(inRectPlot, 2), Ky, Kx);

C = struct();
C.scatterTable = scatterTable;
C.gridSize = gridSize;
C.areaSize = areaSize;
C.Kx = Kx; C.Ky = Ky; C.K = K;
C.xCenters = xCenters;
C.yCenters = yCenters;
C.invalidMask = invalidMask;
C.plotMask = plotMask;
end
