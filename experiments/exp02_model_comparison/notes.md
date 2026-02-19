# Experiment Notes — Model Comparison

## Goal
Benchmark **VirtualScatter6D vs multiple baselines** under the **same dataset**.  
This experiment emphasizes:
- fair comparison (identical train/test sets),
- unified evaluation settings,
- automated per-model outputs,
- a comparison-ready metrics artifact for papers.

## Folder Contract
Self-contained experiment folder:
- `data/`: shared dataset cache + per-model response files
- `outputs/`: per-model figures + comparison summaries

No writing outside this folder.

## Configuration
Primary file: `config.json`

Key design:
- `scenePresets` contains multiple presets; `activeScenePreset` selects one
- `dataset.mode` should typically be `"load"` to ensure identical datasets across models
- `models.modelList` enumerates models to run in order
- each model section provides:
  - `responseFile` (separate per model),
  - `hyper` parameters (model-specific)

## Execution
Recommended: run via `main_all_experiments.m` to inject seeds consistently.  
Direct run: execute `run_experiment.m` after setting `expRoot`.

## Expected Outputs
In `outputs/`:
- per-model figures (if enabled): `{modelKey}_fig_*.png`
- run summary: `comparison_summary_seed*.mat`

## Recommended Next Step (for real benchmarking)
Make `evaluate()` return a metrics struct (MSE/NMSE/glo_mse_dB/buckets/etc).  
Then the comparison script can automatically assemble a single results table and export it.

## Fairness Checklist
- fixed dataset (`dataset.mode="load"`)
- same noise-floor projection settings
- same test set (`whichSet="test"`)
- same diagnostics TX list (or disable diagnostics for speed)
