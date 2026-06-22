% ok_experimentalVariogram - Compute a binned experimental semivariogram.
%
% SYNTAX:
%   vg = ok_experimentalVariogram(XY, z)
%   vg = ok_experimentalVariogram(XY, z, Name, Value)
%
% INPUTS:
%   XY - [N x 2] sample coordinates.
%   z  - [N x 1] sample values (typically power in dBm).
%
% NAME-VALUE:
%   "MaxDistance" - maximum lag distance used in binning.
%                   Default: max pairwise distance / 2.
%   "NumBins"     - number of lag bins. Default: 20.
%
% OUTPUT:
%   vg - struct with fields:
%        .distance : [B x 1] bin center distance
%        .gamma    : [B x 1] semivariance mean per bin
%        .count    : [B x 1] number of pairs per bin
%
% NOTES:
%   - Uses unique sample pairs from the upper triangle only.
%   - Empty bins are dropped from output.
%   - If valid pair distances are unavailable, returns zeros.
function vg = ok_experimentalVariogram(XY, z, varargin)
p = inputParser;
p.addParameter("MaxDistance", []);
p.addParameter("NumBins", 20);
p.parse(varargin{:});
opt = p.Results;

% Normalize input layout/type for vectorized pairwise operations.
XY = double(XY);
z = double(z(:));

N = size(XY,1);
% Not enough points to form a distance pair.
if N < 2
    vg.distance = 0;
    vg.gamma = 0;
    vg.count = 0;
    return;
end

% Build full pairwise distance/semivariance matrices, then keep upper
% triangle to avoid duplicated (i,j)/(j,i) pairs and self-pairs.
dx = XY(:,1) - XY(:,1).';
dy = XY(:,2) - XY(:,2).';
D  = hypot(dx, dy);

dz = z - z.';
G  = 0.5 * (dz.^2);

mask = triu(true(N), 1);
d = D(mask);
g = G(mask);

% Default lag cutoff: half of the maximum valid pair distance.
if isempty(opt.MaxDistance)
    dPos = d((d > 0) & isfinite(d));
    if isempty(dPos)
        vg.distance = 0;
        vg.gamma = 0;
        vg.count = 0;
        return;
    end
    opt.MaxDistance = max(dPos) / 2;
end

% Keep only positive distances within cutoff and finite semivariance.
keep = (d > 0) & (d <= opt.MaxDistance) & isfinite(g);
d = d(keep);
g = g(keep);

% Construct equally spaced lag bins on [0, MaxDistance].
B = max(5, opt.NumBins);
edges = linspace(0, opt.MaxDistance, B+1);
centers = 0.5*(edges(1:end-1) + edges(2:end));

gamma = nan(B,1);
count = zeros(B,1);

for b = 1:B
    % Left-closed, right-open binning rule.
    in = (d >= edges(b)) & (d < edges(b+1));
    count(b) = nnz(in);
    if count(b) > 0
        % Experimental semivariance per bin: average pair semivariance.
        gamma(b) = mean(g(in));
    end
end

% Drop empty/invalid bins to return compact variogram samples.
valid = (count > 0) & isfinite(gamma);
vg.distance = centers(valid).';
vg.gamma    = gamma(valid);
vg.count    = count(valid);
end
