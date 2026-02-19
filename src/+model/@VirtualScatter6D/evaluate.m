function evaluate(obj, opt)
% evaluate - example evaluation pipeline (calls all reusable blocks)
%
% This implementation is intentionally "full": it calls all base blocks and
% generates both CGM heatmaps and residual diagnostics.

if nargin < 2 || isempty(opt), opt = struct(); end
if ~isfield(opt,"whichSet"),      opt.whichSet = "test"; end
if ~isfield(opt,"txGridList"),    opt.txGridList = [30 30]; end
if ~isfield(opt,"doPdf"),         opt.doPdf = true; end
if ~isfield(opt,"doCgm"),         opt.doCgm = true; end
if ~isfield(opt,"doResidual"),    opt.doResidual = true; end

% default knobs consumed by base blocks / plots
if ~isfield(opt,"q"),             opt.q = 0.02; end
if ~isfield(opt,"eps_min"),       opt.eps_min = 1e-12; end
if ~isfield(opt,"eps_mW"),        opt.eps_mW = opt.eps_min; end
if ~isfield(opt,"binWidth_dB"),   opt.binWidth_dB = 1.0; end
if ~isfield(opt,"smoothWin"),     opt.smoothWin = 3; end
if ~isfield(opt,"topPercentile"), opt.topPercentile = 95; end

if isempty(obj.scatterInfo)
    error('[evaluate] scatterInfo is empty. Call train() first.');
end
fprintf('\n[%s.evaluate] Evaluating ...\n', obj.ModelSpec.modelId);

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
