% refresh_final_panel - Recompose the exp01 final panel from existing FIG sources.
%
% This does not regenerate datasets, retrain, or rerun ray tracing.

function refresh_final_panel(seed)
if nargin < 1 || isempty(seed), seed = 521; end

expRoot = fileparts(mfilename('fullpath'));
cfg = jsondecode(fileread(fullfile(expRoot, "config.json")));
outDir = fullfile(expRoot, "outputs");
originalDir = fullfile(outDir, "original");
finalDir = fullfile(outDir, "final");

E = cfg.modelEvaluation;
params = struct();
params.areaSize = cfg.grid.areaSize;
params.gridSize = cfg.grid.gridSize;
params.tx_pos_z = cfg.grid.tx_pos_z;

composePanel(originalDir, finalDir, string(cfg.models.activeModel), seed, ...
    string(E.cgmSliceMode), E.cgmGridList, params);
end

function composePanel(originalDir, finalDir, modelKey, seed, cgmSliceMode, cgmGridList, params)
[figFiles, panelTitles] = collectSources(originalDir, modelKey, seed, cgmSliceMode, cgmGridList, params);
globalClim = [-125, -35];

if ~isfolder(finalDir), mkdir(finalDir); end
delete(fullfile(finalDir, "panel_composed_2x4.*"));

panelFig = figure("Color", "w", "Units", "pixels", ...
    "Position", [100, 100, 2800, 1380], "Visible", "off");
set(panelFig, "DefaultTextInterpreter", "latex");
set(panelFig, "DefaultLegendInterpreter", "latex");
tileAxes = gobjects(numel(figFiles), 1);
left = 0.070;
gapX = 0.022;
axW = 0.185;
axH = 0.330;
topY = 0.555;
botY = 0.150;

for i = 1:numel(figFiles)
    srcFig = openfig(figFiles(i), "invisible");
    srcAx = findDataAxis(srcFig);
    col = mod(i - 1, 4);
    rowY = topY;
    if i > 4, rowY = botY; end
    dstAx = axes("Parent", panelFig, "Units", "normalized", ...
        "Position", [left + col * (axW + gapX), rowY, axW, axH]);
    tileAxes(i) = dstAx;
    copyobj(allchild(srcAx), dstAx);
    copyAxisProperties(srcAx, dstAx);
    dstAx.CLim = globalClim;
    styleCopiedAnnotations(dstAx);
    title(dstAx, panelTitles(i), "Interpreter", "latex", ...
        "FontWeight", "normal", "FontSize", 28);
    if i <= 4
        xlabel(dstAx, "");
        dstAx.XTickLabel = [];
    else
        xlabel(dstAx, "$x$ (m)", "Interpreter", "latex", "FontSize", 28);
    end
    if mod(i - 1, 4) == 0
        ylabel(dstAx, "$y$ (m)", "Interpreter", "latex", "FontSize", 28);
    else
        ylabel(dstAx, "");
        dstAx.YTickLabel = [];
    end
    set(dstAx, "FontName", "Times New Roman", "FontSize", 24);
    dstAx.TickLabelInterpreter = "latex";
    dstAx.XTickLabelRotation = 0;
    dstAx.YTickLabelRotation = 0;
    colorbar(dstAx, "off");
    close(srcFig);
end

cbAx = axes("Parent", panelFig, "Units", "normalized", ...
    "Position", [0.896, 0.150, 0.010, 0.735], "Visible", "off");
colormap(cbAx, colormap(tileAxes(end)));
clim(cbAx, globalClim);
cb = colorbar(cbAx, "eastoutside");
cb.Units = "normalized";
cb.Position = [0.901, 0.150, 0.012, 0.735];
cb.FontSize = 24;
cb.FontName = "Times New Roman";
cb.TickLabelInterpreter = "latex";
cb.Label.String = "Received power (dBm)";
cb.Label.Interpreter = "latex";
cb.Label.FontSize = 28;
cb.Label.FontName = "Times New Roman";

outBase = fullfile(finalDir, "panel_composed_2x4");
exportgraphics(panelFig, outBase + ".png", "Resolution", 300);
savefig(panelFig, outBase + ".fig");
close(panelFig);
fprintf("[SHOWCASE] refreshed final panel: %s.[png|fig]\n", outBase);
end

function [figFiles, titles] = collectSources(originalDir, modelKey, seed, cgmSliceMode, cgmGridList, params)
numPanels = 4;
figFiles = strings(numPanels * 2, 1);
titles = strings(numPanels * 2, 1);
modelDir = fullfile(originalDir, "model", sprintf("%s_%s_seed%d", char(modelKey), char(cgmSliceMode), seed));
truthDir = fullfile(originalDir, "env", "cgm_raytrace");

