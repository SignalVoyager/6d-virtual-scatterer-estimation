% run_experiment.m (ENVIRONMENT TOP VIEW)
% Inputs injected by main_all_experiments.m: expRoot, seed

dataDir = fullfile(expRoot, "data");
outDir  = fullfile(expRoot, "outputs");
logDir = fullfile(outDir, "logs");
originalDir = fullfile(outDir, "original");
finalDir = fullfile(outDir, "final");
if ~isfolder(dataDir), mkdir(dataDir); end
if ~isfolder(outDir),  mkdir(outDir);  end
if ~isfolder(logDir), mkdir(logDir); end
if ~isfolder(originalDir), mkdir(originalDir); end
if ~isfolder(finalDir), mkdir(finalDir); end

cfg = jsondecode(fileread(fullfile(expRoot, "config.json")));
P = cfg.plot;
sceneList = string(P.sceneList);
if isempty(sceneList)
    sceneList = string(fieldnames(cfg.scenes));
end

for iScene = 1:numel(sceneList)
    sceneKey = sceneList(iScene);
    if ~isfield(cfg.scenes, char(sceneKey))
        error("[TOPVIEW] Scene %s not found in cfg.scenes.", sceneKey);
    end

    scene = cfg.scenes.(char(sceneKey));
    scatterTable = scene.scatterTable;
    saveBase = fullfile(finalDir, "env_topview_" + sceneKey);

    fig = iPlotTopView(scatterTable, P, char(sceneKey));
    iSaveFigure(fig, saveBase, P);

    if isfield(cfg.runtime, "showFigures") && logical(cfg.runtime.showFigures)
        set(fig, "Visible", "on");
    else
        close(fig);
    end
    fprintf("[TOPVIEW] Saved %s.[%s]\n", saveBase, strjoin(string(P.formats), "|"));
end

function fig = iPlotTopView(scatterTable, P, sceneName)
xyLim = P.xyLim;
xyMin = xyLim(1);
xyMax = xyLim(2);
figSize = P.figureSize;
showLabels = logical(P.showLabels);
showCentroids = logical(P.showCentroids);

x0 = scatterTable(:, 1);
y0 = scatterTable(:, 2);
dx = scatterTable(:, 4);
dy = scatterTable(:, 5);
height = scatterTable(:, 6);
centroidX = x0 + dx / 2;
centroidY = y0 + dy / 2;

fig = figure("Color", "w", "Position", [100, 100, figSize(1), figSize(2)], "Visible", "off");
set(fig, "DefaultTextInterpreter", "latex");
set(fig, "DefaultLegendInterpreter", "latex");
ax = axes(fig);
hold(ax, "on");
axis(ax, "equal");
box(ax, "on");

ax.XLim = [xyMin, xyMax];
ax.YLim = [xyMin, xyMax];
ax.FontName = "Times New Roman";
ax.FontSize = 15;
ax.LineWidth = 0.9;
ax.Layer = "top";
ax.TickLabelInterpreter = "latex";
grid(ax, "on");
ax.GridAlpha = 0.12;
ax.MinorGridAlpha = 0.08;
ax.XMinorGrid = "on";
ax.YMinorGrid = "on";

cmap = iPaperColormap(256);
colormap(ax, cmap);
if min(height) == max(height)
    clim(ax, [height(1)-0.5, height(1)+0.5]);
else
    clim(ax, [min(height), max(height)]);
end

rectangle(ax, ...
    "Position", [xyMin, xyMin, xyMax - xyMin, xyMax - xyMin], ...
    "LineStyle", "--", ...
    "EdgeColor", [0.38, 0.38, 0.38], ...
    "LineWidth", 1.0);

for n = 1:size(scatterTable, 1)
    faceColor = interp1(linspace(min(height), max(height), 256), cmap, height(n), "linear", "extrap");
    rectangle(ax, ...
        "Position", [x0(n), y0(n), dx(n), dy(n)], ...
        "FaceColor", faceColor, ...
        "EdgeColor", [0.30, 0.34, 0.36], ...
        "LineWidth", 0.8, ...
        "Curvature", 0.03);
end

if showCentroids
    scatter(ax, centroidX, centroidY, 28, "k", "filled", ...
        "MarkerEdgeColor", "w", "LineWidth", 0.45);
end

if showLabels
    for n = 1:numel(centroidX)
        text(ax, centroidX(n) + 2.5, centroidY(n) + 2.0, sprintf("$s_{%d}$", n), ...
            "Interpreter", "latex", ...
            "FontSize", 22, ...
            "FontWeight", "bold", ...
            "Color", [0.08, 0.08, 0.08]);
    end
end

xlabel(ax, "$x$ (m)", "Interpreter", "latex", "FontSize", 20);
ylabel(ax, "$y$ (m)", "Interpreter", "latex", "FontSize", 20);
title(ax, string(sceneName), "Interpreter", "latex", "FontWeight", "normal");
cb = colorbar(ax);
cb.Label.String = "Building height (m)";
cb.Label.Interpreter = "latex";
cb.Label.FontName = "Times New Roman";
cb.Label.FontSize = 18;
cb.FontName = "Times New Roman";
cb.FontSize = 15;
cb.TickLabelInterpreter = "latex";
end

function iSaveFigure(fig, saveBase, P)
formats = lower(string(P.formats));
for i = 1:numel(formats)
    switch formats(i)
        case "png"
            exportgraphics(fig, saveBase + ".png", "Resolution", P.pngResolution);
        case "pdf"
            exportgraphics(fig, saveBase + ".pdf", "ContentType", "vector");
        case "fig"
            savefig(fig, saveBase + ".fig");
        otherwise
            warning("[TOPVIEW] Unsupported output format: %s", formats(i));
    end
end
end

function cmap = iPaperColormap(n)
anchors = [
    0.89, 0.96, 0.98
    0.70, 0.88, 0.93
    0.35, 0.70, 0.90
    0.00, 0.45, 0.70
    0.93, 0.78, 0.48
    0.84, 0.37, 0.00
];
x = linspace(0, 1, size(anchors, 1));
xi = linspace(0, 1, n);
cmap = interp1(x, anchors, xi, "linear");
cmap = min(max(cmap, 0), 1);
end
