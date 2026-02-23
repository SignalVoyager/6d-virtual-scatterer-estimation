function compose_figure_panel()
% compose_figure_panel
% Batch-compose panel figures from subfolders under src/+utils/selected_figs.
% Each subfolder is processed independently and outputs are saved back
% into the same subfolder.

cfg = struct();
cfg.rootDir = fullfile("src", "+utils", "selected_figs");
cfg.targetSubfolders = strings(0, 1); % empty => process all subfolders
cfg.fileOrder = strings(0, 1); % optional order within each subfolder
cfg.outputName = "panel_composed";

% If cfg.layout is empty, layout is auto-computed per subfolder.
cfg.layout = [];
cfg.defaultRows = 1;
cfg.tileSpacing = "compact";
cfg.padding = "compact";

cfg.fontName = "Times New Roman";
cfg.fontSize = 12;
cfg.lineWidth = 1.2;
cfg.axisLabelInterpreter = "latex"; % "none" | "tex" | "latex"
cfg.legendInterpreter = "latex";    % "none" | "tex" | "latex"
cfg.titleInterpreter = "latex";     % "none" | "tex" | "latex"

% legendMode: "none" | "first" | "all" | "global"
cfg.legendMode = "global";
cfg.globalLegendLocation = "southoutside";
cfg.globalLegendOrientation = "horizontal";

% panelLabelMode: "none" | "alphabetical"
cfg.panelLabelMode = "alphabetical";
cfg.panelLabelFormat = "(%s)"; % e.g., "(a)"
cfg.panelLabelPosition = [0.02, 0.98]; % normalized in each axis
cfg.panelLabelFontSize = 13;

cfg.savePng = true;
cfg.saveFig = true;
cfg.pngResolution = 300;

% openMode: "none" | "last" | "all"
cfg.openMode = "last";

if ~isfolder(cfg.rootDir)
    error("compose_figure_panel:RootDirMissing", ...
        "Root directory does not exist: %s", cfg.rootDir);
end

subDirs = listTargetSubfolders(cfg.rootDir, cfg.targetSubfolders);
if isempty(subDirs)
    error("compose_figure_panel:NoSubfolders", ...
        "No subfolders found under %s", cfg.rootDir);
end

lastPanelFig = gobjects(0);
for s = 1:numel(subDirs)
    subDir = subDirs(s);
    figList = collectFigList(subDir, cfg.fileOrder);
    if isempty(figList)
        warning("compose_figure_panel:NoFigFiles", ...
            "Skip %s (no .fig files).", subDir);
        continue;
    end

    panelFig = composeOneFolder(figList, cfg, subDir);
    lastPanelFig = panelFig;
end

switch lower(string(cfg.openMode))
    case "none"
    case "last"
        if ~isempty(lastPanelFig) && isgraphics(lastPanelFig)
            set(lastPanelFig, "Visible", "on");
            figure(lastPanelFig);
        end
    case "all"
        allPanels = findall(0, "Type", "figure", "Tag", "compose_figure_panel_output");
        for i = 1:numel(allPanels)
            set(allPanels(i), "Visible", "on");
            figure(allPanels(i));
        end
    otherwise
        warning("compose_figure_panel:UnknownOpenMode", ...
            "Unknown openMode=%s, fallback to 'last'.", cfg.openMode);
        if ~isempty(lastPanelFig) && isgraphics(lastPanelFig)
            set(lastPanelFig, "Visible", "on");
            figure(lastPanelFig);
        end
end

fprintf("[compose_figure_panel] done. root=%s, subfolders=%d\n", cfg.rootDir, numel(subDirs));
end

function panelFig = composeOneFolder(figList, cfg, subDir)
numPanels = numel(figList);
[nRows, nCols] = resolveLayout(cfg.layout, cfg.defaultRows, numPanels);

panelFig = figure("Color", "w", "Visible", "off", "Tag", "compose_figure_panel_output");
t = tiledlayout(panelFig, nRows, nCols, ...
    "TileSpacing", cfg.tileSpacing, ...
    "Padding", cfg.padding);

