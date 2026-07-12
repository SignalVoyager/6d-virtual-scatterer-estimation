# Propagation-order ablation

This experiment is strictly paired. For each RNG seed it creates one training
sampling plan and one test sampling plan, then reuses those exact TX--RX pairs
for both propagation settings. The model architecture, hyperparameters, split,
and seed are unchanged. Only `MaxNumReflections` and `MaxNumDiffractions` differ.

The current compact comparison includes 3 reflections plus 2 diffractions
(`higher_order_3r2d`), 2 reflections plus 1 diffraction (`second_order_2r1d`),
2 reflections without diffraction (`second_order_2r0d`), and 1 reflection
without diffraction (`first_order`).
It uses 612 training pairs (6-by-6 geometry-guided TX/RX pairs per virtual
scatterer), approximately 1,500 test pairs, and 2-by-2 sub-grid sampling at each
endpoint. It must not be described as the original full 5R/2D setting.

The LoS/NLoS label is determined geometrically from the unobstructed segment
between grid-centre TX and RX locations. It is computed once from the shared
test pairs, saved with the sampling plan, and asserted identical during both
runs. Consequently it does not depend on whether a backend happens to return a
detectable direct-path component.

To avoid changing the behavior of existing experiments, the MATLAB ray tracer
with configurable reflection/diffraction limits is implemented locally in this
experiment's `run_experiment.m`. No `src/` implementation is modified by exp04.
MATLAB ray tracing GPU acceleration is controlled by `backend.useGPU` in
`config.json`; it is disabled for the current stability-first pilot.

Run through `main_all_experiments` after selecting
`exp04_propagation_order_ablation` and the desired seeds. Each seed writes a raw
CSV/MAT file. The final grouped plot and summary CSV are rebuilt from every raw
seed file currently present, so standard-deviation error bars appear once two
or more seeds have completed.
