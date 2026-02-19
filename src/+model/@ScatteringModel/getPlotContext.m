function C = getPlotContext(obj)
% getPlotContext - build common grid/scene context for plotting routines.
% Includes axis centers and an invalid-grid mask around scatterers.
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
