% EVALUATE Evaluate the virtual scatterer 3D model on a specified dataset
%   evaluate(obj, opt, savePath) performs comprehensive evaluation of the trained 3D
%   virtual scatterer model, including metrics computation, PDF comparisons, 
%   and spatial diagnostics visualizations.
%
%   INPUTS:
%       obj     VirtualScatter3D object with trained scatterInfo
%       opt     struct with optional evaluation parameters:
%           whichSet        char/string - Dataset to evaluate ("test" default)
%           txGridList      [N x 2] numeric - Transmitter grid coordinates 
%                           [col, row] for spatial diagnostics (default: [30 30])
%           doPdf           logical - Generate PDF comparison plots (default: true)
%           doCgm           logical - Generate CGM (Cumulative Gain Map) plots 
%                           for each TX grid (default: true)
%           doResidual      logical - Generate residual map plots for each TX 
%                           grid (default: true)
%           q               numeric - Quantile parameter for metrics 
%                           (default: 0.02)
%           eps_min         numeric - Minimum epsilon threshold 
%                           (default: 1e-12)
%           eps_mW          numeric - Epsilon for mW calculations 
%                           (default: eps_min)
%           binWidth_dB     numeric - Histogram bin width in dB 
%                           (default: 1.0)
%           smoothWin       numeric - Smoothing window size for diagnostics 
%                           (default: 3)
%           topPercentile   numeric - Top percentile for threshold analysis 
%                           (default: 95)
%       savePath    char/string - output file path prefix (without extension).
%                   if empty, figures are not saved.
%
%   OUTPUTS:
%       None. Results are reported via console output and generated plots.
%
%   NOTES:
%       - Requires scatterInfo to be populated; call train() first
%       - Performs per-TX 3D baseline evaluation
%       - txGridList rows must have exactly 2 columns [col, row]
%
%   EXAMPLE:
%       opt = struct('whichSet', 'test', 'txGridList', [30 30; 20 20]);
%       evaluate(obj, opt, fullfile("outputs", "VirtualScatter3D_seed421"));
function evaluate(obj, opt, savePath)
if nargin < 2 || isempty(opt), opt = struct(); end
if ~isfield(opt,"whichSet"),      opt.whichSet = "test"; end
if ~isfield(opt,"txGridList"),    opt.txGridList = [30 30]; end
if ~isfield(opt,"cgmSliceMode"),  opt.cgmSliceMode = "fixTx"; end
if ~isfield(opt,"cgmGridList"),   opt.cgmGridList = opt.txGridList; end
if ~isfield(opt,"doPdf"),         opt.doPdf = true; end
if ~isfield(opt,"doCgm"),         opt.doCgm = true; end
if ~isfield(opt,"doResidual"),    opt.doResidual = true; end

% knobs consumed by base blocks / plots
if ~isfield(opt,"q"),             opt.q = 0.02; end
if ~isfield(opt,"eps_min"),       opt.eps_min = 1e-12; end
if ~isfield(opt,"eps_mW"),        opt.eps_mW = opt.eps_min; end
if ~isfield(opt,"binWidth_dB"),   opt.binWidth_dB = 1.0; end
if ~isfield(opt,"smoothWin"),     opt.smoothWin = 3; end
if ~isfield(opt,"topPercentile"), opt.topPercentile = 95; end

if isempty(obj.scatterInfo)
    error('[VirtualScatter3D.evaluate] scatterInfo is empty. Call train() first.');
end
fprintf('\n[VirtualScatter3D.evaluate] Evaluating (per-TX 3D baseline) ...\n');
figsBefore = findall(0, 'Type', 'figure');

% ----- 1) standardized prediction pack -----
P = obj.evalPrepare(opt.whichSet, opt);

% ----- 2) metrics -----
M = obj.evalMetricsCore(P);
B = obj.evalMetricsBuckets(P, [0.50 0.90]);

% ----- 3) report -----
obj.evalReport(M, B);

% ----- 4) PDF -----
if opt.doPdf
    obj.plotPdfCompare(P, opt);
end

% ----- 5) spatial diagnostics -----
if size(opt.cgmGridList,2) ~= 2
    error('opt.cgmGridList must be [N x 2] as [col,row].');
end

if opt.doCgm
    for i = 1:size(opt.cgmGridList,1)
        obj.plotCgmSlice(char(string(opt.cgmSliceMode)), opt.cgmGridList(i,:));
    end
end

if opt.doResidual
    for i = 1:size(opt.cgmGridList,1)
        index = opt.cgmGridList(i,:);
        obj.plotResidualMap(index, opt);
    end
end

if strlength(string(savePath)) > 0
    savePathStr = char(string(savePath));
    [saveDir, ~, ~] = fileparts(savePathStr);
    if ~isempty(saveDir) && ~isfolder(saveDir)
        mkdir(saveDir);
    end

    figsAfter = findall(0, 'Type', 'figure');
    figs = setdiff(figsAfter, figsBefore);
    if ~isempty(figs)
        figNums = arrayfun(@(h) h.Number, figs);
        [~, idxOrder] = sort(figNums);
        figs = figs(idxOrder);
    end
    for i = 1:numel(figs)
        baseName = sprintf('%s_%02d', savePathStr, i);
        saveas(figs(i), string(baseName) + ".png");
        savefig(figs(i), string(baseName) + ".fig");
    end
end
end