for k = 1:numPanels
    figFiles(k) = fullfile(modelDir, sprintf("cgm_%s_grid%d.fig", char(cgmSliceMode), k));
    figFiles(k + numPanels) = fullfile(truthDir, ...
        sprintf("env_cgmRaytrace_%s_grid%d_seed%d.fig", char(cgmSliceMode), k, seed));
    txTitle = formatTxTitle(cgmGridList(k, :), params);
    titles(k) = sprintf("(%s) Proposed X2X CGM\n%s", alphabeticalLabel(k), txTitle);
    titles(k + numPanels) = sprintf("(%s) Ground truth\n%s", alphabeticalLabel(k + numPanels), txTitle);
end
end

function label = alphabeticalLabel(idx)
letters = 'abcdefghijklmnopqrstuvwxyz';
label = letters(idx);
end

function txTitle = formatTxTitle(gridCR, params)
areaSize = params.areaSize;
gridSize = params.gridSize;
Kx = floor(areaSize(1) / gridSize);
Ky = floor(areaSize(2) / gridSize);
x = ((gridCR(1) - (Kx + 1) / 2) * gridSize);
y = ((gridCR(2) - (Ky + 1) / 2) * gridSize);
z = params.tx_pos_z;
txTitle = sprintf("TX (%.1f, %.1f, %.1f) m", x, y, z);
end

function clim = resolveGlobalClim(figFiles)
clim = [inf, -inf];
for i = 1:numel(figFiles)
    srcFig = openfig(figFiles(i), "invisible");
    srcAx = findDataAxis(srcFig);
    srcClim = srcAx.CLim;
    if any(~isfinite(srcClim)) || srcClim(1) >= srcClim(2)
        srcClim = finiteImageClim(srcAx);
    end
    clim(1) = min(clim(1), srcClim(1));
    clim(2) = max(clim(2), srcClim(2));
    close(srcFig);
end
end

function dataClim = finiteImageClim(ax)
imgs = findobj(ax, "Type", "image");
vals = [];
for i = 1:numel(imgs)
    c = imgs(i).CData;
    vals = [vals; c(isfinite(c))]; %#ok<AGROW>
end
if isempty(vals)
    error("[SHOWCASE] Cannot resolve finite image color range.");
end
dataClim = [min(vals), max(vals)];
if dataClim(1) >= dataClim(2)
    dataClim = dataClim + [-0.5, 0.5];
end
end

function ax = findDataAxis(figHandle)
axesList = findobj(figHandle, "Type", "axes");
ax = gobjects(0);
bestArea = -inf;
for k = 1:numel(axesList)
    if ~isempty(findobj(axesList(k), "Type", "image")) || ...
            ~isempty(findobj(axesList(k), "Type", "surface"))
        pos = axesList(k).Position;
        area = pos(3) * pos(4);
        if area > bestArea
            bestArea = area;
            ax = axesList(k);
        end
    end
end
if isempty(ax)
    ax = axesList(end);
end
end

function copyAxisProperties(srcAx, dstAx)
dstAx.XLim = srcAx.XLim;
dstAx.YLim = srcAx.YLim;
dstAx.CLim = srcAx.CLim;
dstAx.YDir = srcAx.YDir;
dstAx.Box = srcAx.Box;
dstAx.Layer = srcAx.Layer;
dstAx.XTick = srcAx.XTick;
dstAx.YTick = srcAx.YTick;
colormap(dstAx, iSoftRygbColormap(256));
axis(dstAx, "equal");
axis(dstAx, "tight");
end

function styleCopiedAnnotations(ax)
txt = findobj(ax, "Type", "text");
if ~isempty(txt)
    set(txt, "FontSize", 14, "Color", [0.80, 0.22, 0.17], "FontWeight", "bold");
end
end

function cmap = iSoftRygbColormap(n)
anchors = [
    0.30, 0.55, 0.78
    0.42, 0.72, 0.72
    0.70, 0.84, 0.60
    0.96, 0.88, 0.58
    0.93, 0.66, 0.42
    0.77, 0.33, 0.30
];
x = linspace(0, 1, size(anchors, 1));
xi = linspace(0, 1, n);
cmap = interp1(x, anchors, xi, "linear");
cmap = 0.88 * cmap + 0.12;
cmap = min(max(cmap, 0), 1);
end
