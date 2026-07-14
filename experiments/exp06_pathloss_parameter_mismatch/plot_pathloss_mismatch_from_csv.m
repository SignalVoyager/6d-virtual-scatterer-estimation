% Redraw the exp06 figure directly from the final summary CSV.
expRoot = fileparts(mfilename("fullpath"));
cfg = jsondecode(fileread(fullfile(expRoot, "config.json")));
S = cfg.mismatchSensitivity;
finalDir = fullfile(expRoot, "outputs", "final");
csvFile = fullfile(finalDir, "pathloss_mismatch_summary.csv");

assert(isfile(csvFile), "Summary CSV not found: %s", csvFile);
summaryTable = readtable(csvFile, "TextType", "string");
requiredVariables = ["parameter", "value", "meanMetric", "stdMetric", ...
    "semMetric", "ci95Metric"];
assert(all(ismember(requiredVariables, string(summaryTable.Properties.VariableNames))), ...
    "Summary CSV does not contain all required columns.");

parameters = ["alpha", "beta0"];
labels = ["Assumed $\widetilde{\alpha}$", ...
    "Assumed $\widetilde{\beta}_0$ (dB)"];
titles = ["(a) Path-loss exponent mismatch", ...
    "(b) Reference-gain mismatch"];
nominal = [S.nominalAlpha, S.nominalBeta0_dB];

fig = figure("Color", "w", "Visible", "off", "Units", "pixels", ...
    "Position", [100 100 1100 440]);
tiledlayout(fig, 1, 2, "TileSpacing", "compact", "Padding", "compact");

for i = 1:2
    ax = nexttile;
    hold(ax, "on"); grid(ax, "on"); box(ax, "on");

    Q = summaryTable(summaryTable.parameter == parameters(i), :);
    Q = sortrows(Q, "value");
    assert(~isempty(Q), "No rows found for parameter '%s'.", parameters(i));

    switch lower(string(S.errorBar))
        case "ci95"
            err = Q.ci95Metric;
        case "sem"
            err = Q.semMetric;
        otherwise
            err = Q.stdMetric;
    end

    errorbar(ax, Q.value, Q.meanMetric, err, "-o", ...
        "LineWidth", 2.2, "MarkerSize", 8, "CapSize", 8, ...
        "Color", [0.12 0.36 0.70], "MarkerFaceColor", "w");
    xline(ax, nominal(i), "--", "Nominal", ...
        "Color", [0.35 0.35 0.35], "LineWidth", 1.2, ...
        "LabelVerticalAlignment", "bottom");

    xlabel(ax, labels(i), "Interpreter", "latex");
    ylabel(ax, "MAE (dB)");
    title(ax, titles(i));
    xticks(ax, Q.value);
    set(ax, "FontName", "Times New Roman", "FontSize", 14, ...
        "LineWidth", 0.9, "Layer", "top");
end

pdfFile = fullfile(finalDir, "pathloss_mismatch_summary.pdf");
exportgraphics(fig, pdfFile, "ContentType", "vector");
close(fig);
fprintf("[PL-MISMATCH-PLOT] Redrew %s from %s\n", pdfFile, csvFile);
