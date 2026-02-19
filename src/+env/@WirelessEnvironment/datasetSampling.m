function Blocks = datasetSampling(obj, mode, varargin)
% datasetSampling: build sampling Blocks for raytracing
% mode: "rand-rand", "geom-geom", "list-rand"
% varargin: additional parameters for different modes
%   - "rand-rand": 'txNum', 'rxNum'
%   - "geom-geom": 'txNumPerSc', 'rxNumPerSc', 'radiationMin', 'radiationMax'
%   - "list-rand": 'txGridList', 'rxNum' (if rxNum >= freeIdx count, uses all freeIdx)
% return: Blocks
% ---------- geometry ----------
gridSize = obj.GridSpec.gridSize;      % 网格边长
areaSize = obj.GridSpec.areaSize;     % 区域尺寸 [Lx, Ly]
scatterTable = obj.SceneSpec.scatterTable;

Kx = floor(areaSize(1) / gridSize);
Ky = floor(areaSize(2) / gridSize);  % 纵向网格数

[xg, yg] = meshgrid( ( (1:Kx) - (Kx+1)/2 ) * gridSize, ( (1:Ky) - (Ky+1)/2 ) * gridSize );
gridPos = [xg(:), yg(:)];

N_s = size(scatterTable,1);

% ---------- global valid grids (exclude all scatterer rectangles, dilated) ----------
xL = scatterTable(:,1) - gridSize/2;
yB = scatterTable(:,2) - gridSize/2;
xR = scatterTable(:,1) + scatterTable(:,4) + gridSize/2;
yT = scatterTable(:,2) + scatterTable(:,5) + gridSize/2;

inRect = (gridPos(:,1) >= xL.') & (gridPos(:,1) <= xR.') & (gridPos(:,2) >= yB.') & (gridPos(:,2) <= yT.'); % K x N logical: grid center inside dilated rectangle of each scatterer
freeIdx = find(~any(inRect, 2));
if isempty(freeIdx)
    error('No free grids available after excluding scatterer regions.');
end

switch lower(string(mode))
    case "rand-rand"
        p = inputParser;
        addParameter(p, 'txNum', 5);
        addParameter(p, 'rxNum', 5);
        parse(p, varargin{:});
        Mt_num = p.Results.txNum;
        Mr_num = p.Results.rxNum;
        [~, txSel] = sampRandom(freeIdx, Mt_num, false);
        [~, rxSel] = sampRandom(freeIdx, Mr_num, false);

        Blocks = struct('txSel', txSel(:), 'rxSel', rxSel(:), 'tag', "rand-rand", 'sid', NaN);
    case "geom-geom"
        p = inputParser;
        addParameter(p, 'txNumPerSc', 4);
        addParameter(p, 'rxNumPerSc', 4);
        addParameter(p, 'radiationMin', 2*gridSize);
        addParameter(p, 'radiationMax', 4*gridSize);
        parse(p, varargin{:});
        
        rMin = p.Results.radiationMin;
        rMax = p.Results.radiationMax;
        MtPerSc = p.Results.txNumPerSc;
        MrPerSc = p.Results.rxNumPerSc;

        Blocks = repmat(struct('txSel', [], 'rxSel', [], 'tag', "geom-geom", 'sid', NaN), N_s, 1);

        pool = freeIdx(:);
        for n = 1:N_s
            s = scatterTable(n,:);
            sc_pos = [s(1)+s(4)/2, s(2)+s(5)/2];

            [pool, txSel] = sampGeometryBins(pool, gridPos, sc_pos, MtPerSc, rMin, rMax, true);
            [pool, rxSel] = sampGeometryBins(pool, gridPos, sc_pos, MrPerSc, rMin, rMax, true);

            Blocks(n).txSel = txSel(:);
            Blocks(n).rxSel = rxSel(:);
            Blocks(n).tag   = "geom-geom";
            Blocks(n).sid   = n;
        end
    case "list-rand"
        p = inputParser;
        addParameter(p, 'txGridList', [0,0]);
        addParameter(p, 'rxNum', 5);
        parse(p, varargin{:});
        txGridCR = p.Results.txGridList;
        Mr_num = p.Results.rxNum;
        [~, txSel] = sampUserGridList(freeIdx, txGridCR, Kx, Ky, false);
        
        % If rxNum >= freeIdx count, use all freeIdx (list-full behavior)
        % Otherwise, randomly sample rxNum RX positions (list-rand behavior)
        if Mr_num >= numel(freeIdx)
            rxSel = freeIdx(:);
        else
            [~, rxSel] = sampRandom(freeIdx, Mr_num, false);
        end
        Blocks = struct('txSel', txSel(:), 'rxSel', rxSel(:), 'tag', "list-rand", 'sid', NaN);
    case "randblock-randblock"
        p = inputParser;
        addParameter(p, 'txNumPerBlock', 4);
        addParameter(p, 'rxNumPerBlock', 4);
        addParameter(p, 'numBlocks', N_s);
        parse(p, varargin{:});

        MtPer = p.Results.txNumPerBlock;
        MrPer = p.Results.rxNumPerBlock;
        B     = p.Results.numBlocks;
        
        Blocks = repmat(struct('txSel', [], 'rxSel', [], 'tag', "randblock-randblock", 'sid', NaN), B, 1);
        pool = freeIdx(:);
        for b = 1:B
            [pool, txSel] = sampRandom(pool, MtPer, true);
            [pool, rxSel] = sampRandom(pool, MrPer, true);

            Blocks(b).txSel = txSel(:);
            Blocks(b).rxSel = rxSel(:);
            Blocks(b).tag   = "randblock";
            Blocks(b).sid   = b;
        end
    otherwise
        error('Unknown mode: %s', mode);
end
end
        