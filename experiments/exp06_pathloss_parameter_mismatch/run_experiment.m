% run_experiment.m (PATH-LOSS PARAMETER MISMATCH)
% Inputs injected by main_all_experiments.m: expRoot, seed
%
% Protocol: keep the RT data fixed. For every assumed (alpha,beta0), rebuild
% the reconstruction design matrix, re-solve Eq. (7), and reconstruct the
% unchanged test set using that same assumed pair. No RT is performed.

dataDir = fullfile(expRoot, "data");
responseDir = fullfile(dataDir, "responses");
originalDir = fullfile(expRoot, "outputs", "original");
finalDir = fullfile(expRoot, "outputs", "final");
logDir = fullfile(expRoot, "outputs", "logs");
dirs = {dataDir, responseDir, originalDir, finalDir, logDir};
for iDir = 1:numel(dirs), if ~isfolder(dirs{iDir}), mkdir(dirs{iDir}); end, end

cfg = jsondecode(fileread(fullfile(expRoot, "config.json")));
S = cfg.mismatchSensitivity;
if isfield(cfg.runtime, "refreshFinalOnly") && logical(cfg.runtime.refreshFinalOnly)
    iRefreshFinal(originalDir, finalDir, S);
    return;
end

assert(~isfield(cfg, "dataCleaning") || ~logical(cfg.dataCleaning.enabled), ...
    "[PL-MISMATCH] dataCleaning must remain disabled so evaluate() controls the noise floor.");

trainPath = fullfile(expRoot, sprintf(string(S.trainCacheSourceTemplate), seed));
testPath = fullfile(expRoot, string(S.testCacheSource));
assert(isfile(trainPath), "[PL-MISMATCH] Missing reusable train cache: %s", trainPath);
assert(isfile(testPath), "[PL-MISMATCH] Missing reusable test cache: %s", testPath);
trainSet = iLoadResults(trainPath);
testSet = iLoadResults(testPath);
fprintf("[PL-MISMATCH] Reused caches: train=%d, test=%d, seed=%d. No RT will run.\n", ...
    size(trainSet,1), size(testSet,1), seed);

p = iBaseParams(cfg, expRoot);
h = cfg.models.VirtualScatter6D.hyper;
ray = struct("trainSet", trainSet, "testSet", testSet);

E = cfg.modelEvaluation;
eopt = struct("whichSet", "test", "doPdf", false, "doCgm", false, "doResidual", false, ...
    "q", E.q, "eps_min", E.eps_min, "eps_mW", E.eps_mW);
rows = struct([]);
rowIdx = 0;

% Alpha mismatch: use the assumed alpha in both Eq. (7) and reconstruction.
alphaList = S.alphaList(:).';
for alpha = alphaList
    p.responseFile = fullfile(responseDir, sprintf("response_alpha_%s_seed%d.mat", iValueTag(alpha), seed));
    mismatchModel = iFitAssumedModel(p, h, alpha, S.nominalBeta0_dB, S.nominalBeta0_dB, ray);
    [~, M] = mismatchModel.evaluate(eopt, "");
    rowIdx = rowIdx + 1;
    newRow = iMetricRow(seed, "alpha", alpha, alpha - S.nominalAlpha, ...
        S.nominalAlpha, S.nominalBeta0_dB, size(trainSet,1), size(testSet,1), M);
    if rowIdx == 1, rows = newRow; else, rows(rowIdx) = newRow; end
    fprintf("[PL-MISMATCH] alpha=%.3g (delta=%+.3g): MAE=%.4f dB.\n", ...
        alpha, alpha-S.nominalAlpha, M.mae_dB);
end

