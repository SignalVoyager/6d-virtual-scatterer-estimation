# Scatter-Based Channel Knowledge Map Project

## Overview
This project builds and evaluates **channel gain / knowledge maps** using:
- ray-traced datasets (MATLAB RT or Sionna RT backend),
- scatterer-based models (e.g., VirtualScatter6D),
- reproducible experiment folders with isolated data/outputs.

## Layout
- `src/`: core MATLAB code (classes + utilities)
- `experiments/<exp_name>/`:
  - `config.json`: experiment-local configuration (including multiple scene presets)
  - `run_experiment.m`: experiment-local execution script
  - `data/`: intermediate/cache artifacts
  - `outputs/`: figures/metrics/logs
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
  - keep multiple environments under `scenePresets`
  - select one via `activeScenePreset`
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
