function [x, y] = rxIdxToXY(obj, rxIdx)
% Map linear rxIdx into grid center coordinates (x,y) in meters.
gridSize = obj.GridSpec.gridSize;
areaSize = obj.GridSpec.areaSize;

Kx = floor(areaSize(1) / gridSize);
Ky = floor(areaSize(2) / gridSize);

[ry, rx] = ind2sub([Ky, Kx], rxIdx);
xCenters = (-areaSize(1)/2 + gridSize/2) + gridSize*(rx-1);
yCenters = (-areaSize(2)/2 + gridSize/2) + gridSize*(ry-1);

x = xCenters(:);
y = yCenters(:);
end