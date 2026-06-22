% EVALUATE - Example evaluation pipeline (calls all reusable blocks)
%
% SYNTAX:
%   [P, M, B] = evaluate(obj, opt, savePath)
%
% DESCRIPTION:
%   This implementation is intentionally "full": it calls all base blocks and
%   generates both CGM heatmaps and residual diagnostics.
%
% INPUTS:
%   obj     - VirtualScatter6D object instance
%   opt     - (optional) struct with configuration options
%   savePath - output file path prefix (without extension). If empty,
%              figures are not saved.
%
% OUTPUTS:
%   P       - Standardized prediction pack from evalPrepare()
%   M       - Core metrics from evalMetricsCore()
%   B       - Bucket metrics from evalMetricsBuckets()
%
% OPTIONS:
%   whichSet       - Dataset to evaluate on (default: "test")
%   txGridList     - [N x 2] array of [col, row] transmitter grid positions 
%                    for spatial diagnostics (default: [30 30])
%   doPdf          - Generate PDF comparison plots (default: true)
%   doCgm          - Generate CGM heatmaps (default: true)
%   doResidual     - Generate residual diagnostic maps (default: true)
%   q              - Quantile parameter for base blocks (default: 0.02)
%   eps_min        - Minimum epsilon threshold (default: 1e-12)
%   eps_mW         - Power-related epsilon threshold (default: eps_min)
%   binWidth_dB    - Histogram bin width in dB (default: 1.0)
%   smoothWin      - Smoothing window size (default: 3)
%   topPercentile  - Top percentile threshold (default: 95)
%
% WORKFLOW:
%   1. Prepares standardized prediction pack via evalPrepare()
%   2. Computes core metrics via evalMetricsCore()
%   3. Computes bucket metrics via evalMetricsBuckets()
%   4. Reports results via evalReport()
%   5. Generates PDF comparisons if enabled
%   6. Generates spatial diagnostics (CGM and residual maps) for each txGrid
%
% NOTES:
%   - Requires scatterInfo to be populated (call train() first)
%   - txGridList must be [N x 2] as [col, row] coordinates
%
% ERRORS:
%   Throws error if scatterInfo is empty
%   Throws error if txGridList is not properly formatted
function [P, M, B] = evaluate(obj, opt, savePath)
if nargin < 3 || isempty(savePath)
    savePath = "";
end
if nargin < 2 || isempty(opt), opt = struct(); end
if ~isfield(opt,"whichSet"),      opt.whichSet = "test"; end
if ~isfield(opt,"txGridList"),    opt.txGridList = [30 30]; end
if ~isfield(opt,"cgmSliceMode"),  opt.cgmSliceMode = "fixTx"; end
if ~isfield(opt,"cgmGridList"),   opt.cgmGridList = opt.txGridList; end
if ~isfield(opt,"doPdf"),         opt.doPdf = true; end
if ~isfield(opt,"doCgm"),         opt.doCgm = true; end
if ~isfield(opt,"doResidual"),    opt.doResidual = true; end

% knobs consumed by base blocks / plots
if ~isfield(opt,"q"),             opt.q = 0.017; end
if ~isfield(opt,"eps_min"),       opt.eps_min = 1e-12; end
if ~isfield(opt,"eps_mW"),        opt.eps_mW = opt.eps_min; end
if ~isfield(opt,"binWidth_dB"),   opt.binWidth_dB = 1.0; end
if ~isfield(opt,"smoothWin"),     opt.smoothWin = 3; end
if ~isfield(opt,"topPercentile"), opt.topPercentile = 95; end

if isempty(obj.scatterInfo)
    error('[VirtualScatter6D.evaluate] scatterInfo is empty. Call train() first.');
end
fprintf('\n[VirtualScatter6D.evaluate] Evaluating ...\n');
figsBefore = findall(0, 'Type', 'figure');

doSave = strlength(string(savePath)) > 0;
savePathStr = char(string(savePath));
if doSave
    [saveDir, ~, ~] = fileparts(savePathStr);
    if ~isempty(saveDir) && ~isfolder(saveDir)
        mkdir(saveDir);
    end
    if ~isfolder(savePathStr)
        mkdir(savePathStr);
    end
end

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
    if doSave
        baseName = fullfile(savePath, 'pdf_compare');
        saveas(gcf, string(baseName) + ".png");
        savefig(gcf, string(baseName) + ".fig");
    end
end

% ----- 5) spatial diagnostics -----
if size(opt.cgmGridList,2) ~= 2
    error('opt.cgmGridList must be [N x 2] as [col,row].');
end

if opt.doCgm
    for i = 1:size(opt.cgmGridList,1)
        obj.plotCgmSlice(char(string(opt.cgmSliceMode)), opt.cgmGridList(i,:));
        if doSave
            baseName = fullfile(savePath, sprintf('cgm_%s_grid%d', opt.cgmSliceMode, i));
            saveas(gcf, string(baseName) + ".png");
            savefig(gcf, string(baseName) + ".fig");
        end
    end
end

if opt.doResidual
    for i = 1:size(opt.cgmGridList,1)
        obj.plotResidualMap(opt.cgmGridList(i,:), opt);
        if doSave
            baseName = fullfile(savePath, sprintf('residual_grid%d', i));
            saveas(gcf, string(baseName) + ".png");
            savefig(gcf, string(baseName) + ".fig");
        end
    end
end

if doSave
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
