function evaluate(obj, opt, savePath)
% evaluate - model-specific evaluation pipeline
% Uses ScatteringModel's protected helper methods.
% savePath is accepted for interface consistency and currently unused.
if nargin < 3 %#ok<INUSD>
    savePath = "";
end

if nargin < 2 || isempty(opt), opt = struct(); end
if ~isfield(opt,"whichSet"),   opt.whichSet = "test"; end
if ~isfield(opt,"doPdf"),      opt.doPdf = true; end
if ~isfield(opt,"doCgm"),      opt.doCgm = true; end
if ~isfield(opt,"doResidual"), opt.doResidual = true; end
if ~isfield(opt,"txGridList"), opt.txGridList = [30 20]; end

% -------- core metrics --------
P = obj.evalPrepare(string(opt.whichSet), opt);
M = obj.evalMetricsCore(P);
B = obj.evalMetricsBuckets(P, [0.5 0.9]);
obj.evalReport(M, B);

% -------- optional plots --------
if opt.doPdf
    obj.plotPdfCompare(P, opt);
end
if opt.doCgm
    txList = opt.txGridList;
    if size(txList,2) ~= 2, txList = reshape(txList, [], 2); end
    for k = 1:size(txList,1)
        obj.plotCgmMap(txList(k,:), opt);
    end
end
if opt.doResidual
    txList = opt.txGridList;
    if size(txList,2) ~= 2, txList = reshape(txList, [], 2); end
    for k = 1:size(txList,1)
        obj.plotResidualMap(txList(k,:), opt);
    end
end

% -------- kriging-specific diagnostics --------
if isfield(obj.KrigingSpec, "verbose") && obj.KrigingSpec.verbose
    obj.printKrigingTrainingSummary();
end
end
