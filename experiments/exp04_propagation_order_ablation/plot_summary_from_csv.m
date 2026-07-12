% plot_summary_from_csv.m
% Regenerate the propagation-order MAE bar chart from outputs/final/propagation_order_summary.csv.

expRoot = fileparts(mfilename("fullpath"));
finalDir = fullfile(expRoot, "outputs", "final");
summaryCsv = fullfile(finalDir, "propagation_order_summary.csv");
assert(isfile(summaryCsv), "Missing summary CSV: %s", summaryCsv);

T = readtable(summaryCsv, "TextType", "string");
T.SettingNorm = strings(height(T), 1);
for i = 1:height(T)
    s = lower(string(T.Setting(i)));
    if contains(s, "3r2d")
        T.SettingNorm(i) = "3R/2D";
    elseif contains(s, "2r1d")
        T.SettingNorm(i) = "2R/1D";
    elseif contains(s, "1r0d") || s == "first_order"
        T.SettingNorm(i) = "1R/0D";
    else
        T.SettingNorm(i) = string(T.Setting(i));
    end
end

groups = ["Overall", "LoS", "NLoS"];
settings = ["3R/2D", "2R/1D", "1R/0D"];
displayNames = ["3R/2D", "2R/1D", "1R/0D"];

meanMae = nan(numel(groups), numel(settings));
stdMae = nan(numel(groups), numel(settings));
for g = 1:numel(groups)
    for s = 1:numel(settings)
        take = T.Group == groups(g) & T.SettingNorm == settings(s);
        if any(take)
            meanMae(g, s) = mean(T.Mean_MAE_dB(take), "omitnan");
            stdMae(g, s) = mean(T.Std_MAE_dB(take), "omitnan");
        end
    end
end

fig = figure("Visible", "off", "Color", "w", "Position", [100 100 760 450]);
bh = bar(meanMae, "grouped");
hold on;
colors = [
    0.1216 0.4667 0.7059
    1.0000 0.4980 0.0549
    0.1725 0.6275 0.1725
];
for s = 1:numel(bh)
    bh(s).FaceColor = colors(s, :);
    x = bh(s).XEndPoints;
    errorbar(x, meanMae(:, s), stdMae(:, s), ...
        "k", "LineStyle", "none", "LineWidth", 1.0, "CapSize", 7);
end

set(gca, "XTick", 1:numel(groups), "XTickLabel", groups, "FontName", "Arial", "FontSize", 11);
ylabel("MAE (dB)", "FontName", "Arial", "FontSize", 12);
ylim([0, max(meanMae(:) + stdMae(:), [], "omitnan") * 1.18]);
grid on; box on;
legend(displayNames, "Location", "northwest", "Box", "off");
title("Propagation-order ablation", "FontName", "Arial", "FontSize", 12);

pngPath = fullfile(finalDir, "propagation_order_mae_from_summary.png");
pdfPath = fullfile(finalDir, "propagation_order_mae_from_summary.pdf");
figPath = fullfile(finalDir, "propagation_order_mae_from_summary.fig");
exportgraphics(fig, pngPath, "Resolution", 300);
exportgraphics(fig, pdfPath, "ContentType", "vector");
savefig(fig, figPath);
close(fig);

fprintf("[PROP-ABLATION] Summary plot saved:\n  %s\n  %s\n  %s\n", pngPath, pdfPath, figPath);
