% run_experiment.m (PROPAGATION ORDER ABLATION)
% Inputs injected by main_all_experiments: expRoot, seed

dataDir = fullfile(expRoot, "data");
responseDir = fullfile(dataDir, "responses");
outDir = fullfile(expRoot, "outputs");
originalDir = fullfile(outDir, "original");
finalDir = fullfile(outDir, "final");
dirs = {dataDir, responseDir, outDir, originalDir, finalDir};
for iDir = 1:numel(dirs), if ~isfolder(dirs{iDir}), mkdir(dirs{iDir}); end, end

cfg = jsondecode(fileread(fullfile(expRoot, "config.json")));
if isstruct(cfg.dataSetList), cfg.dataSetList = num2cell(cfg.dataSetList); end
settings = cfg.propagationSettings;
if iscell(settings), settings = [settings{:}]; end
assert(numel(settings) >= 2, "[PROP-ABLATION] At least two propagation settings are required.");
cleanCfg = iCleaningConfig(cfg);

params = iBaseParams(cfg, dataDir, expRoot);
envPlan = env.WirelessEnvironment(params);
envPlan.datasetScene("save");
fprintf("[PROP-ABLATION] Scene preparation complete.\n");

trainSpec = iDataSetSpec(cfg.dataSetList, "paired_train");
testSpec = iDataSetSpec(cfg.dataSetList, "paired_test");
planSpec = struct("trainNtSide", trainSpec.Nt_side, "trainNrSide", trainSpec.Nr_side, ...
    "testNtSide", testSpec.Nt_side, "testNrSide", testSpec.Nr_side, ...
    "pairOrder", "tx-major-v2", ...
    "trainSamplingMode", string(trainSpec.samplingMode), ...
    "testSamplingMode", string(testSpec.samplingMode), ...
    "trainSamplingArgs", trainSpec.samplingArgs, "testSamplingArgs", testSpec.samplingArgs);
planFile = fullfile(dataDir, sprintf("paired_sampling_seed%d.mat", seed));
reusePlan = false;
reuseTestPlan = false;
refreshPlanLabels = false;
if isfile(planFile)
    planVars = who("-file", planFile);
    if any(strcmp(planVars, "planSpec"))
        old = load(planFile, "planSpec");
        reusePlan = isequaln(old.planSpec, planSpec);
        if ~reusePlan && iPlanSpecMatchesExceptPairOrder(old.planSpec, planSpec)
            reusePlan = true;
            refreshPlanLabels = true;
        end
        if ~reusePlan && iTestPlanSpecMatches(old.planSpec, planSpec)
            reuseTestPlan = true;
        end
    end
end
if reusePlan
    fprintf("[PROP-ABLATION] Loading matched paired sampling plan: %s\n", planFile);
    S = load(planFile, "trainPlan", "testPlan", "losMask", "testPairs");
    trainPlan = S.trainPlan; testPlan = S.testPlan; losMask = S.losMask; testPairs = S.testPairs;
    if refreshPlanLabels
        fprintf("[PROP-ABLATION] Migrating cached sampling labels to TX-major pair order.\n");
        testPairs = iPairsFromPlan(testPlan);
        losMask = iLosMask(testPairs, params);
        save(planFile, "trainPlan", "testPlan", "testPairs", "losMask", "planSpec", "-v7.3");
    end
    fprintf("[PROP-ABLATION] Sampling plan loaded: %d train blocks, %d test blocks, %d test pairs.\n", ...
        numel(trainPlan), numel(testPlan), size(testPairs,1));
elseif reuseTestPlan
    fprintf("[PROP-ABLATION] Training sampling config changed; reusing matched test plan from: %s\n", planFile);
    S = load(planFile, "testPlan");
    testPlan = S.testPlan;
    testPairs = iPairsFromPlan(testPlan);
    losMask = iLosMask(testPairs, params);
    fprintf("[PROP-ABLATION] Rebuilding training sampling plan for seed %d.\n", seed);
    trainArgs = iSamplingArgs(trainSpec.samplingArgs);
    trainPlan = envPlan.datasetSampling(trainSpec.samplingMode, trainArgs{:});
    save(planFile, "trainPlan", "testPlan", "testPairs", "losMask", "planSpec", "-v7.3");
    fprintf("[PROP-ABLATION] Sampling plan updated: %d train blocks, %d test blocks, %d test pairs.\n", ...
        numel(trainPlan), numel(testPlan), size(testPairs,1));
