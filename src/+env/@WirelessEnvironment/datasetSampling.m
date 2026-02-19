% datasetSampling - Build sampling blocks for raytracing simulation
%
% SYNTAX:
%   Blocks = datasetSampling(obj, mode)
%   Blocks = datasetSampling(obj, mode, Name, Value, ...)
%
% DESCRIPTION:
%   Generates sampling blocks containing transmitter and receiver grid positions
%   for raytracing based on the specified sampling mode. The function excludes
%   grid positions that overlap with scatterer regions.
%
% INPUT ARGUMENTS:
%   obj           - WirelessEnvironment object containing GridSpec and SceneSpec
%   mode          - Sampling mode (string or char):
%                   - "rand-rand"          : Random TX and RX sampling
%                   - "geom-geom"          : Geometric distribution around scatterers
%                   - "list-rand"          : User-specified TX list with random RX
%                   - "randblock-randblock": Sequential random block sampling
%
% NAME-VALUE PAIRS (varargin):
%   For "rand-rand" mode:
%       'txNum'           - Number of TX positions (default: 5)
%       'rxNum'           - Number of RX positions (default: 5)
%
%   For "geom-geom" mode:
%       'txNumPerSc'      - TX positions per scatterer (default: 4)
%       'rxNumPerSc'      - RX positions per scatterer (default: 4)
%       'radiationMin'    - Minimum sampling radius (default: 2*gridSize)
%       'radiationMax'    - Maximum sampling radius (default: 4*gridSize)
%
%   For "list-rand" mode:
%       'txGridList'      - [col, row] grid coordinates for TX (default: [0,0])
%       'rxNum'           - Number of RX positions; if >= freeIdx count, uses all
%
%   For "randblock-randblock" mode:
%       'txNumPerBlock'   - TX positions per block (default: 4)
%       'rxNumPerBlock'   - RX positions per block (default: 4)
%       'numBlocks'       - Number of blocks (default: number of scatterers)
%
%   For "list-geom" mode:
%       'txGridList'      - [col, row] TX list (default: [0,0])
%       'rxNumPerSc'      - RX positions per scatterer for each TX (default: 4)
%       'radiationMin'    - Minimum sampling radius (default: 2*gridSize)
%       'radiationMax'    - Maximum sampling radius (default: 4*gridSize)
%       'dedupRx'         - Deduplicate RX indices (default: true)
%       'oneBlockPerTx'   - If true, returns one block per TX (default: true)
%
% OUTPUT ARGUMENTS:
%   Blocks        - Array of structures with fields:
%                   - txSel: Indices of selected TX grid positions
%                   - rxSel: Indices of selected RX grid positions
%                   - tag:   Sampling mode identifier (string)
%                   - sid:   Scatterer ID or block ID (NaN for non-block modes)
%
% NOTES:
%   - Grid positions overlapping with scatterer rectangles (dilated by gridSize/2)
%     are excluded from sampling.
%   - For "list-rand" mode with rxNum >= number of free grids, all free grids
%     are used as RX positions.
%   - The function requires obj.GridSpec.gridSize, obj.GridSpec.areaSize, and
%     obj.SceneSpec.scatterTable to be properly defined.
%
% ERRORS:
%   - Throws error if no free grids available after excluding scatterer regions.
%   - Throws error if unknown mode is specified.
%
% SEE ALSO:
%   sampRandom, sampGeometryBins, sampUserGridList
function Blocks = datasetSampling(obj, mode, varargin)
% ---------- geometry ----------
gridSize = obj.GridSpec.gridSize;
areaSize = obj.GridSpec.areaSize;
scatterTable = obj.SceneSpec.scatterTable;

Kx = floor(areaSize(1) / gridSize);
Ky = floor(areaSize(2) / gridSize);

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
    case "list-geom"
        % list-geom: given TX list, sample RX geometrically around EACH scatterer
        % Output default: one block per TX (best for per-TX training like VirtualScatter3D)

        p = inputParser;
        addParameter(p, 'txGridList', [0,0]);     % [col,row], [0,0] means random fill
        addParameter(p, 'rxNumPerSc', 4);
        addParameter(p, 'radiationMin', 2*gridSize);
        addParameter(p, 'radiationMax', 4*gridSize);
        addParameter(p, 'dedupRx', true);
        addParameter(p, 'oneBlockPerTx', true);
        parse(p, varargin{:});

        txGridCR = p.Results.txGridList;
        MrPerSc  = p.Results.rxNumPerSc;
        rMin     = p.Results.radiationMin;
        rMax     = p.Results.radiationMax;
        dedupRx  = logical(p.Results.dedupRx);
        oneBlockPerTx = logical(p.Results.oneBlockPerTx);

        % ---- choose TXs from user list (must be free grids) ----
        [~, txSelAll] = sampUserGridList(freeIdx, txGridCR, Kx, Ky, false);
        txSelAll = txSelAll(:);
        if isempty(txSelAll)
            error('list-geom: txSel is empty. Check txGridList and free-grid constraints.');
        end

        % ---- build blocks ----
        if oneBlockPerTx
            Blocks = repmat(struct('txSel', [], 'rxSel', [], 'tag', "list-geom", 'sid', NaN), numel(txSelAll), 1);
        else
            % single block containing all TXs (rarely useful for per-TX training)
            Blocks = struct('txSel', txSelAll, 'rxSel', [], 'tag', "list-geom", 'sid', NaN);
        end

        for t = 1:numel(txSelAll)
            txIdx = txSelAll(t);

            % For this TX: sample RX around each scatterer using angular bins.
            % Use a TX-local pool with removeFlag=true to avoid duplicate RX
            % across different scatterers for the same TX.
            rxSelAll = zeros(0,1);
            localPool = freeIdx(:);
            for n = 1:N_s
                s = scatterTable(n,:);
                sc_pos = [s(1)+s(4)/2, s(2)+s(5)/2];

                [localPool, rxSel_n] = sampGeometryBins(localPool, gridPos, sc_pos, MrPerSc, rMin, rMax, true);
                rxSelAll = [rxSelAll; rxSel_n(:)]; %#ok<AGROW>
            end

            if dedupRx
                rxSelAll = unique(rxSelAll, 'stable');
            end

            if oneBlockPerTx
                Blocks(t).txSel = txIdx;
                Blocks(t).rxSel = rxSelAll;
                Blocks(t).tag   = "list-geom";
                Blocks(t).sid   = txIdx;   % store TX index for traceability
            else
                % single block: append (not recommended)
                Blocks.rxSel = unique([Blocks.rxSel(:); rxSelAll(:)], 'stable');
            end
        end
    otherwise
        error('Unknown mode: %s', mode);
end
end
        