globalLegendHandles = gobjects(0);
globalLegendLabels = strings(0, 1);

for i = 1:numPanels
    srcFig = openfig(figList(i), "invisible");
    srcAx = findobj(srcFig, "Type", "axes", "-not", "Tag", "legend", "-not", "Tag", "Colorbar");
    if isempty(srcAx)
        close(srcFig);
        warning("compose_figure_panel:NoAxes", "Skip %s (no axes found).", figList(i));
        continue;
    end

    srcAx = srcAx(end);
    dstAx = nexttile(t, i);
    copyobj(allchild(srcAx), dstAx);

    applyAxisStyle(dstAx, srcAx, cfg);
    applyTitle(dstAx, figList(i), i, cfg);
    applyLegendPerAxis(dstAx, cfg.legendMode, i, cfg);

    if strcmpi(cfg.legendMode, "global") && isempty(globalLegendHandles)
        [globalLegendHandles, globalLegendLabels] = collectLegendItems(dstAx);
    end
    close(srcFig);
end

if strcmpi(cfg.legendMode, "global") && ~isempty(globalLegendHandles)
    legend(t, globalLegendHandles, globalLegendLabels, ...
        "Location", cfg.globalLegendLocation, ...
        "Orientation", cfg.globalLegendOrientation, ...
        "Interpreter", cfg.legendInterpreter);
end

outBase = fullfile(subDir, cfg.outputName);
if cfg.savePng
    exportgraphics(panelFig, outBase + ".png", "Resolution", cfg.pngResolution);
end
if cfg.saveFig
    savefig(panelFig, outBase + ".fig");
end

fprintf("[compose_figure_panel] subfolder=%s, panels=%d, output=%s\n", subDir, numPanels, outBase);
end

function subDirs = listTargetSubfolders(rootDir, targetSubfolders)
d = dir(rootDir);
d = d([d.isdir]);
names = string({d.name});
names = names(~ismember(names, [".", ".."]));

if isempty(targetSubfolders)
    pick = names;
else
    req = string(targetSubfolders(:));
    pick = strings(0, 1);
    for i = 1:numel(req)
        hit = find(strcmpi(names, req(i)), 1);
        if isempty(hit)
            warning("compose_figure_panel:SubfolderMissing", ...
                "targetSubfolders item not found: %s", req(i));
        else
            pick(end+1, 1) = names(hit); %#ok<AGROW>
        end
    end
end

subDirs = fullfile(rootDir, pick);
subDirs = subDirs(:);
end

function figList = collectFigList(sourceDir, fileOrder)
figFiles = dir(fullfile(sourceDir, "*.fig"));
if isempty(figFiles)
    figList = strings(0, 1);
    return;
end

allNames = string({figFiles.name});
[~, idxSort] = sort(lower(allNames));
allNames = allNames(idxSort);

if isempty(fileOrder)
    figList = fullfile(sourceDir, allNames);
    figList = figList(:);
    return;
end

order = string(fileOrder(:));
for i = 1:numel(order)
    if ~endsWith(order(i), ".fig", "IgnoreCase", true)
        order(i) = order(i) + ".fig";
    end
end

figList = strings(0, 1);
used = false(size(allNames));
for i = 1:numel(order)
    hit = find(strcmpi(allNames, order(i)), 1);
    if ~isempty(hit)
        figList(end+1, 1) = fullfile(sourceDir, allNames(hit)); %#ok<AGROW>
        used(hit) = true;
    else
        warning("compose_figure_panel:OrderNameMissing", ...
            "File in fileOrder not found: %s", order(i));
    end
end

remain = allNames(~used);
for i = 1:numel(remain)
    figList(end+1, 1) = fullfile(sourceDir, remain(i)); %#ok<AGROW>
end
end

function [nRows, nCols] = resolveLayout(layout, defaultRows, numPanels)
if isempty(layout)
    nRows = min(defaultRows, numPanels);
    nRows = max(nRows, 1);
    nCols = ceil(numPanels / nRows);
else
    nRows = layout(1);
    nCols = layout(2);
    if nRows * nCols < numPanels
        error("compose_figure_panel:LayoutTooSmall", ...
            "layout=[%d %d] cannot hold %d panels.", nRows, nCols, numPanels);
    end
