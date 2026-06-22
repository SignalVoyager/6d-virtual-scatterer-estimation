# Experiment Notes - Model Comparison

## Goal
Benchmark the proposed `VirtualScatter6D` pipeline against baseline models under
matched sample-budget settings.

This experiment emphasizes:
- fair comparison with consistent train/test scene presets,
- unified evaluation settings across models,
- raw per-model diagnostics for inspection,
- a paper-ready deployment-cost comparison table under `outputs/final/`.

## Final Figure Concept
Use one table for the main paper:

- Evaluation assumption
- Samples used in experiment
- Full-6D deployment multiplier
- Equivalent full-6D samples
- NMAE
- MAE (dB)

The table should be interpreted as a sample-efficiency and deployment-cost
comparison for the full 6D prediction task, not as a representation-equivalent
comparison between 6D and 3D parameterizations.

## Fair Comparison Policy
The proposed method is a native 6D model: each training sample is a TX-RX pair,
and the trained model is intended to generalize across both transmitter and
receiver positions.

The 3D baselines are fixed-TX radio-map learners. Directly simulating a full 6D
task with 3D baselines would require training or maintaining separate 3D models
for many TX positions, which is cumbersome and would introduce another layer of
cost accounting.

Instead, this experiment uses an equivalent fixed-TX assumption:

- predefine five representative TX positions,
- generate or load one full-RX pool for each fixed TX,
- evaluate each 3D baseline on those five fixed-TX tasks,
- average the five fixed-TX metrics as a Monte Carlo estimate,
- use that averaged fixed-TX performance as the baseline's equivalent estimate
  for the full 6D task.

This is favorable to the 3D baselines because it does not charge them for the
extra cost of retraining, storing, or maintaining separate models over many TX
positions. Therefore, if the proposed 6D strategic pipeline performs better
under this setting, the conclusion is stronger: the gain is not caused by
penalizing 3D methods for their full 6D deployment cost.

Suggested caption language:

`For 3D baselines, we evaluate five representative fixed-TX slices and average
their metrics as an equivalent estimate across TX positions, assuming similar
slice-wise behavior. This gives the 3D baselines a favorable comparison by not
accounting for the additional cost of retraining or maintaining separate models
for many TX positions.`

## Current Sampling Policy
Dense scene only.

Training budget:
- all methods use `8*8*17 = 1088` training samples in the experiment.
- the budget is matched at the experimental fixed-TX/6D training-set level;
  full-6D deployment cost is reported separately through the multiplier column.

Proposed method:
- model: `VirtualScatter6D`
- `NumCenters = 5`
- training set: geometry-aware TX/RX samples
- dataset cache: `data/geom_scatter_focus_dense_1088.mat`
- if direct `8x8` geometry sampling has empty angular bins, the script builds
  this cache by combining smaller successful geometry batches until 1088 unique
  TX-RX samples are available
- evaluation: the same trained 6D response is evaluated on each of the five
  fixed-TX full-RX test pools
- deployment multiplier: `1`

3D baseline:
- model: `VirtualScatter3D`
- `NumCenters = 5`
- five Monte Carlo tasks are used, each fixing one TX
- RX training samples are selected geometrically from that fixed-TX full-RX pool
- each fixed-TX task uses 1088 RX samples
- one 3D model is trained/evaluated per fixed TX
- metrics are averaged over five predefined fixed TXs
- deployment multiplier: `3600`

Kriging baseline:
- model: `KrigingModel`
- five Monte Carlo tasks are used, each fixing one TX
- RX training samples are selected randomly from that fixed-TX full-RX pool
- each fixed-TX task uses 1088 RX samples
- one Kriging model is trained/evaluated per fixed TX
- metrics are averaged over five predefined fixed TXs
- deployment multiplier: `3600`

Test policy:
- each evaluation task fixes one TX,
- RX test samples cover all available RX grids for that TX.
- the five fixed TX grid coordinates are:
  - `[30, 30]`
  - `[4, 4]`
  - `[56, 4]`
  - `[56, 56]`
  - `[4, 56]`

Ray-tracing reuse:
- the five fixed-TX full-RX pools are generated once,
- both the 3D baseline and Kriging baseline draw their training subsets from
  these pools,
- this avoids repeatedly ray tracing separate training and test datasets for
  each baseline.

Expected dataset caches:
- `data/geom_scatter_focus_dense_1088.mat`
- `data/fixedtx_pool_dense_tx01.mat`
- `data/fixedtx_pool_dense_tx02.mat`
- `data/fixedtx_pool_dense_tx03.mat`
- `data/fixedtx_pool_dense_tx04.mat`
- `data/fixedtx_pool_dense_tx05.mat`

The fixed-TX pool files are semantic datasets. Any
`geom_scatter_focus_dense_1088_batch*.mat` files are implementation details
used only to construct the final 6D geometry-sampling cache.

## Folder Contract
Self-contained experiment folder:
- `config.json`: dataset, model-list, hyperparameter, and runtime configuration
- `run_experiment.m`: the experiment entry point
- `data/`: shared dataset cache and per-model response files
- `outputs/logs/`: run logs and reference records
- `outputs/original/`: figures generated directly by environment/model evaluation
- `outputs/final/`: paper-ready comparison figures, tables, or curated final artifacts

No experiment output should be written outside this folder.

## Configuration
Primary file: `config.json`.

Key design:
- each dataset entry in `dataSetList` carries its own `activeScenePreset`
- dataset MAT path is implicit: `data/<dataset.name>.mat`
- dataset `dataMode` should typically be `"load"` for repeatability after caches are generated
- `models.modelList` enumerates models to run in order
- each model section provides a separate `responseFile`, dataset selection, and hyperparameters
- selected train/test datasets for each model should use a consistent scene preset

## Execution
Recommended:

```matlab
main_all_experiments
```

Direct run is also possible after setting `expRoot` to this experiment folder and then running `run_experiment.m`.

RNG seeds are injected by `main_all_experiments.m`.

## Expected Outputs
After a normal run:
- `outputs/original/`: environment diagnostics and per-model evaluation figures
- `outputs/logs/`: runtime logs when log mode is enabled
- `outputs/final/model_comparison_table_seed<seed>.csv`: final paper-ready comparison table
- `outputs/final/model_comparison_table_seed<seed>.mat`: MATLAB copy of the same table

## Recommended Next Step
Use the final table as the main experiment-3 artifact. If additional sample
budgets are later needed, generate one table per budget or add a budget column,
but keep the full-6D multiplier explicit.

## Fairness Checklist
- fixed dataset caches where possible
- same test set for comparable models
- same diagnostics TX list
- same evaluation options and noise-floor behavior
- clearly label 3D/Kriging baselines as equivalent fixed-TX estimates
- do not imply that the 3D baselines are native 6D models
- mention that the equivalent fixed-TX assumption is favorable to the baselines
