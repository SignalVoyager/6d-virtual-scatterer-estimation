# Scatter-Based Channel Knowledge Map Project

## Overview
This project builds and evaluates **channel gain / knowledge maps** using:
- ray-traced datasets (MATLAB RT or Sionna RT backend),
- scatterer-based models (e.g., VirtualScatter6D),
- reproducible experiment folders with isolated data/outputs.

## Layout
- `src/`: core MATLAB code (classes + utilities)
- `tools/`: reusable post-processing helpers for composing figure panels and result tables
- `experiments/<exp_name>/`:
  - `config.json`: experiment-local configuration (`dataSetList` + per-dataset `activeScenePreset`)
  - `run_experiment.m`: experiment-local execution script
  - `data/`: intermediate/cache artifacts
  - `outputs/`: figures/metrics/logs
  - `S_Fig*/`: figure-specific source data, plotting scripts, and final rendered outputs when a figure belongs to this experiment
  - `notes.md`: experiment intent + usage notes
- `main_all_experiments.m`: top-level orchestration (select experiments + seeds)

## Running
Recommended (from project root):
1. edit `main_all_experiments.m`:
   - choose `expNames`
   - choose `rngValues`
2. run:
   - `main_all_experiments`

Direct run:
- execute `experiments/<exp_name>/run_experiment.m` after setting `expRoot`

## Configuration Principles
- JSON does not support comments:
  - keep multiple environments under `scenes`
  - set `dataSetList[].activeScenePreset` to choose which scene each dataset uses
  - dataset files are saved/loaded by convention at `data/<dataset.name>.mat`
  - keep selected train/test datasets scene-consistent for one run
- Use `dataset.mode="save"` only when regenerating ray-tracing datasets.
  Otherwise use `"load"` for repeatability and speed.

## Extending
Add a new experiment:
- copy an existing experiment folder
- edit its `config.json` + `run_experiment.m`
- add its name to `main_all_experiments.m`

Add a new model:
- implement a new class under `src/`
- register it in the comparison run script (switch-case)
- add its hyperparameters to the comparison config
