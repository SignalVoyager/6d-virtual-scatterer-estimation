# Experiment Notes — VirtualScatter6D Showcase

## Goal
This experiment is a **single-model showcase** focusing on **VirtualScatter6D** (formerly X2XSingleHop).  
It is designed to produce **paper/slide-ready** diagnostics and performance evidence:
- overall prediction accuracy on held-out data,
- spatial diagnostics (CGM map, residual map),
- sensitivity checks by switching scene presets (dense vs sparse),
- fully reproducible outputs saved under one experiment folder.

## Folder Contract
This experiment is self-contained under:
- `data/`: intermediate artifacts and cached results (STL/PLY/XML, Train/Test MAT, response MAT, etc.)
- `outputs/`: figures and summary artifacts

The run script must **only** read/write inside this experiment folder (except importing `src/`).

## Configuration
Primary file: `config.json`

Key switches:
- `activeScenePreset`: selects one preset from `scenePresets` without editing code
- `dataset.mode`: `"save"` regenerates datasets; `"load"` reuses cached MAT files
- `models.activeModel`: must be `"VirtualScatter6D"` in this experiment

Scene switching (no comments needed; JSON has no comments):
- set `"activeScenePreset": "dense"` or `"sparse"`

## Execution
Recommended: run from project root via `main_all_experiments.m`.  
Direct run: execute `run_experiment.m` after setting `expRoot`.

RNG:
- seeds are injected by `main_all_experiments.m` for reproducibility.

## Expected Outputs
In `outputs/`:
- environment plots: TX heatmaps / sampling count maps
- model diagnostics: CGM maps + residual maps for chosen TX grids
- optional PDF comparison plot (GT vs prediction)
- optional saved summaries if you export metrics structs later

## Best Practices
- generate datasets once → then switch to `dataset.mode="load"`
- keep `diagTxGridList` small (1–3 TX points)
- for final figures: lock `seed`, `activeScenePreset`, and `dataset.mode="load"`