else
    if isfile(planFile), fprintf("[PROP-ABLATION] Sampling config changed; rebuilding paired plan.\n"); end
    fprintf("[PROP-ABLATION] Building paired sampling plan for seed %d.\n", seed);
    trainArgs = iSamplingArgs(trainSpec.samplingArgs);
    testArgs = iSamplingArgs(testSpec.samplingArgs);
    trainPlan = envPlan.datasetSampling(trainSpec.samplingMode, trainArgs{:});
    testPlan = envPlan.datasetSampling(testSpec.samplingMode, testArgs{:});
    testPairs = iPairsFromPlan(testPlan);
    losMask = iLosMask(testPairs, params);
    save(planFile, "trainPlan", "testPlan", "testPairs", "losMask", "planSpec", "-v7.3");
    fprintf("[PROP-ABLATION] Sampling plan saved: %s\n", planFile);
end
assert(any(losMask) && any(~losMask), "[PROP-ABLATION] Test set must contain both LoS and NLoS pairs.");
fprintf("[PROP-ABLATION] LoS labels verified: %d LoS, %d NLoS.\n", nnz(losMask), nnz(~losMask));

rows = repmat(struct("Seed", seed, "Setting", "", "Group", "", "MAE_dB", NaN, "Count", 0), 3*numel(settings), 1);
rowIdx = 0;
cleanRows = repmat(struct("Seed", seed, "Setting", "", "Floor_mW", NaN, "Floor_dBm", NaN, ...
    "TrainRawNonpositive", 0, "TrainClipped", 0, "TrainCount", 0, ...
    "TestRawNonpositive", 0, "TestClipped", 0, "TestCount", 0), numel(settings), 1);
referencePairs = [];
referenceTrainPairs = [];
referenceTrainPower = [];
referenceTestPower = [];

for iSetting = 1:numel(settings)
    setting = settings(iSetting);
    key = string(setting.key);
    fprintf("[PROP-ABLATION] Starting setting %s (%dR/%dD).\n", ...
        key, setting.maxRef, setting.maxDif);
    p = params; p.maxRef = setting.maxRef; p.maxDif = setting.maxDif;
    trainFile = fullfile(dataDir, sprintf("train_%s_seed%d.mat", key, seed));
    testFile = fullfile(dataDir, sprintf("test_%s_seed%d.mat", key, seed));
    trainData = iLoadOrTrace(p, trainPlan, trainSpec, trainFile, cfg.backend.rayTracingBackend);
    testData = iLoadOrTrace(p, testPlan, testSpec, testFile, cfg.backend.rayTracingBackend);
    [trainData, testData, cleanRows(iSetting)] = iCleanPowerData(trainData, testData, cleanCfg, seed, key);

    if isempty(referencePairs)
        referencePairs = testData(:,1:2);
        referenceTrainPairs = trainData(:,1:2);
        referenceTrainPower = trainData(:,3);
        referenceTestPower = testData(:,3);
    end
    assert(isequal(referenceTrainPairs, trainData(:,1:2)), "[PROP-ABLATION] Training pairs differ between settings.");
    assert(isequal(referencePairs, testData(:,1:2)), "[PROP-ABLATION] Test pairs differ between settings.");
    assert(isequal(testPairs, testData(:,1:2)), "[PROP-ABLATION] Cached labels are not aligned with test data.");
    if iSetting > 1
        changedTrain = nnz(referenceTrainPower ~= trainData(:,3));
        changedTest = nnz(referenceTestPower ~= testData(:,3));
        assert(changedTrain > 0 && changedTest > 0, ...
            "[PROP-ABLATION] Propagation settings produced identical powers; check RT parameter forwarding.");
        fprintf("[PROP-ABLATION] Changed powers: train %d/%d, test %d/%d.\n", ...
            changedTrain, numel(referenceTrainPower), changedTest, numel(referenceTestPower));
    end

    h = cfg.models.VirtualScatter6D.hyper;
    p.responseFile = fullfile(responseDir, sprintf("response_%s_seed%d.mat", key, seed));
    ray = struct("trainSet", trainData, "testSet", testData);
    modelObj = model.VirtualScatter6D(p, "VirtualScatter6D", ray, ...
        "NumCenters", h.NumCenters, "PathLossExp", h.PathLossExp, ...
        "RefDistance", h.RefDistance, "EpsDist", h.EpsDist, "Solver", h.Solver);
    modelObj.train("mode", "save");
    eopt = struct("whichSet", "test", "doPdf", false, "doCgm", false, "doResidual", false);
    [P, ~, ~] = modelObj.evaluate(eopt, "");

    masks = {true(size(losMask)), losMask, ~losMask};
    groups = ["Overall", "LoS", "NLoS"];
    for iGroup = 1:3
        rowIdx = rowIdx + 1; mask = masks{iGroup} & P.valid;
        rows(rowIdx).Seed = seed;
        rows(rowIdx).Setting = char(key);
        rows(rowIdx).Group = char(groups(iGroup));
        rows(rowIdx).MAE_dB = mean(abs(P.err_dB(mask)), "omitnan");
        rows(rowIdx).Count = nnz(mask);
    end