% Beta0 mismatch: apply the assumed global gain in both Eq. (7) and
% reconstruction. With unconstrained response coefficients, this global
% scale is theoretically absorbed by the fitted coefficients.
betaList = S.beta0List_dB(:).';
for beta0dB = betaList
    deltaDb = beta0dB - S.nominalBeta0_dB;
    p.responseFile = fullfile(responseDir, sprintf("response_beta0_%s_seed%d.mat", iValueTag(beta0dB), seed));
    mismatchModel = iFitAssumedModel(p, h, S.nominalAlpha, beta0dB, S.nominalBeta0_dB, ray);
    [~, M] = mismatchModel.evaluate(eopt, "");
    rowIdx = rowIdx + 1;
    newRow = iMetricRow(seed, "beta0", beta0dB, deltaDb, ...
        S.nominalAlpha, S.nominalBeta0_dB, size(trainSet,1), size(testSet,1), M);
    rows(rowIdx) = newRow;
    fprintf("[PL-MISMATCH] beta0=%.3g dB (delta=%+.3g dB): MAE=%.4f dB.\n", ...
        beta0dB, deltaDb, M.mae_dB);
end

rawTable = struct2table(rows);
rawCsv = fullfile(originalDir, sprintf("pathloss_mismatch_raw_seed%d.csv", seed));
writetable(rawTable, rawCsv);
save(fullfile(originalDir, sprintf("pathloss_mismatch_raw_seed%d.mat", seed)), ...
    "rawTable", "trainPath", "testPath");
iRefreshFinal(originalDir, finalDir, S);
fprintf("[PL-MISMATCH] Done: %s\n", rawCsv);

function data = iLoadResults(path)
vars = who("-file", path);
assert(any(strcmp(vars, "Results")), "[PL-MISMATCH] Cache has no Results variable: %s", path);
x = load(path, "Results");
data = x.Results;
assert(isnumeric(data) && size(data,2) >= 3, "[PL-MISMATCH] Invalid cache: %s", path);
data = data(:,1:3);
end

function p = iBaseParams(cfg, expRoot)
scene = cfg.scenes.(char(cfg.mismatchSensitivity.scenePreset));
p = struct("fc", cfg.radio.fc, "Pt_dBm", cfg.radio.Pt_dBm, ...
    "areaSize", cfg.grid.areaSize, "gridSize", cfg.grid.gridSize, ...
    "tx_pos_z", cfg.grid.tx_pos_z, "rx_pos_z", cfg.grid.rx_pos_z, ...
    "scatterTable", scene.scatterTable, "responseFile", ...
    fullfile(expRoot, cfg.models.VirtualScatter6D.responseFile));
end

function obj = iCreateModel(p, h, alpha, ray)
obj = model.VirtualScatter6D(p, "VirtualScatter6D", ray, ...
    "NumCenters", h.NumCenters, "PathLossExp", alpha, ...
    "RefDistance", h.RefDistance, "EpsDist", h.EpsDist, "Solver", h.Solver);
end

function obj = iFitAssumedModel(p, h, alpha, beta0dB, nominalBeta0dB, ray)
% beta0 contributes a global factor c to the design matrix. Solving
% (c*A)*theta=y and predicting with (c*A)*theta is algebraically identical
% to solving A*thetaEffective=y and predicting A*thetaEffective. Therefore
% the native fit below is the exact reparameterized solution, without access
% to the model-private TypesSector method and without modifying src.
obj = iCreateModel(p, h, alpha, ray);
gain0 = 10.^((beta0dB-nominalBeta0dB)/10);
obj.train("mode","fit");
obj.scatterInfo.meta.assumedAlpha = alpha;
obj.scatterInfo.meta.assumedBeta0_dB = beta0dB;
obj.scatterInfo.meta.globalGain = gain0;
scatterer = obj.scatterInfo;
save(p.responseFile,"scatterer");
end

function tag = iValueTag(value)
tag = strrep(strrep(sprintf("%+.3g",value),"+","p"),"-","m");
tag = strrep(tag,".","p");
end