end
end

function applyAxisStyle(dstAx, srcAx, cfg)
dstAx.XLim = srcAx.XLim;
dstAx.YLim = srcAx.YLim;

if isprop(srcAx, "ZLim") && isprop(dstAx, "ZLim")
    dstAx.ZLim = srcAx.ZLim;
end

dstAx.XScale = srcAx.XScale;
dstAx.YScale = srcAx.YScale;

if isprop(srcAx, "ZScale") && isprop(dstAx, "ZScale")
    dstAx.ZScale = srcAx.ZScale;
end

dstAx.View = srcAx.View;
dstAx.Box = srcAx.Box;
dstAx.FontName = cfg.fontName;
dstAx.FontSize = cfg.fontSize;

xlabel(dstAx, srcAx.XLabel.String, "Interpreter", cfg.axisLabelInterpreter);
ylabel(dstAx, srcAx.YLabel.String, "Interpreter", cfg.axisLabelInterpreter);
zlabel(dstAx, srcAx.ZLabel.String, "Interpreter", cfg.axisLabelInterpreter);

grid(dstAx, srcAx.XGrid);
set(findobj(dstAx, "Type", "line"), "LineWidth", cfg.lineWidth);
end

function applyTitle(dstAx, figPath, idx, cfg)
[~, baseName, ~] = fileparts(figPath);
displayName = regexprep(baseName, "^\d+[_\-\s]*", "");
if strlength(displayName) == 0
    displayName = baseName;
end
prefix = "";
if lower(string(cfg.panelLabelMode)) == "alphabetical"
    token = toAlphabeticalToken(idx);
    prefix = sprintf(cfg.panelLabelFormat, token) + " ";
end
titleText = prefix + displayName;
if any(strcmpi(string(cfg.titleInterpreter), ["latex", "tex"]))
    % Escape underscores from filenames so labels render literally.
    titleText = replace(titleText, "_", "\_");
end
title(dstAx, titleText, "Interpreter", cfg.titleInterpreter, "FontWeight", "normal");
end

function applyPanelLabel(ax, idx, cfg)
% Deprecated behavior: labels are now merged into subplot titles.
% Keep function as no-op for compatibility.
if nargin >= 1 %#ok<INUSD>
end
if nargin >= 2 %#ok<INUSD>
end
if nargin >= 3 %#ok<INUSD>
end
return;
end

function token = toAlphabeticalToken(idx)
letters = 'abcdefghijklmnopqrstuvwxyz';
tokenChars = '';
n = idx;
while n > 0
    rem = mod(n - 1, 26) + 1;
    tokenChars = [letters(rem), tokenChars]; %#ok<AGROW>
    n = floor((n - 1) / 26);
end
token = string(tokenChars);
end

function applyLegendPerAxis(ax, legendMode, idx, cfg)
mode = lower(string(legendMode));
switch mode
    case "none"
        legend(ax, "off");
    case "first"
        if idx == 1
            legend(ax, "show", "Interpreter", cfg.legendInterpreter);
        else
            legend(ax, "off");
        end
    case "all"
        legend(ax, "show", "Interpreter", cfg.legendInterpreter);
    case "global"
        legend(ax, "off");
    otherwise
        warning("compose_figure_panel:UnknownLegendMode", ...
            "Unknown legendMode=%s; fallback to 'first'.", legendMode);
        if idx == 1
            legend(ax, "show", "Interpreter", cfg.legendInterpreter);
        else
            legend(ax, "off");
        end
end
end

function [handles, labels] = collectLegendItems(ax)
ln = findobj(ax, "Type", "line");
ln = flipud(ln);
handles = gobjects(0);
labels = strings(0, 1);
for i = 1:numel(ln)
    name = string(get(ln(i), "DisplayName"));
    if strlength(strtrim(name)) == 0
        continue;
    end
    handles(end+1, 1) = ln(i); %#ok<AGROW>
    labels(end+1, 1) = name; %#ok<AGROW>
end
end