end

rawTable = struct2table(rows);
cleaningTable = struct2table(cleanRows);
rawCsv = fullfile(originalDir, sprintf("propagation_order_raw_seed%d.csv", seed));
rawMat = fullfile(originalDir, sprintf("propagation_order_raw_seed%d.mat", seed));
writetable(rawTable, rawCsv);
writetable(cleaningTable, fullfile(originalDir, sprintf("propagation_order_cleaning_seed%d.csv", seed)));
save(rawMat, "rawTable", "cleaningTable", "losMask", "testPairs");
iAggregateAndPlot(originalDir, finalDir, settings);
fprintf("[PROP-ABLATION] Completed paired seed %d. Raw metrics: %s\n", seed, rawCsv);

function params = iBaseParams(cfg, dataDir, expRoot)
params = struct("condaEnv", string(cfg.backend.condaEnv), ...
    "sionnaModule", fullfile(expRoot, string(cfg.backend.sionnaModule)), ...
    "rayTracingBackend", string(cfg.backend.rayTracingBackend), ...
    "fc", cfg.radio.fc, "Pt_dBm", cfg.radio.Pt_dBm, ...
    "areaSize", cfg.grid.areaSize, "gridSize", cfg.grid.gridSize, ...
    "tx_pos_z", cfg.grid.tx_pos_z, "rx_pos_z", cfg.grid.rx_pos_z);
params.scatterTable = cfg.scenes.dense.scatterTable;
params.useGPU = false;
if isfield(cfg.backend, "useGPU"), params.useGPU = logical(cfg.backend.useGPU); end
params.stlFile = fullfile(dataDir, "scene_dense.stl");
params.plyFile = fullfile(dataDir, "scene_dense.ply");
params.xmlFile = fullfile(dataDir, "scene_dense.xml");
end

function spec = iDataSetSpec(list, name)
for i = 1:numel(list)
    if string(list{i}.name) == string(name), spec = list{i}; return; end
end
error("[PROP-ABLATION] Dataset spec not found: %s", name);
end

function args = iSamplingArgs(s)
names = fieldnames(s); args = cell(1, 2*numel(names));
for i = 1:numel(names)
    value = s.(names{i});
    if strcmp(names{i}, "rxNum") && value < 0, value = inf; end
    args{2*i-1} = names{i}; args{2*i} = value;
end
end

function tf = iPlanSpecMatchesExceptPairOrder(oldSpec, newSpec)
if isfield(oldSpec, "pairOrder"), oldSpec = rmfield(oldSpec, "pairOrder"); end
if isfield(newSpec, "pairOrder"), newSpec = rmfield(newSpec, "pairOrder"); end
tf = isequaln(oldSpec, newSpec);
end

function tf = iTestPlanSpecMatches(oldSpec, newSpec)
fields = ["testNtSide", "testNrSide", "testSamplingMode", "testSamplingArgs"];
tf = true;
for i = 1:numel(fields)
    f = fields(i);
    if ~isfield(oldSpec, f) || ~isfield(newSpec, f) || ~isequaln(oldSpec.(f), newSpec.(f))
        tf = false;
        return;
    end
end
end

function cleanCfg = iCleaningConfig(cfg)
cleanCfg = struct("enabled", true, "method", "quantile_floor", ...
    "floor_dBm", NaN, "q", 0.017, "eps_min_mW", 1e-12);