function row = iMetricRow(seed, parameter, value, delta, nominalAlpha, nominalBeta0, nTrain, nTest, M)
row = struct("seed", seed, "parameter", string(parameter), "value", value, "delta", delta, ...
    "nominalAlpha", nominalAlpha, "nominalBeta0_dB", nominalBeta0, ...
    "trainSamples", nTrain, "testSamples", nTest, "rmse_dB", M.rmse_dB, ...
    "mae_dB", M.mae_dB, "p90ae_dB", M.p90ae_dB, "bias_dB", M.bias_dB, ...
    "nmse", M.nmse, "nmae", M.nmae, "relRMSE", M.relRMSE, ...
    "rho_y_yhat", M.rho_y_yhat, "nValid", M.nValid);
end

function iRefreshFinal(originalDir, finalDir, S)
files = dir(fullfile(originalDir, "pathloss_mismatch_raw_seed*.csv"));
assert(~isempty(files), "[PL-MISMATCH] No raw seed CSV files found.");
tables = cell(numel(files),1);
for i = 1:numel(files), tables{i} = readtable(fullfile(files(i).folder, files(i).name)); end
rawAll = vertcat(tables{:});
parameters = ["alpha", "beta0"];
summaryRows = struct([]); k = 0;
for parameter = parameters
    values = unique(rawAll.value(string(rawAll.parameter) == parameter), "sorted");
    for value = values(:).'
        mask = string(rawAll.parameter) == parameter & rawAll.value == value;
        metric = rawAll.(char(S.metric))(mask);
        k = k + 1;
        summaryRows(k).parameter = parameter;
        summaryRows(k).value = value;
        summaryRows(k).delta = mean(rawAll.delta(mask));
        summaryRows(k).meanMetric = mean(metric, "omitnan");
        summaryRows(k).stdMetric = std(metric, "omitnan");
        summaryRows(k).numRuns = nnz(mask);
        summaryRows(k).semMetric = summaryRows(k).stdMetric / sqrt(max(nnz(mask),1));
        summaryRows(k).ci95Metric = 1.96 * summaryRows(k).semMetric;
    end
end
summaryTable = struct2table(summaryRows);
writetable(summaryTable, fullfile(finalDir, "pathloss_mismatch_summary.csv"));
save(fullfile(finalDir, "pathloss_mismatch_summary.mat"), "summaryTable", "rawAll");
iPlotSummary(summaryTable, S, fullfile(finalDir, "pathloss_parameter_mismatch_mae"));
end

function iPlotSummary(T, S, saveBase)
fig = figure("Color", "w", "Visible", "off", "Units", "pixels", "Position", [100 100 1100 440]);
tiledlayout(1,2,"TileSpacing","compact","Padding","compact");
names = ["alpha", "beta0"];
labels = ["Assumed $\widetilde{\alpha}$", "Assumed $\widetilde{\beta}_0$ (dB)"];
titles = ["(a) Path-loss exponent mismatch", "(b) Reference-gain mismatch"];
for i = 1:2
    nexttile; hold on; grid on; box on;
    Q = T(string(T.parameter) == names(i),:);
    switch lower(string(S.errorBar))
        case "ci95", err = Q.ci95Metric;
        case "sem", err = Q.semMetric;
        otherwise, err = Q.stdMetric;
    end
    errorbar(Q.value, Q.meanMetric, err, "-o", "LineWidth", 2.2, "MarkerSize", 8, ...
        "Color", [0.12 0.36 0.70], "MarkerFaceColor", "w", "CapSize", 8);
    xline(iNominalValue(S,names(i)), "--", "Nominal", "LabelVerticalAlignment", "bottom");
    xlabel(labels(i), "Interpreter", "latex"); ylabel("MAE (dB)"); title(titles(i));
    xticks(Q.value); set(gca,"FontName","Times New Roman","FontSize",14,"LineWidth",0.9);
end
exportgraphics(fig, string(saveBase)+".png", "Resolution", 300);
exportgraphics(fig, string(saveBase)+".pdf", "ContentType", "vector");
savefig(fig, string(saveBase)+".fig"); close(fig);
end

function value = iNominalValue(S, parameter)
if parameter == "alpha", value = S.nominalAlpha; else, value = S.nominalBeta0_dB; end
end
