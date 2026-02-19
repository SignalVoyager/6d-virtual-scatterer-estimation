% EVALUATE Evaluate the virtual scatterer 3D model on a specified dataset
%   evaluate(obj, opt) performs comprehensive evaluation of the trained 3D 
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
%       evaluate(obj, opt);
function evaluate(obj, opt)
if nargin < 2 || isempty(opt), opt = struct(); end
if ~isfield(opt,"whichSet"),      opt.whichSet = "test"; end
if ~isfield(opt,"txGridList"),    opt.txGridList = [30 30]; end
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
txList = opt.txGridList;
if isempty(txList), return; end
if size(txList,2) ~= 2
    error('opt.txGridList must be [N x 2] as [col,row].');
end

for i = 1:size(txList,1)
    txGrid = txList(i,:);
    if opt.doCgm
        obj.plotCgmMap(txGrid, opt);
    end
    if opt.doResidual
        obj.plotResidualMap(txGrid, opt);
    end
end
end