if isfield(cfg, "dataCleaning")
    userCfg = cfg.dataCleaning;
    if isfield(userCfg, "enabled"), cleanCfg.enabled = logical(userCfg.enabled); end
    if isfield(userCfg, "method"), cleanCfg.method = string(userCfg.method); end
    if isfield(userCfg, "floor_dBm"), cleanCfg.floor_dBm = userCfg.floor_dBm; end
    if isfield(userCfg, "q"), cleanCfg.q = userCfg.q; end
    if isfield(userCfg, "eps_min_mW"), cleanCfg.eps_min_mW = userCfg.eps_min_mW; end
end
end

function [trainData, testData, stats] = iCleanPowerData(trainData, testData, cleanCfg, seed, key)
stats = struct("Seed", seed, "Setting", char(key), "Floor_mW", NaN, "Floor_dBm", NaN, ...
    "TrainRawNonpositive", 0, "TrainClipped", 0, "TrainCount", size(trainData,1), ...
    "TestRawNonpositive", 0, "TestClipped", 0, "TestCount", size(testData,1));
if ~cleanCfg.enabled
    return;
end
if lower(string(cleanCfg.method)) == "fixed_floor" && isfinite(cleanCfg.floor_dBm)
    floorMw = max(10.^(cleanCfg.floor_dBm/10), cleanCfg.eps_min_mW);
else
    allPower = [trainData(:,3); testData(:,3)];
    positive = allPower(isfinite(allPower) & allPower > 0);
    if isempty(positive)
        floorMw = cleanCfg.eps_min_mW;
    else
        floorMw = max(quantile(positive, cleanCfg.q), cleanCfg.eps_min_mW);
    end
end
stats.Floor_mW = floorMw;
stats.Floor_dBm = 10*log10(floorMw);
[trainData(:,3), stats.TrainRawNonpositive, stats.TrainClipped] = iClipPowerVector(trainData(:,3), floorMw);
[testData(:,3), stats.TestRawNonpositive, stats.TestClipped] = iClipPowerVector(testData(:,3), floorMw);
fprintf("[PROP-ABLATION] Cleaning %s: floor=%.3e mW (%.2f dBm), train clipped %d/%d, test clipped %d/%d.\n", ...
    key, stats.Floor_mW, stats.Floor_dBm, stats.TrainClipped, stats.TrainCount, stats.TestClipped, stats.TestCount);
end

function [y, nRawNonpositive, nClipped] = iClipPowerVector(y, floorMw)
rawBad = ~isfinite(y) | y <= 0;
nRawNonpositive = nnz(rawBad);
y(rawBad) = floorMw;
clipMask = y < floorMw;
nClipped = nRawNonpositive + nnz(clipMask);
y(clipMask) = floorMw;
end

function data = iLoadOrTrace(p, plan, spec, filePath, backend)
rtSpec = struct("maxRef", p.maxRef, "maxDif", p.maxDif, ...
    "backend", string(backend), "useGPU", p.useGPU, ...
    "NtSide", spec.Nt_side, "NrSide", spec.Nr_side);
expectedPairs = iPairsFromPlan(plan);
if isfile(filePath)
    cachedVars = who("-file", filePath);
    if any(strcmp(cachedVars, "rtSpec"))
        cached = load(filePath, "rtSpec");
        if isequal(cached.rtSpec, rtSpec)
            S = load(filePath, "Results");
            if isequal(S.Results(:,1:2), expectedPairs)
                data = S.Results;
                return;
            end
            fprintf("[PROP-ABLATION] Rebuilding RT cache with stale TX-RX pairs: %s\n", filePath);
        end
    end
    fprintf("[PROP-ABLATION] Rebuilding stale RT cache: %s\n", filePath);
end
assert(lower(string(backend)) == "matlab", ...
    "[PROP-ABLATION] The experiment-local isolated tracer currently supports the MATLAB backend only.");
data = iTracePlanMatlab(p, plan, spec.Nt_side, spec.Nr_side);
Results = data;
save(filePath, "Results", "rtSpec", "-v7.3");
end

