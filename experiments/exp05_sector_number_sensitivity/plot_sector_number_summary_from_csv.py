from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd


HERE = Path(__file__).resolve().parent
FINAL_DIR = HERE / "outputs" / "final"
CSV_PATH = FINAL_DIR / "sector_number_summary.csv"

df = pd.read_csv(CSV_PATH).sort_values("M")

plt.style.use("default")
plt.rcParams.update({
    "font.family": "Times New Roman",
    "font.size": 19,
    "axes.labelsize": 23,
    "xtick.labelsize": 20,
    "ytick.labelsize": 20,
    "legend.fontsize": 20,
    "pdf.fonttype": 42,
    "ps.fonttype": 42,
})

fig, ax = plt.subplots(figsize=(9.0, 6.2), dpi=300, facecolor="white")
ax.set_facecolor("white")

x = df["M"].to_numpy()
y = df["meanMetric"].to_numpy()
yerr = df["stdMetric"].to_numpy()
train_n = df["trainSamples"].to_numpy()

ax.errorbar(
    x,
    y,
    yerr=yerr,
    fmt="-o",
    color="#1f5aa6",
    linewidth=3.2,
    markersize=10.5,
    markerfacecolor="white",
    markeredgewidth=2.4,
    capsize=8,
    capthick=2.2,
    label="X2X CGM",
)

label_offsets = [(-16, 16), (0, 16), (0, 14), (12, 14), (14, 14)]
for idx, (xi, yi, ni) in enumerate(zip(x, y, train_n)):
    dx, dy = label_offsets[idx % len(label_offsets)]
    ax.annotate(
        f"$|\\mathcal{{A}}_{{\\mathrm{{train}}}}|={int(ni)}$",
        xy=(xi, yi),
        xytext=(dx, dy),
        textcoords="offset points",
        ha="center",
        va="bottom",
        fontsize=14,
    )

ax.set_xlabel(r"Number of sectors $M$")
ax.set_ylabel("MAE (dB)")
ax.set_xticks(x)

x_pad = max(1.0, 0.08 * (x.max() - x.min()))
ax.set_xlim(x.min() - x_pad, x.max() + x_pad)
y_low = (y - yerr).min()
y_high = (y + yerr).max()
y_pad = max(0.25, 0.18 * (y_high - y_low))
ax.set_ylim(max(0, y_low - y_pad), y_high + y_pad)

ax.grid(True, alpha=0.22, linewidth=0.9)
ax.tick_params(colors="black")
ax.xaxis.label.set_color("black")
ax.yaxis.label.set_color("black")
for spine in ax.spines.values():
    spine.set_linewidth(1.2)
    spine.set_color("black")

ax.legend(loc="upper right", frameon=True)
fig.tight_layout()

out_base = FINAL_DIR / "sector_number_sensitivity_mae_largefont"
fig.savefig(out_base.with_suffix(".png"), dpi=300, bbox_inches="tight", facecolor="white")
fig.savefig(out_base.with_suffix(".pdf"), bbox_inches="tight", facecolor="white")
plt.close(fig)

print(f"Saved {out_base.with_suffix('.png')}")
print(f"Saved {out_base.with_suffix('.pdf')}")
