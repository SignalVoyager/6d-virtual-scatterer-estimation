function vis = segmentVisibility3D(p0, p1, scatterTable, mode, tol)
% vis = segmentVisibility3D(p0, p1, scatterTable, mode, tol)
% p0, p1: [1x3] or [Nx3]
% scatterTable columns assumed:
%   x = col1, y = col2, width = col4, depth = col5, height = col6, zbase = col7
% mode: "los" or "nlos"
% tol: tolerance on t-interval in XY

% ---- rectangle bounds in XY ----
xL = scatterTable(:,1).';
yB = scatterTable(:,2).';
xR = (scatterTable(:,1) + scatterTable(:,4)).';
yT = (scatterTable(:,2) + scatterTable(:,5)).';

% ---- height bounds ----
zBase = scatterTable(:, 3).';
zTop  = zBase + scatterTable(:, 6).';

% ---- broadcast p0/p1 to Nx3 ----
if size(p0,1)==1 && size(p1,1)>1
    p0 = repmat(p0, size(p1,1), 1);
elseif size(p1,1)==1 && size(p0,1)>1
    p1 = repmat(p1, size(p0,1), 1);
end

P0x = p0(:,1); P0y = p0(:,2); P0z = p0(:,3);
Vx  = p1(:,1) - P0x;
Vy  = p1(:,2) - P0y;
Vz  = p1(:,3) - P0z;

% avoid divide by 0 in XY
epsv = 1e-12;
Vx(abs(Vx)<epsv) = epsv;
Vy(abs(Vy)<epsv) = epsv;

% ---- XY slab intersection -> [N x M] ----
tx1 = (xL - P0x) ./ Vx; tx2 = (xR - P0x) ./ Vx;
tminX = min(tx1, tx2);  tmaxX = max(tx1, tx2);

ty1 = (yB - P0y) ./ Vy; ty2 = (yT - P0y) ./ Vy;
tminY = min(ty1, ty2);  tmaxY = max(ty1, ty2);

tEnter = max(tminX, tminY);
tExit  = min(tmaxX, tmaxY);

% clip to segment parameter
tEnterC = max(tEnter, 0);
tExitC  = min(tExit,  1);

hitXY = (tExitC >= tEnterC + tol);   % [N x M]

% ---- Z test on mid-point of intersection interval ----
tMid = 0.5*(tEnterC + tExitC);         % [N x M]
zMid = P0z + tMid .* Vz;               % [N x M] implicit expansion

hit3D = hitXY & (zMid <= (zTop - tol));  % blocked if ray goes through below top

hitCount = sum(hit3D, 2);

if mode == "nlos"
    vis = (hitCount <= 1);
elseif mode == "los"
    vis = (hitCount == 0);
else
    error('segmentVisibility3D: mode must be "los" or "nlos".');
end
end