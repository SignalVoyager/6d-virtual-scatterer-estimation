# Experiment Notes - VirtualScatter6D Showcase

## Goal
This experiment is the dense-scene single-model showcase for `VirtualScatter6D`.

It produces the raw diagnostic figures and the final Fig. 1 intuitive panel:
- ray-traced CGM slices for selected TX positions,
- VirtualScatter6D predicted CGM slices for the same TX positions,
- a composed 2x4 paper panel comparing prediction and ground truth,
- run logs and reference metric tables.

## Folder Contract
This experiment is self-contained under `experiments/exp01_virtualscatter6d_showcase/`.

- `config.json`: scene, dataset, model, evaluation, and runtime switches
- `run_experiment.m`: the experiment entry point
- `data/`: cached datasets, scene files, and trained response artifacts
- `outputs/logs/`: run logs and reference log-derived tables
- `outputs/original/env/`: environment figures generated directly by the experiment code
- `outputs/original/model/`: model diagnostic figures generated directly by the experiment code
- `outputs/final/`: final paper-ready rendered outputs

For Fig. 1, the curated package lives directly under:

```text
outputs/final/
```

That folder contains the composed `panel_composed_2x4.[png|fig]`. Source subfigures are regenerated under `outputs/original/env/` and `outputs/original/model/`.

## Configuration
Primary file: `config.json`.

Important switches:
- `dataSetList[].activeScenePreset`: choose the scene for each dataset entry
- `dataSetList[].dataMode`: use `"save"` to regenerate datasets and `"load"` for repeatable reruns
- `models.activeModel`: expected to remain `"VirtualScatter6D"` here
- `runtime.showFigures`: controls whether diagnostic figures are generated under `outputs/original/env/` and `outputs/original/model/`
- `runtime.composeIntuitivePanel`: composes the Fig. 1 panel from `outputs/original/` into `outputs/final/`
- `envEvaluation.cgmRaytraceDataMode`: use `"load"` to reuse the cached ground-truth CGM dataset; use `"save"` only when refreshing the ray-tracing cache

For the current Fig. 1 dense showcase, selected train/test datasets should consistently use the `dense` scene.

## Execution
Recommended:

```matlab
main_all_experiments
```

Direct run is also possible after setting `expRoot` to this experiment folder and then running `run_experiment.m`.

RNG seeds are injected by `main_all_experiments.m`.

## Expected Outputs
After a normal run:
- `outputs/original/env/`: environment TX heatmaps and ray-traced CGM slices
- `outputs/original/model/`: model CGM outputs
- `outputs/logs/`: runtime logs when log mode is enabled
- `outputs/final/`: final composed Fig. 1 panel

## Best Practices
- Generate datasets once, then switch dataset entries back to `"load"`.
- Keep the Fig. 1 TX grid list fixed when refreshing the panel.
- Treat `outputs/original/` as reproducible raw output and `outputs/final/` as publication material.
