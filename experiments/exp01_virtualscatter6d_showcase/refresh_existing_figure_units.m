% refresh_existing_figure_units - Update existing exp01 FIG/PNG outputs with colorbar units.
%
% Run from the project root or this experiment folder.

function refresh_existing_figure_units()
scriptDir = fileparts(mfilename('fullpath'));
outDir = fullfile(scriptDir, "outputs");

figFiles = [ ...
    dir(fullfile(outDir, "final", "*.fig")); ...
    dir(fullfile(outDir, "original", "env", "cgm_raytrace", "*.fig")); ...
    dir(fullfile(outDir, "original", "env", "test_heatmaps", "*.fig")); ...
    dir(fullfile(outDir, "original", "model", "**", "*.fig")) ...
];

for i = 1:numel(figFiles)
    figPath = fullfile(figFiles(i).folder, figFiles(i).name);
    refreshOneFigure(figPath);
end

fprintf("[SHOWCASE] Refreshed units for %d existing figure(s).\n", numel(figFiles));
end

function refreshOneFigure(figPath)
fig = openfig(figPath, "invisible");
cleaner = onCleanup(@() close(fig));

colorbars = findall(fig, "Type", "ColorBar");
for k = 1:numel(colorbars)
    colorbars(k).Label.String = "Received power (dBm)";
    colorbars(k).Label.Interpreter = "latex";
    if contains(figPath, fullfile("outputs", "final"))
        colorbars(k).Label.FontSize = 22;
        colorbars(k).Label.FontName = "Times New Roman";
    end
end

savefig(fig, figPath);
[folder, name, ~] = fileparts(figPath);
pngPath = fullfile(folder, name + ".png");
try
    exportgraphics(fig, pngPath, "Resolution", 300);
catch
    saveas(fig, pngPath);
end

fprintf("[SHOWCASE] refreshed %s\n", figPath);
end