function Results = iTracePlanMatlab(p, plan, NtSide, NrSide)
fprintf("[PROP-ABLATION] Initializing hidden site viewer (CPU/GPU setup follows).\n");
viewer = siteviewer("SceneModel", p.stlFile, "Visible", "off");
fprintf("[PROP-ABLATION] Site viewer initialized.\n");
useGpuValue = "off";
if p.useGPU, useGpuValue = "on"; end
pm = propagationModel("raytracing", "Method", "sbr", ...
    "CoordinateSystem", "cartesian", "MaxNumReflections", p.maxRef, ...
    "MaxNumDiffractions", p.maxDif, "SurfaceMaterial", "concrete", ...
    "UseGPU", useGpuValue);
fprintf("[PROP-ABLATION] Propagation model initialized: %dR/%dD, UseGPU=%s.\n", ...
    p.maxRef, p.maxDif, useGpuValue);
Results = zeros(0,3);
cleanup = onCleanup(@() close(viewer));
for b = 1:numel(plan)
    txSel = plan(b).txSel(:); rxSel = plan(b).rxSel(:);
    if isempty(txSel) || isempty(rxSel), continue; end
    numPairs = numel(txSel)*numel(rxSel); pairIdx = 0;
    fprintf("[PROP-ABLATION] RT block %d/%d: ref=%d dif=%d, %d grid pairs.\n", ...
        b, numel(plan), p.maxRef, p.maxDif, numPairs);
    for iTx = 1:numel(txSel)
        for iRx = 1:numel(rxSel)
            pairIdx = pairIdx+1;
            if txSel(iTx) == rxSel(iRx), continue; end
            [txPos, rxPos] = iExpandGridSamples(p, txSel(iTx), rxSel(iRx), NtSide, NrSide);
            fprintf("  pair %d/%d (TX grid %d, RX grid %d)\n", ...
                pairIdx, numPairs, txSel(iTx), rxSel(iRx));
            txSites = txsite("cartesian", "AntennaPosition", txPos, ...
                "TransmitterFrequency", p.fc, "TransmitterPower", 10.^((p.Pt_dBm-30)/10));
            rxSites = rxsite("cartesian", "AntennaPosition", rxPos);
            powerDbm = sigstrength(rxSites, txSites, pm, "Map", viewer);
            avgPowerMw = mean(10.^(powerDbm(:)/10), "omitnan");
            Results = [Results; txSel(iTx),rxSel(iRx),avgPowerMw]; %#ok<AGROW>
        end
    end
end
Results(Results(:,1)==Results(:,2),:) = [];
[~,ia] = unique(Results(:,1:2),"rows","stable"); Results = Results(ia,:);
end

function [txPos, rxPos, meta] = iExpandGridSamples(p, txIdx, rxIdx, NtSide, NrSide)
Kx = floor(p.areaSize(1)/p.gridSize); Ky = floor(p.areaSize(2)/p.gridSize);
[ty,tx] = ind2sub([Ky,Kx],txIdx); [ry,rx] = ind2sub([Ky,Kx],rxIdx);
txCenter = [(-p.areaSize(1)/2+p.gridSize/2)+p.gridSize*(tx-1), ...
    (-p.areaSize(2)/2+p.gridSize/2)+p.gridSize*(ty-1)];
rxCenter = [(-p.areaSize(1)/2+p.gridSize/2)+p.gridSize*(rx-1), ...
    (-p.areaSize(2)/2+p.gridSize/2)+p.gridSize*(ry-1)];
txOffset = ((1:NtSide)-(NtSide+1)/2)*(p.gridSize/NtSide);
rxOffset = ((1:NrSide)-(NrSide+1)/2)*(p.gridSize/NrSide);
[dx,dy] = meshgrid(txOffset,txOffset); txDelta = [dx(:),dy(:)];
[dx,dy] = meshgrid(rxOffset,rxOffset); rxDelta = [dx(:),dy(:)];
NsTx = size(txDelta,1); NsRx = size(rxDelta,1);
txSamples = kron(txCenter,ones(NsTx,1))+repmat(txDelta,numel(txIdx),1);
rxSamples = kron(rxCenter,ones(NsRx,1))+repmat(rxDelta,numel(rxIdx),1);
txPos = [txSamples,repmat(p.tx_pos_z,size(txSamples,1),1)].';
rxPos = [rxSamples,repmat(p.rx_pos_z,size(rxSamples,1),1)].';
meta = struct("Ntx",numel(txIdx),"Nrx",numel(rxIdx),"NsTx",NsTx,"NsRx",NsRx);
end

