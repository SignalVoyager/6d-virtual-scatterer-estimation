% EVALUATE Evaluate Kriging baseline model on a specified dataset
%   [P, M, B] = evaluate(obj, opt, savePath) runs full evaluation for the
%   trained Kriging model, including metrics computation, PDF comparison,
%   and spatial diagnostics visualizations.
%
%   INPUTS:
%       obj     KrigingModel object with trained scatterInfo
%       opt     struct with optional evaluation parameters:
%           whichSet        char/string - Dataset to evaluate ("test" default)
%           txGridList      [N x 2] numeric - Transmitter grid coordinates
%                           [col, row] for spatial diagnostics (default: [30 30])
%           cgmSliceMode    char/string - Slice mode for CGM plotting
%                           (default: "fixTx")
%           cgmGridList     [N x 2] numeric - Grid list used by CGM/residual
%                           plots (default: txGridList)
%           doPdf           logical - Generate PDF comparison plots
%                           (default: true)
%           doCgm           logical - Generate CGM plots for each grid
%                           (default: true)
%           doResidual      logical - Generate residual maps for each grid
%                           (default: true)
%           q               numeric - Quantile parameter for metrics
%                           (default: 0.017)
%           eps_min         numeric - Minimum epsilon threshold
%                           (default: 1e-12)
%           eps_mW          numeric - Epsilon for mW calculations
%                           (default: eps_min)
%           binWidth_dB     numeric - Histogram bin width in dB
%                           (default: 1.0)
%           smoothWin       numeric - Smoothing window size
%                           (default: 3)
%           topPercentile   numeric - Top percentile for threshold analysis
%                           (default: 95)
%       savePath    char/string - output file path prefix (without extension).
%                   If empty, figures are not saved.
%
%   OUTPUTS:
%       P           struct - Standardized prediction pack from evalPrepare().
%       M           struct - Core metrics from evalMetricsCore().
%       B           struct - Bucket metrics from evalMetricsBuckets().
%
%   NOTES:
%       - Requires scatterInfo to be populated; call train() first
%       - Uses per-TX Kriging baseline prediction flow
%       - cgmGridList rows must have exactly 2 columns [col, row]
%
%   EXAMPLE:
%       opt = struct('whichSet', 'test', 'txGridList', [30 30; 20 20]);
%       [P, M, B] = evaluate(obj, opt, fullfile("outputs", "Kriging_seed421"));
function [P, M, B] = evaluate(obj, opt, savePath)
if nargin < 3 || isempty(savePath)
    savePath = "";
end
if nargin < 2 || isempty(opt), opt = struct(); end
if ~isfield(opt,"whichSet"),   opt.whichSet = "test"; end
if ~isfield(opt,"txGridList"), opt.txGridList = [30 30]; end
if ~isfield(opt,"cgmSliceMode"),  opt.cgmSliceMode = "fixTx"; end
if ~isfield(opt,"cgmGridList"),   opt.cgmGridList = opt.txGridList; end
if ~isfield(opt,"doPdf"),      opt.doPdf = true; end
if ~isfield(opt,"doCgm"),      opt.doCgm = true; end
if ~isfield(opt,"doResidual"), opt.doResidual = true; end

% knobs consumed by base blocks / plots
if ~isfield(opt,"q"),             opt.q = 0.017; end
if ~isfield(opt,"eps_min"),       opt.eps_min = 1e-12; end
if ~isfield(opt,"eps_mW"),        opt.eps_mW = opt.eps_min; end
if ~isfield(opt,"binWidth_dB"),   opt.binWidth_dB = 1.0; end
if ~isfield(opt,"smoothWin"),     opt.smoothWin = 3; end
if ~isfield(opt,"topPercentile"), opt.topPercentile = 95; end

if isempty(obj.scatterInfo)
    error('[KrigingModel.evaluate] scatterInfo is empty. Call train() first.');
end
fprintf('\n[KrigingModel.evaluate] Evaluating (per-TX 3D baseline) ...\n');
figsBefore = findall(0, 'Type', 'figure');

% ----- 1) standardized prediction pack -----
P = obj.evalPrepare(string(opt.whichSet), opt);

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
