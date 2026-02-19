function vg = ok_experimentalVariogram(XY, z, varargin)
p = inputParser;
p.addParameter("MaxDistance", []);
p.addParameter("NumBins", 20);
p.parse(varargin{:});
opt = p.Results;

XY = double(XY);
z = double(z(:));

N = size(XY,1);
if N < 2
    vg.distance = 0;
    vg.gamma = 0;
    vg.count = 0;
    return;
end

% pairwise distances (upper triangle)
dx = XY(:,1) - XY(:,1).';
dy = XY(:,2) - XY(:,2).';
D  = hypot(dx, dy);

dz = z - z.';
G  = 0.5 * (dz.^2);

mask = triu(true(N), 1);
d = D(mask);
g = G(mask);

if isempty(opt.MaxDistance)
    opt.MaxDistance = prctile(d, 90);
end

keep = (d > 0) & (d <= opt.MaxDistance) & isfinite(g);
d = d(keep);
g = g(keep);

B = max(5, opt.NumBins);
edges = linspace(0, opt.MaxDistance, B+1);
centers = 0.5*(edges(1:end-1) + edges(2:end));

gamma = nan(B,1);
count = zeros(B,1);

for b = 1:B
    in = (d >= edges(b)) & (d < edges(b+1));
    count(b) = nnz(in);
    if count(b) > 0
        gamma(b) = mean(g(in));
    end
end

valid = (count > 0) & isfinite(gamma);
vg.distance = centers(valid).';
vg.gamma    = gamma(valid);
vg.count    = count(valid);
end