function pairs = iPairsFromPlan(plan)
pairs = zeros(0,2);
for b = 1:numel(plan)
    txSel = plan(b).txSel(:);
    rxSel = plan(b).rxSel(:);
    tx = repelem(txSel, numel(rxSel));
    rx = repmat(rxSel, numel(txSel), 1);
    pairs = [pairs; tx, rx]; %#ok<AGROW>
end
pairs(pairs(:,1) == pairs(:,2), :) = [];
[~, ia] = unique(pairs, "rows", "stable"); pairs = pairs(ia,:);
end

function mask = iLosMask(pairs, p)
tx = iGridPosition(pairs(:,1), p, p.tx_pos_z);
rx = iGridPosition(pairs(:,2), p, p.rx_pos_z);
mask = true(size(pairs,1),1);
for i = 1:size(p.scatterTable,1)
    lo = p.scatterTable(i,1:3); hi = lo + p.scatterTable(i,4:6);
    mask = mask & ~iSegmentHitsBox(tx, rx, lo, hi);
end
end

function xyz = iGridPosition(idx, p, z)
Kx = floor(p.areaSize(1)/p.gridSize); Ky = floor(p.areaSize(2)/p.gridSize);
[row,col] = ind2sub([Ky,Kx], idx);
xyz = [(col(:)-(Kx+1)/2)*p.gridSize, (row(:)-(Ky+1)/2)*p.gridSize, repmat(z,numel(idx),1)];
end

function hit = iSegmentHitsBox(a, b, lo, hi)
d = b-a; t0 = zeros(size(a,1),1); t1 = ones(size(a,1),1); hit = true(size(t0));
for k = 1:3
    parallel = abs(d(:,k)) < 1e-12;
    hit = hit & ~(parallel & (a(:,k) < lo(k) | a(:,k) > hi(k)));
    q1 = (lo(k)-a(:,k))./d(:,k); q2 = (hi(k)-a(:,k))./d(:,k);
    q1(parallel) = -inf; q2(parallel) = inf;
    t0 = max(t0, min(q1,q2)); t1 = min(t1, max(q1,q2));
end
hit = hit & t0 <= t1 & t1 > 0 & t0 < 1;
end

function iAggregateAndPlot(originalDir, finalDir, settings)
files = dir(fullfile(originalDir, "propagation_order_raw_seed*.csv"));
allT = table();
for i = 1:numel(files), allT = [allT; readtable(fullfile(files(i).folder, files(i).name))]; end %#ok<AGROW>
groups = ["Overall","LoS","NLoS"]; keys = string({settings.key});
nSettings = numel(keys);
summary = table(); meanMae = nan(3,nSettings); stdMae = nan(3,nSettings);
for g = 1:3
    for s = 1:nSettings
        take = string(allT.Group)==groups(g) & string(allT.Setting)==keys(s);
        vals = allT.MAE_dB(take); n = numel(vals);
        meanMae(g,s)=mean(vals,"omitnan"); stdMae(g,s)=std(vals,"omitnan");
        summary = [summary; table(groups(g),keys(s),meanMae(g,s),stdMae(g,s),n, ...
            'VariableNames',{'Group','Setting','Mean_MAE_dB','Std_MAE_dB','NumSeeds'})]; %#ok<AGROW>
    end
end
writetable(summary, fullfile(finalDir,"propagation_order_summary.csv"));
save(fullfile(finalDir,"propagation_order_summary.mat"),"summary","allT");
fig = figure("Visible","off","Color","w","Position",[100 100 720 440]);
bh = bar(meanMae,"grouped"); hold on;
for s = 1:nSettings
    x = bh(s).XEndPoints; errorbar(x,meanMae(:,s),stdMae(:,s),"k","LineStyle","none","LineWidth",1);
end
set(gca,"XTickLabel",groups); ylabel("MAE (dB)"); grid on; box on;
legend(string({settings.displayName}),"Location","best");
exportgraphics(fig,fullfile(finalDir,"propagation_order_mae.png"),"Resolution",300);
exportgraphics(fig,fullfile(finalDir,"propagation_order_mae.pdf"),"ContentType","vector");
savefig(fig,fullfile(finalDir,"propagation_order_mae.fig")); close(fig);
end
