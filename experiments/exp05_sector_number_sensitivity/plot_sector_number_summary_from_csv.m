% plot_sector_number_summary_from_csv
% Plot sector-number sensitivity from outputs/final/sector_number_summary.csv.

expRoot = fileparts(mfilename("fullpath"));
finalDir = fullfile(expRoot, "outputs", "final");
csvPath = fullfile(finalDir, "sector_number_summary.csv");
assert(isfile(csvPath), "Missing summary CSV: %s", csvPath);

T = readtable(csvPath);
required = ["M", "trainSamples", "meanMetric", "stdMetric"];
for i = 1:numel(required)
    assert(ismember(required(i), string(T.Properties.VariableNames)), ...
        "Missing required column: %s", required(i));
end
T = sortrows(T, "M");

fig = figure("Color", "w", "Visible", "off", "Units", "pixels", ...
    "Position", [100, 100, 900, 620]);
set(fig, "DefaultTextInterpreter", "latex");
set(fig, "DefaultLegendInterpreter", "latex");
hold on; grid on; box on;

x = T.M;
y = T.meanMetric;
yerr = T.stdMetric;

color = [0.10, 0.32, 0.68];
e = errorbar(x, y, yerr, "-o", ...
    "Color", color, "LineWidth", 3.2, "MarkerSize", 11, ...
    "MarkerFaceColor", "w", "MarkerEdgeColor", color, ...
    "CapSize", 12);
e.DisplayName = "X2X CGM";

for i = 1:height(T)
    text(x(i), y(i) + 0.06, sprintf("$n=%d$", T.trainSamples(i)), ...
        "FontName", "Times New Roman", "FontSize", 18, ...
        "HorizontalAlignment", "center", "VerticalAlignment", "bottom", ...
        "Interpreter", "latex");
end

xlabel("Number of sectors $M$", "Interpreter", "latex");
ylabel("MAE (dB)", "Interpreter", "latex");
xticks(x);

padX = max(1, 0.08 * range(x));
xlim([min(x)-padX, max(x)+padX]);
yLow = min(y - yerr);
yHigh = max(y + yerr);
padY = max(0.25, 0.18 * (yHigh - yLow));
ylim([max(0, yLow - padY), yHigh + padY]);

ax = gca;
set(ax, "FontName", "Times New Roman", "FontSize", 24, ...
    "LineWidth", 1.2, "TickLabelInterpreter", "latex", ...
    "GridAlpha", 0.18, "MinorGridAlpha", 0.10);

lg = legend("Location", "northeast", "Interpreter", "latex");
set(lg, "FontName", "Times New Roman", "FontSize", 22, ...
    "Box", "on", "LineWidth", 0.8);

saveBase = fullfile(finalDir, "sector_number_sensitivity_mae_largefont");
exportgraphics(fig, saveBase + ".png", "Resolution", 300);
exportgraphics(fig, saveBase + ".pdf", "ContentType", "vector");
savefig(fig, saveBase + ".fig");
close(fig);

fprintf("[M-SENS-PLOT] Saved:\n  %s.png\n  %s.pdf\n  %s.fig\n", ...
    saveBase, saveBase, saveBase);
